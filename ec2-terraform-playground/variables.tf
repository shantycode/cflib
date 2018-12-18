variable "region" {}

variable "amis" {
  type = "map"
}

variable "instance_type" {}
variable "public_key_path" {}

variable "allowed_cidr_blocks" {
  type = "list"
}

variable "corp_public_ip" {}
