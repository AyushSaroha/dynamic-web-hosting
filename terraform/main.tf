terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}

# -------------------------
# Random ID (optional use)
# -------------------------
resource "random_id" "key" {
  byte_length = 4
}

# -------------------------
# Generate Private Key
# -------------------------
resource "tls_private_key" "dynamic_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# -------------------------
# AWS Key Pair (FIXED)
# -------------------------
resource "aws_key_pair" "dynamic_site_key" {
  key_name   = "dynamic-site-key"
  public_key = tls_private_key.dynamic_key.public_key_openssh
}

# -------------------------
# Ubuntu AMI
# -------------------------
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# -------------------------
# Security Group
# -------------------------
resource "aws_security_group" "dynamic_site_sg" {
  name_prefix = "${var.project_name}-sg-"
  description = "Security group for dynamic web hosting project"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.your_ip]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Grafana"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.your_ip]
  }

  ingress {
    description = "Prometheus"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [var.your_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-sg"
    Project = var.project_name
  }
}

# -------------------------
# EC2 Instance (FIXED)
# -------------------------
resource "aws_instance" "dynamic_site" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  # FIX: correct key reference
  key_name = aws_key_pair.dynamic_site_key.key_name

  vpc_security_group_ids = [
    aws_security_group.dynamic_site_sg.id
  ]

  user_data = file("${path.module}/user_data.sh")

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name    = var.project_name
    Project = var.project_name
  }
}

# -------------------------
# Elastic IP (FIXED)
# -------------------------
resource "aws_eip" "dynamic_site_eip" {
  instance = aws_instance.dynamic_site.id
  domain   = "vpc"

  tags = {
    Name    = "${var.project_name}-eip"
    Project = var.project_name
  }
}