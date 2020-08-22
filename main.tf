provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

#-----VPC-----

resource "aws_vpc" "blog_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "blog_vpc"
  }
}

#internet gateway

resource "aws_internet_gateway" "blog_internet_gateway" {
  vpc_id = aws_vpc.blog_vpc.id
  tags = {
    Name = "blog_igw"
  }
}

#route tables

resource "aws_route_table" "blog_public_rt" {
  vpc_id = aws_vpc.blog_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.blog_internet_gateway.id
  }
  tags = {
    Name = "blog_public_rt"
  }
}
resource "aws_default_route_table" "blog_private_rt" {
  default_route_table_id = aws_vpc.blog_vpc.default_route_table_id
  tags = {
    Name = "blog_private_rt"
  }
}

#subnets

resource "aws_subnet" "blog_public1_subnet" {
  vpc_id                  = aws_vpc.blog_vpc.id
  cidr_block              = var.cidrs["public1"]
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "blog_public1"
  }
}

#subnet associations

resource "aws_route_table_association" "blog_public1_assoc" {
  subnet_id      = aws_subnet.blog_public1_subnet.id
  route_table_id = aws_route_table.blog_public_rt.id
}

#security groups

resource "aws_security_group" "blog_public_sg" {
  name        = "blog_public_sg"
  description = "used for public access to blog"
  vpc_id      = aws_vpc.blog_vpc.id

  #SSH
  ingress {
    from_port   = 22
    protocol    = "tcp"
    to_port     = 22
    cidr_blocks = [var.local_ip]
  }

  #HTTP
  ingress {
    from_port   = 80
    protocol    = "tcp"
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  #HTTPS
  ingress {
    from_port   = 443
    protocol    = "tcp"
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#-----Storage-----

# ebs volume for blog data

resource "aws_ebs_volume" "blog_volume" {
  availability_zone = data.aws_availability_zones.available.names[0]
  size              = 10

  tags = {
    Name = "blog_data"
  }
}

#-----Compute-----

#key pair

resource "aws_key_pair" "blog_auth" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)
}

#elastic ip address

resource "aws_eip" "blog_ip" {
  instance = aws_instance.blog_instance.id
  vpc      = true
}

#ghost server

resource "aws_instance" "blog_instance" {
  instance_type          = var.blog_instance_type
  ami                    = var.blog_ami
  key_name               = aws_key_pair.blog_auth.id
  vpc_security_group_ids = [aws_security_group.blog_public_sg.id]
  subnet_id              = aws_subnet.blog_public1_subnet.id

  tags = {
    Name = "blog_instance"
  }
}

#attach to ebs

resource "aws_volume_attachment" "blog_att" {
  device_name = "/dev/sdg"
  instance_id = aws_instance.blog_instance.id
  volume_id   = aws_ebs_volume.blog_volume.id
}

#-----Route53-----

#create zone

resource "aws_route53_zone" "primary" {
  name              = "${var.domain_name}.com"
  delegation_set_id = var.delegation_set
}

#blog site at stephaniekoerlin.com

resource "aws_route53_record" "blog" {
  name    = "blog.${var.domain_name}.com"
  type    = "A"
  zone_id = aws_route53_zone.primary.zone_id
  records = [aws_eip.blog_ip.public_ip]
  ttl     = "3600"

  #UPDATE - add static fall back with health true
  #alias {
  #  evaluate_target_health = false
  #  name                   = aws_instance.blog_instance.public_ip
  #  zone_id                = aws_route53_zone.primary.zone_id
  #}
}

output "Ghost_Address" {
  value = "http://${aws_eip.blog_ip.public_ip}"
}