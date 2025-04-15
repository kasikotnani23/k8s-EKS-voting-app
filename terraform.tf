provider "aws" {
  region = "us-east-1"
}

variable "ami" {
  default     = "ami-084568db4383264d4"
  description = "The AMI ID to use for the instance."
}

variable "instance_type" {
  type        = string
  default     = "t2.medium"
  description = "The instance type to use for the instance."
}

variable "key_name" {
  default     = "vpc_one"
  description = "The name of the key pair to associate with the instance."
}

data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "allow_jenkins" {
  name        = "allow_jenkins"
  description = "Allow Jenkins inbound traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_jenkins"
  }
}

resource "aws_instance" "ec2_machine" {
  ami                         = var.ami
  instance_type               = var.instance_type
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.allow_jenkins.id]

  root_block_device {
    volume_size = 15
  }

  user_data = <<-EOF
        #!/bin/bash
        sudo -i
        sudo apt update -y
        sudo apt install default-jdk -y 
        sudo apt install docker.io -y
        sudo systemctl start docker
        sudo systemctl enable docker
        sudo wget -O /usr/share/keyrings/jenkins-keyring.asc \
          https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
        echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null
        sudo apt-get update
        sudo apt-get install jenkins -y
        sudo systemctl start jenkins
        sudo systemctl enable jenkins
        sudo apt install git -y
        usermod -aG docker jenkins
  EOF
}

output "public_ip" {
  value       = aws_instance.ec2_machine.public_ip
  description = "The public IP address of the instance."
}

output "jenkins_url" {
  value       = "http://${aws_instance.ec2_machine.public_ip}:8080"
  description = "The Jenkins URL for the instance."
}
