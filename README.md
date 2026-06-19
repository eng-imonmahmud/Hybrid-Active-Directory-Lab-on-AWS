# Hybrid Active Directory Lab on AWS

## Project Overview

This project demonstrates the deployment of a Microsoft Active Directory Domain Controller on AWS using Infrastructure as Code (Terraform) and integration with AWS Identity Services.

The environment simulates a hybrid identity architecture where an on-premises Active Directory is extended into AWS and connected through AWS Directory Service (AD Connector) and IAM Identity Center.

This project was built to gain hands-on experience with:

* Terraform Infrastructure as Code (IaC)
* AWS Networking
* Windows Server Administration
* Active Directory Domain Services (AD DS)
* DNS Configuration
* AWS Directory Service
* IAM Identity Center
* Identity Federation Concepts
* Infrastructure Troubleshooting

---

## Architecture

```text
Internet
    │
    ▼
AWS VPC (10.0.0.0/16)
│
├── Public Subnet (10.0.1.0/24)
│     └── Windows Server 2022
│           ├── Active Directory Domain Services
│           ├── DNS Server
│           └── Domain Controller
│
├── Private Subnet A (10.0.10.0/24)
│
├── Private Subnet B (10.0.20.0/24)
│
└── AD Connector
        │
        ▼
IAM Identity Center
```

---

## Technologies Used

### Cloud

* AWS EC2
* AWS VPC
* AWS Route Tables
* AWS Internet Gateway
* AWS Security Groups
* AWS Directory Service
* AWS IAM Identity Center

### Infrastructure as Code

* Terraform

### Operating System

* Windows Server 2022

### Identity Services

* Active Directory Domain Services
* DNS
* AD Connector
* IAM Identity Center

---

## Infrastructure Provisioned with Terraform

### Networking

* Custom VPC
* Public Subnet
* Private Subnet A
* Private Subnet B
* Internet Gateway
* Route Tables
* Route Associations

### Security

* Security Group
* RDP Access Restriction
* Active Directory Ports
* DNS Ports
* LDAP Ports
* Kerberos Ports

### Compute

* Windows Server 2022 EC2 Instance
* SSH/RDP Key Pair

---

## Active Directory Configuration

Domain Name:

```text
imon.local
```

Installed Roles:

* Active Directory Domain Services
* DNS Server

Verified Components:

* Domain Controller Promotion
* DNS Resolution
* User Creation
* Domain Validation

PowerShell Validation:

```powershell
Get-ADDomain
Get-WindowsFeature AD-Domain-Services,DNS
```

---

## AWS Directory Service Integration

### AD Connector

Configured AWS AD Connector to connect AWS services with the Active Directory environment.

Configuration:

| Item            | Value        |
| --------------- | ------------ |
| Directory Type  | AD Connector |
| Directory Size  | Small        |
| Domain          | imon.local   |
| DNS Server      | 10.0.1.158   |
| Service Account | ad.connector |

---

## IAM Identity Center

Enabled:

* IAM Identity Center (Standalone Account Instance)

Configured:

* Identity Source
* Access Portal
* Federation Readiness

---

## Troubleshooting Experience

### Issue

AD Connector failed during deployment.

Error:

```text
LDAP unavailable (UDP port 389)
```

### Root Cause

The Active Directory Security Group was missing:

```text
UDP 389 (LDAP)
```

Although LDAP TCP 389 was configured, AWS AD Connector health checks also require LDAP UDP 389 connectivity.

### Resolution

Updated Terraform Security Group configuration:

```hcl
ingress {
  description = "LDAP UDP"
  from_port   = 389
  to_port     = 389
  protocol    = "udp"
  cidr_blocks = ["10.0.0.0/16"]
}
```

Applied changes:

```bash
terraform apply
```

Result:

```text
AD Connector Status = Active
```

---

## Validation Evidence

Screenshots included:

* Terraform Plan Clean
* VPC Resource Map
* Domain Controller Instance
* Get-ADDomain Output
* Active Directory Users and Computers
* AD Connector Active
* IAM Identity Center Enabled

---

## Project Outcomes

Successfully deployed:

* AWS Infrastructure with Terraform
* Windows Server 2022 Domain Controller
* Active Directory Domain Services
* DNS Services
* AD Connector Integration
* IAM Identity Center Integration

Successfully performed:

* Infrastructure Provisioning
* Active Directory Administration
* AWS Networking
* Identity Integration
* Production-style Troubleshooting

---

## Future Improvements

Potential future enhancements:

* AWS Managed Microsoft AD
* SAML Federation
* Multi-Factor Authentication (MFA)
* WorkSpaces Integration
* AWS Organizations Integration
* Multi-Region Domain Controllers

---

## Author

Imon Mahmud

Computer Engineer

Focus Areas:

* Cloud Engineering
* AWS
* Terraform
* Active Directory
* Identity & Access Management
* DevOps
* Infrastructure Automation
