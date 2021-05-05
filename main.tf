# Terraform 0.13 and later:
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
  access_key = "YOUR AWS ACCESS KEY"
  secret_key = "YOUR AWS SECRET KEY"
}

# EC2 instance with Ubuntu 18.04 AMI ID
# resource "aws_instance" "my-first-server" {
#   ami           = "ami-085925f297f89fce1"
#   instance_type = "t3.micro"

#   tags = {
#     Name = "ubuntu-18.04-from-terraform"
#   }
# }

# resource "<provider>_<resource_type>" "name" {
#   config options...
#   key = "value"
#   key2 = "value2"
# }

# VPC 
# resource "aws_vpc" "my-first-vpc" {
#   cidr_block = "10.0.0.0/16"

#   tags = {
#     Name = "virtual-private-cloud-from-terraform"
#   }
# }

# Subnet
# resource "aws_subnet" "my-first-subnet" {
#   vpc_id            = aws_vpc.my-first-vpc.id
#   cidr_block        = "10.0.1.0/24"
#   availability_zone = "us-east-1a"

#   tags = {
#     Name = "subnet-from-terraform"
#   }
# }

variable "subnet_prefix" {
  description = "cidr block for subnet"#
  default = "10.0.1.0/24"
  type = string
}

# Create a VPC
resource "aws_vpc" "main-vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "virtual-private-cloud-from-terraform"
  }
}
# Create Internet Gateway
resource "aws_internet_gateway" "main-gateway" {
  vpc_id = aws_vpc.main-vpc.id

  tags = {
      Name = "internet-gateway-from-terraform"
  }
}
# Create Custom Route Table
resource "aws_route_table" "main-route-table" {
  vpc_id = aws_vpc.main-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main-gateway.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.main-gateway.id
  }

  tags = {
    Name = "route-table-from-terraform"
  }
}
# Create a Subnet
resource "aws_subnet" "main-subnet" {
    vpc_id = aws_vpc.main-vpc.id
    cidr_block = var.subnet_prefix #"10.0.1.0/24"
    availability_zone = "us-east-1a"

    tags = {
      Name = "subnet-terraform"
    }
}
# Associate subnet with Route Table
resource "aws_route_table_association" "main-route-table-association" {
  subnet_id      = aws_subnet.main-subnet.id
  route_table_id = aws_route_table.main-route-table.id
}
# Create Security Group to allow port 22,80,443
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.main-vpc.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}
# Create a network interface with an ip in the subnet that was created in step 4
resource "aws_network_interface" "main-nic" {
  subnet_id       = aws_subnet.main-subnet.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]

#   attachment {
#     instance     = aws_instance.test.id
#     device_index = 1
#   }
}
# Assign an elastic IP to the network inferface created in step 7
resource "aws_eip" "main-eip" {
  vpc                       = true
  network_interface         = aws_network_interface.main-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [
    aws_internet_gateway.main-gateway,
  ]
}
# Create ubuntu server and install/enable apache2
resource "aws_instance" "main-server-instance" {
  ami = "ami-085925f297f89fce1"
  instance_type = "t3.micro"
  availability_zone = "us-east-1a"
  key_name = "main-key"

  network_interface {
      device_index = 0
      network_interface_id = aws_network_interface.main-nic.id
  }

  user_data = <<-EOF
    #!/bin/bash
    sudo apt update -y 
    sudo apt install apache2 -y
    sudo systemctl start apache2
    sudo bash -c "echo terraform is LIT > /var/www/html/index.html"
    EOF

  tags = {
    Name = "ubuntu-18.04-from-terraform"
  }
}

# For observing after terraform apply 
output "server_public_ip" {
  value = aws_eip.main-eip.public_ip
}