provider "aws" {
  region = var.region
}

variable "region" { type = string; default = "ap-southeast-1" }
variable "instance_type" { type = string; default = "t3.medium" }
variable "key_name" { type = string; default = "jenkins-key" }
variable "public_key_path" { type = string; default = "~/.ssh/id_rsa.pub" }
variable "vpc_cidr" { type = string; default = "10.0.0.0/16" }

# VPC and Networking
resource "aws_vpc" "jenkins" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "jenkins-vpc" }
}

resource "aws_internet_gateway" "jenkins" {
  vpc_id = aws_vpc.jenkins.id
  tags   = { Name = "jenkins-igw" }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.jenkins.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 1)
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags = { Name = "jenkins-public-a" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.jenkins.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 2)
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true
  tags = { Name = "jenkins-public-b" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.jenkins.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.jenkins.id
  }
  tags = { Name = "jenkins-public-rt" }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

data "aws_availability_zones" "available" {
  state = "available"
}

# Security Groups
resource "aws_security_group" "jenkins" {
  name        = "jenkins-sg"
  description = "Security group for Jenkins controller instance"
  vpc_id      = aws_vpc.jenkins.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Jenkins UI (direct access)"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "jenkins-sg" }
}

# SSH Key Pair
resource "aws_key_pair" "jenkins" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)
}

# Jenkins Controller Instance
resource "aws_instance" "jenkins" {
  ami                    = data.aws_ami.almalinux.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.jenkins.key_name
  vpc_security_group_ids = [aws_security_group.jenkins.id]
  subnet_id              = aws_subnet.public_a.id
  user_data              = templatefile("${path.module}/../cloud-init/jenkins-almalinux.sh", {})
  
  root_block_device {
    volume_size = 50
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = { Name = "jenkins-controller" }
}

# AMI Data Source
data "aws_ami" "almalinux" {
  most_recent = true
  owners      = ["679593333241"] # AlmaLinux OS Foundation
  filter { name = "name"; values = ["AlmaLinux OS 9* x86_64"] }
  filter { name = "virtualization-type"; values = ["hvm"] }
}

# Outputs
output "jenkins_public_ip" {
  description = "Public IP of Jenkins controller"
  value       = aws_instance.jenkins.public_ip
}

output "jenkins_http_url" {
  description = "HTTP URL to Jenkins (via Nginx reverse proxy)"
  value       = "http://${aws_instance.jenkins.public_ip}"
}

output "jenkins_https_url" {
  description = "HTTPS URL to Jenkins (configure TLS in Nginx)"
  value       = "https://${aws_instance.jenkins.public_ip}"
}

output "jenkins_direct_url" {
  description = "Direct access URL to Jenkins (bypass Nginx)"
  value       = "http://${aws_instance.jenkins.public_ip}:8080"
}

output "ssh_command" {
  description = "SSH command to connect to Jenkins controller"
  value       = "ssh -i ~/.ssh/${var.key_name} ec2-user@${aws_instance.jenkins.public_ip}"
}

output "next_steps" {
  description = "Next steps after provisioning"
  value = <<-EOT
    1. Wait 3-5 minutes for Jenkins and Nginx to install
    2. SSH: ssh -i ~/.ssh/${var.key_name} ec2-user@${aws_instance.jenkins.public_ip}
    3. Get admin password: sudo cat /var/lib/jenkins/secrets/initialAdminPassword
    4. Access Jenkins via Nginx: http://${aws_instance.jenkins.public_ip}
    5. Direct Jenkins access: http://${aws_instance.jenkins.public_ip}:8080
    6. For HTTPS: Configure TLS certificate in /etc/nginx/conf.d/jenkins.conf
  EOT
}
