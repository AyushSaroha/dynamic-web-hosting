variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-2"
}

variable "project_name" {
  description = "Name used for AWS resource tags"
  type        = string
  default     = "dynamic-web-hosting"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Existing AWS EC2 key pair name"
  type        = string
  default     = "dynamic-site-key"
}

variable "your_ip" {
  description = "Your public IP address in CIDR format, for example 49.36.55.12/32"
  type        = string

  validation {
    condition     = can(cidrhost(var.your_ip, 0))
    error_message = "your_ip must be valid CIDR, for example 49.36.55.12/32."
  }
}
