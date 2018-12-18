# Create a data source from a shell script for provisioning the machine. The variables will be interpolated within the script.
data "template_file" "provision" {
  template = "${file("${path.module}/provision.sh")}"

  vars {
    region = "${var.region}"
  }
}

data "aws_availability_zones" "available" {}
