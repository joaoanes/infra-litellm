terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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

resource "aws_eip" "litellm_eip" {
  domain = "vpc"

  tags = {
    Name = "litellm-eip"
  }
}

resource "local_file" "eip_output" {
  content  = aws_eip.litellm_eip.public_ip
  filename = "../step2-instance/eip.txt"
}

output "elastic_ip" {
  value = aws_eip.litellm_eip.public_ip
}
