provider "aws" {
  version = "~> 0.1"
  region  = "${var.region}"

  #access_key = "${var.access_key}"
  #secret_key = "${var.secret_key}"
}

# Create a VPC to launch our instances into.
resource "aws_vpc" "vpc" {
  cidr_block = "${var.allowed_cidr_blocks[0]}"

  tags {
    Name = "waf-example-vpc"
  }
}

# Create an internet gateway to give our subnet access to the outside world.
resource "aws_internet_gateway" "gateway" {
  vpc_id = "${aws_vpc.vpc.id}"

  tags {
    Name = "waf-example-internet-gateway"
  }
}

# Grant the VPC internet access on its main route table.
resource "aws_route" "route" {
  route_table_id         = "${aws_vpc.vpc.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.gateway.id}"
}

# Create subnets in each availability zone to launch our instances into, each with address blocks within the VPC.
resource "aws_subnet" "main" {
  count                   = "${length(data.aws_availability_zones.available.names)-1}"
  vpc_id                  = "${aws_vpc.vpc.id}"
  cidr_block              = "192.168.${count.index}.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${element(data.aws_availability_zones.available.names, count.index)}"

  tags {
    Name = "public-${element(data.aws_availability_zones.available.names, count.index)}"
  }
}

# Create a security group in the VPC which our instances will belong to.
resource "aws_security_group" "default" {
  name        = "terraform_security_group"
  description = "Terraform example security group"
  vpc_id      = "${aws_vpc.vpc.id}"

  # Restrict inboud SSH traffic by IP address.
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.allowed_cidr_blocks}", "${var.corp_public_ip}"]
  }

  # Allow ICMP echo requests.
  ingress {
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = "${var.allowed_cidr_blocks}"
  }

  # Restrict inbound HTTP traffic to the load balancer.
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = ["${aws_security_group.alb.id}"]
  }

  # Allow outbound internet access.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "waf-example-security-group"
  }
}

# Create an application load balancer security group.
resource "aws_security_group" "alb" {
  name        = "terraform_alb_security_group"
  description = "Terraform load balancer security group"
  vpc_id      = "${aws_vpc.vpc.id}"

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = "${var.allowed_cidr_blocks}"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["${var.allowed_cidr_blocks}", "${var.corp_public_ip}"]
  }

  # Allow all outbound traffic.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "waf-example-alb-security-group"
  }
}

# Create a new application load balancer.
resource "aws_alb" "alb" {
  name            = "waf-example-alb"
  security_groups = ["${aws_security_group.alb.id}"]
  subnets         = ["${aws_subnet.main.*.id}"]

  tags {
    Name = "waf-example-alb"
  }
}

# Create a new target group for the application load balancer.
resource "aws_alb_target_group" "group" {
  name     = "waf-example-alb-target"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.vpc.id}"

  stickiness {
    type = "lb_cookie"
  }

  # Alter the destination of the health check to be the login page.
  health_check {
    path = "/"
    port = 80
  }
}

# Create a new application load balancer listener for HTTP.
resource "aws_alb_listener" "listener_http" {
  load_balancer_arn = "${aws_alb.alb.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.group.arn}"
    type             = "forward"
  }
}
