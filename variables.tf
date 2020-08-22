variable "aws_region" {}
variable "aws_profile" {}
data "aws_availability_zones" "available" {}
variable "vpc_cidr" {}

variable "cidrs" {
  type = map
}

variable "local_ip" {}
variable "domain_name" {}
variable "key_name" {}
variable "public_key_path" {}
variable "blog_instance_type" {}
variable "blog_ami" {}
variable "delegation_set" {}