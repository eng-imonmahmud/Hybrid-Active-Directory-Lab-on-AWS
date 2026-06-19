# Author      : Imon Mahmud
# Project     : Hybrid Active Directory Lab on AWS
# Tool        : Terraform
# Cloud       : AWS
# OS          : Windows Server 2022
# Directory   : Active Directory Domain Services
# DNS         : Microsoft DNS
# Integration : AWS Directory Service (AD Connector)

###############################################################
# PROJECT: Hybrid Active Directory Lab on AWS using Terraform
#
# PURPOSE:
# - Create a custom AWS VPC
# - Deploy Windows Server 2022 Domain Controller
# - Install Active Directory Domain Services (AD DS)
# - Install DNS Server
# - Create imon.local domain automatically
# - Integrate with AWS Directory Service (AD Connector)
#
# REGION:
# eu-north-1 (Stockholm)
###############################################################

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

##################################################
# VARIABLES
##################################################

variable "region" {
  type    = string
  default = "eu-north-1"
}

variable "dsrm_password" {
  type      = string
  sensitive = true
}

###############################################################
# AWS Provider
#
# Defines which AWS Region Terraform will use
###############################################################
provider "aws" {
  region = var.region
}

###############################################################
# Detect Current Public IP
#
# Used to automatically restrict RDP access (3389)
# only to my current public IP address.
#
# Security Benefit:
# Avoids exposing RDP to the entire internet.
###############################################################
data "http" "myip" {
  url = "https://checkip.amazonaws.com"
}

locals {
  my_ip = "${chomp(data.http.myip.response_body)}/32"
}

###############################################################
# Latest Windows Server 2022 AMI
#
# Dynamically retrieves the latest Amazon-maintained
# Windows Server 2022 image.
#
# Benefit:
# No need to hardcode AMI IDs.
###############################################################
data "aws_ami" "windows2022" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

###############################################################
# Custom VPC
#
# CIDR: 10.0.0.0/16
#
# Dedicated network environment for:
# - Domain Controller
# - AD Connector
# - Future expansion
###############################################################
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "imon-lab-vpc"
  }
}

###############################################################
# Internet Gateway
#
# Provides internet connectivity
# for resources in public subnet.
###############################################################
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "imon-igw"
  }
}

###############################################################
# Public Subnet
#
# Hosts Windows Domain Controller.
#
# Public IP assignment enabled.
###############################################################
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-north-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet"
  }
}

###############################################################
# Private Subnets
#
# Reserved for AWS Directory Service
# and future hybrid identity components.
#
# AD Connector requires two subnets
# in separate Availability Zones.
###############################################################
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = "eu-north-1a"

  tags = {
    Name = "private-a"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.20.0/24"
  availability_zone = "eu-north-1b"

  tags = {
    Name = "private-b"
  }
}

##################################################
# ROUTE TABLES & ASSOCIATIONS
##################################################

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "private-rt"
  }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

###############################################################
# Domain Controller Security Group
#
# Purpose:
# Secure Active Directory communication.
#
# Key Rules:
# - RDP restricted to my public IP
# - DNS
# - LDAP
# - Kerberos
# - SMB
# - Global Catalog
# - Dynamic RPC Ports
#
# Required for:
# AWS AD Connector integration.
###############################################################
resource "aws_security_group" "dc" {
  name   = "domain-controller-sg"
  vpc_id = aws_vpc.main.id

  ###############################################################
  # RDP Access
  #
  # Allows administrative access
  # only from my current public IP.
  ###############################################################
  ingress {
    description = "RDP"
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = [local.my_ip]
  }

  #########################
  # DNS
  #########################
  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  #########################
  # KERBEROS
  #########################
  ingress {
    from_port   = 88
    to_port     = 88
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    from_port   = 88
    to_port     = 88
    protocol    = "udp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  #########################
  # LDAP
  #########################
  ingress {
    from_port   = 389
    to_port     = 389
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # LDAP UDP (Required by AWS AD Connector health checks)
  ingress {
    description = "LDAP UDP"
    from_port   = 389
    to_port     = 389
    protocol    = "udp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  #########################
  # LDAPS
  #########################
  ingress {
    from_port   = 636
    to_port     = 636
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  #########################
  # RPC
  #########################
  ingress {
    from_port   = 135
    to_port     = 135
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  #########################
  # SMB
  #########################
  ingress {
    from_port   = 445
    to_port     = 445
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  #########################
  # KERBEROS PASSWORD
  #########################
  ingress {
    from_port   = 464
    to_port     = 464
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  #########################
  # GLOBAL CATALOG
  #########################
  ingress {
    from_port   = 3268
    to_port     = 3268
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    from_port   = 3269
    to_port     = 3269
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  #########################
  # DYNAMIC RPC
  #########################
  ingress {
    from_port   = 49152
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "dc-security-group"
  }
}

###############################################################
# EC2 Key Pair
#
# Generates a temporary RSA key pair.
#
# Purpose:
# Retrieve and decrypt Windows
# Administrator password.
###############################################################
resource "tls_private_key" "dc_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "dc" {
  key_name   = "imon-dc-key"
  public_key = tls_private_key.dc_key.public_key_openssh
}

###############################################################
# Windows Server 2022 Domain Controller
#
# Instance Type:
# t3.micro
#
# Root Volume:
# 30 GB gp3
#
# Automatically:
# - Installs AD DS
# - Installs DNS
# - Creates imon.local forest
# - Promotes server to Domain Controller
###############################################################
resource "aws_instance" "dc" {
  ami           = data.aws_ami.windows2022.id
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.public.id

  vpc_security_group_ids = [
    aws_security_group.dc.id
  ]

  key_name          = aws_key_pair.dc.key_name
  get_password_data = true

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  ###############################################################
  # Bootstrap Script
  #
  # Executes during first boot.
  #
  # Actions:
  # 1. Install AD DS
  # 2. Install DNS
  # 3. Create Forest: imon.local
  # 4. Configure NetBIOS Name: IMON
  # 5. Promote server to Domain Controller
  # 6. Reboot automatically
  ###############################################################
  user_data = <<-EOF
<powershell>

Install-WindowsFeature AD-Domain-Services,DNS -IncludeManagementTools

Import-Module ADDSDeployment

$SafeModePassword = ConvertTo-SecureString "${var.dsrm_password}" -AsPlainText -Force

Install-ADDSForest `
-DomainName "imon.local" `
-DomainNetbiosName "IMON" `
-InstallDNS `
-SafeModeAdministratorPassword $SafeModePassword `
-Force `
-NoRebootOnCompletion:$false

</powershell>
EOF

  tags = {
    Name = "imon-domain-controller"
  }
}

###############################################################
# Terraform Outputs
#
# Exposes:
# - Public IP
# - Private IP
# - Windows AMI ID
# - RDP Allowed IP
# - Private Key
# - Encrypted Windows Password
###############################################################

output "dc_public_ip" {
  value = aws_instance.dc.public_ip
}

output "dc_private_ip" {
  value = aws_instance.dc.private_ip
}

output "windows_ami" {
  value = data.aws_ami.windows2022.id
}

output "rdp_allowed_ip" {
  value = local.my_ip
}

output "private_key_pem" {
  value     = tls_private_key.dc_key.private_key_pem
  sensitive = true
}

output "encrypted_windows_password" {
  value     = aws_instance.dc.password_data
  sensitive = true
}