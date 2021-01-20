##############################################################################################
# VARIABLES
##############################################################################################

variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "private_key_path" {}
variable "key_name" {}
variable "region" {
  default = "us-east-1"
}
variable "network_address_space" {
  default = "10.1.0.0/16"
}
variable "subnet1_address_space" {
  default = "10.1.0.0/24"
}

##############################################################################################
# PROVIDERS
##############################################################################################

provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.region
}

##############################################################################################
# DATA
##############################################################################################

data "aws_availability_zones" "available" {}

data "aws_ami" "aws-linux" {
  most_recent   = true
  owners        = [ "amazon" ]

  filter {
    name    = "name" 
    values  = [ "amzn-ami-hvm*" ]
  }

  filter {
    name    = "root-device-type"
    values  = ["ebs"]
  }

  filter {
    name    = "virtualization-type"
    values  = [ "hvm" ]
  }
}

##############################################################################################
# RESOURCES
##############################################################################################

## NETWORKING SECTION ##

resource "aws_vpc" "vpc" {
  cidr_block            = var.network_address_space
  enable_dns_hostnames  = true

  tags = {
    "Name" = "Terraform VPC"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_subnet" "subnet1" {
  cidr_block                = var.subnet1_address_space
  vpc_id                    = aws_vpc.vpc.id
  map_public_ip_on_launch   = true
  availability_zone         = data.aws_availability_zones.available.names[0]
}

## ROUTING ##

resource "aws_route_table" "rtb" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block  = "0.0.0.0/0"
    gateway_id  = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "rta-subnet-1" {
  subnet_id       = aws_subnet.subnet1.id
  route_table_id  = aws_route_table.rtb.id
}

## SECURITY GROUPS ##

resource "aws_security_group" "nginx-sg" {
  name          = "nginx_demo"
  description   = "Allow ports for nginx demo"
  vpc_id        = aws_vpc.vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = [ "0.0.0.0/0" ]
  }
}

## INSTANCES ##

resource "aws_instance" "nginx1" {
  ami                       = data.aws_ami.aws-linux.id
  instance_type             = "t2.micro"
  subnet_id                 = aws_subnet.subnet1.id
  key_name                  = var.key_name
  vpc_security_group_ids    = [ aws_security_group.nginx-sg.id ]
  
  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ec2-user"
    private_key = file(var.private_key_path)
  }

  provisioner "remote-exec" {
    inline = [
        "sudo yum install nginx -y",
        "sudo service nginx start",
        "echo '<html><head><title>Blue Team Server</title></head><body style=\"background-color:#1F778D\"><p style=\"text-align: center;\"><span style=\"color:#FFFFFF;\"><span style=\"font-size:28px;\">Blue Team</span></span></p></body></html>' | sudo tee /usr/share/nginx/html/index.html"
    ]
  }
}

##############################################################################################
# OUTPUTS
##############################################################################################

output "aws_instance_public_dns" {
  value = aws_instance.nginx1.public_dns
}
