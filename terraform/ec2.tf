data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "dynamic_site" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.dynamic_key.key_name

  vpc_security_group_ids = [
    aws_security_group.dynamic_site_sg.id
  ]

  user_data = templatefile("${path.module}/user_data.sh", {
    docker_image = var.docker_image
  })

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name    = var.project_name
    Project = var.project_name
  }
}

resource "aws_eip" "dynamic_site_eip" {
  domain = "vpc"

  tags = {
    Name    = "${var.project_name}-eip"
    Project = var.project_name
  }
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.dynamic_site.id
  allocation_id = aws_eip.dynamic_site_eip.id
}
