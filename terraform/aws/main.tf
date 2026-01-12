provider "aws" {
  region = var.region
}

variable "region" { type = string default = "us-east-1" }
variable "instance_type" { type = string default = "t3.medium" }
variable "key_name" { type = string default = "jenkins-key" }
variable "public_key_path" { type = string default = "~/.ssh/id_rsa.pub" }

resource "aws_key_pair" "jenkins" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)
}

resource "aws_security_group" "jenkins" {
  name        = "jenkins-sg"
  description = "SSH and HTTP/S"

  ingress { from_port = 22   to_port = 22   protocol = "tcp" cidr_blocks = ["0.0.0.0/0"] }
  ingress { from_port = 8080 to_port = 8080 protocol = "tcp" cidr_blocks = ["0.0.0.0/0"] }
  ingress { from_port = 443  to_port = 443  protocol = "tcp" cidr_blocks = ["0.0.0.0/0"] }
  egress  { from_port = 0    to_port = 0    protocol = "-1"  cidr_blocks = ["0.0.0.0/0"] }
}

resource "aws_instance" "jenkins" {
  ami           = data.aws_ami.almalinux.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.jenkins.key_name
  vpc_security_group_ids = [aws_security_group.jenkins.id]
  user_data = file("${path.module}/../cloud-init/jenkins-almalinux.sh")
  root_block_device { volume_size = 50 }
  tags = { Name = "jenkins-controller" }
}

data "aws_ami" "almalinux" {
  most_recent = true
  owners      = ["679593333241"] # AlmaLinux OS Foundation
  filter { name = "name" values = ["AlmaLinux OS 9* x86_64"] }
  filter { name = "virtualization-type" values = ["hvm"] }
}
