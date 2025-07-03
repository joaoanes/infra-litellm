terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
    local = {
      source = "hashicorp/local"
      version = "~> 2.1"
    }
  }
}

provider "aws" {
  region  = "eu-west-1"
  profile = "self"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "litellm_sg" {
  name        = "litellm-sg"
  description = "Allow SSH, HTTP and HTTPS traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "litellm_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = "joaoanes@joaoanes-mindera"
  security_groups = [aws_security_group.litellm_sg.name]

  tags = {
    Name = "litellm-server"
    Hostname = var.hostname
  }
}

data "local_file" "eip" {
  filename = "eip.txt"
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.litellm_server.id
  public_ip = data.local_file.eip.content
}

resource "null_resource" "litellm_provisioner" {
  triggers = {
    instance_id = aws_eip_association.eip_assoc.id
  }

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("~/.ssh/id_ed25519")
    agent       = true
    host        = aws_eip_association.eip_assoc.public_ip
  }

  provisioner "file" {
    source      = "user_data.sh"
    destination = "/tmp/user_data.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/user_data.sh",
      "/tmp/user_data.sh '${file(var.openai_api_key_file)}' '${file(var.anthropic_api_key_file)}' '${file(var.gemini_api_key_file)}' '' '' '${random_string.master_key.result}' '${random_string.ui_username.result}' '${random_string.ui_password.result}' '${var.hostname}' '${random_string.db_password.result}'"
    ]
  }
}

resource "random_string" "master_key" {
  length  = 16
  special = false
}

resource "random_string" "ui_username" {
  length  = 8
  special = false
}

resource "random_string" "ui_password" {
  length  = 12
  special = false
}

resource "random_string" "db_password" {
  length  = 16
  special = false
}

output "litellm_ui_username" {
  value = random_string.ui_username.result
}

output "litellm_ui_password" {
  value     = random_string.ui_password.result
  sensitive = true
}

output "sshstring" {
  value = "/tmp/user_data.sh '${file(var.openai_api_key_file)}' '${file(var.anthropic_api_key_file)}' '${file(var.gemini_api_key_file)}' '${random_string.master_key.result}' '${random_string.ui_username.result}' '${random_string.ui_password.result}' '${var.hostname}' '${random_string.db_password.result}'"
}
