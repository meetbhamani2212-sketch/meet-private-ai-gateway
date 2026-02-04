# Private AI Gateway via Tailscale Subnet Router
*Tailscale Take-Home Assignment*

**Tailnet Name:** `meet-private-ai-gateway`

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Overview of Technical Choices made](#overview-of-technical-choices-made)
- [Security & Design Considerations](#security--design-considerations)
- [Infrastructure as Code](#infrastructure-as-code)
- [Deployment Instructions](#deployment-instructions)
- [Validation Technique](#validation-technique)
- [Tools & Technologies](#tools--technologies)
- [Reflection & AI Disclosure](#reflection--ai-disclosure)

---

## Overview

This repository contains a **reproducible proof-of-concept** that demonstrates how **Tailscale subnet routing** can securely provide access to a **private internal service** - in this case, an **AI-powered FastAPI designed to call Amazon Bedrock for real LLM responses** - without exposing that service to the public internet.

The solution mirrors **a real-world commercial customer scenario**: Teams want to safely access internal tools such as APIs, admin services, AI-powered services or AI assistants from anywhere, while avoiding traditional VPN complexity, inbound network exposure, and shared credentials.

**In this design:**
- **Tailscale** provides identity-based secure connectivity and acts as the secure access layer
- **AWS** hosts the isolated application environment 
- **Terraform** delivers repeatable **Infrastructure as Code (IaC)** for **both AWS and Tailscale resources**

### What This Demonstrates

- **Subnet routing**: Tailscale subnet router advertising a private CIDR (`10.0.2.0/24`) with approved routes
- **Zero public exposure**: Private service with no public IP, accessible only via Tailnet
- **Identity-based access**: Identity-based access control using Tailscale ACLs. ACL policy restricting access to `group:engineers`
- **Infrastructure as Code**: Full Infrastructure as Code automation with Terraform for AWS and Tailscale resources
- **Credentialless design**: IAM roles for AWS service integration (no hardcoded credentials)
- **Real AI/LLM integration**: AI/LLM responses with Amazon Bedrock (Claude 3 Haiku)
- **Automated validation**: PowerShell script for end-to-end testing

---

## Architecture

### Architecture Components

| Component | Purpose | Security Posture |
|-----------|---------|------------------|
| **Tailscale Client** | User's laptop running tailscale | Identity Based Authentication
| **Subnet Router (EC2)** | Advertises `10.0.2.0/24` to Tailnet | Tagged `tag:subnet-router`, no SSH by default |
| **Private Service (EC2)** | FastAPI service with AI/LLM endpoints | No public IP, accepts traffic only from router SG |
| **NAT Gateway** | Provides private subnet egress for updates & AWS API calls | One-way outbound traffic only |
| **Amazon Bedrock** | LLM inference endpoint | Accessed via IAM instance role |
| **Tailscale ACL** | Identity-based access control | Only `group:engineers` can reach `10.0.2.0/24:8000` |

### AWS VPC Layout

#### Public Subnet (10.0.1.0/24)
- Hosts the Tailscale subnet router EC2 instance  
- Provides outbound internet access for control-plane connectivity  
- Connected to Internet Gateway for direct internet access

#### Private Subnet (10.0.2.0/24)
- Hosts the private FastAPI service on EC2 instance  
- Has no public IPs and is not directly reachable from the internet  
- Uses NAT Gateway for outbound-only internet access 

### Architecture Diagram

Visual diagram for this project is located in the `diagrams/` folder at the root of this repository:

- **tailscale-aws-architecture-diagram.png** - overall system architecture  
- **tailscale-security-controls.png** - network and identity security controls  

### Tailscale

- The subnet router advertises `10.0.2.0/24` to the Tailnet  
- Access is governed by identity, tags, and ACLs managed as code in Terraform

### Private Service (FastAPI)

FastAPI Runs on port **8000** and exposes three endpoints:

| Endpoint | Purpose |
|----------|---------|
| `GET /health` | Connectivity validation |
| `GET /whoami` | Hostname + private IP for clear demos |
| `POST /ask` | Real AI/LLM responses from **Amazon Bedrock (Claude 3 Haiku)** |

### Traffic Flow

1. **User authenticates** to Tailscale via identity-based access.
2. **User's device joins** the Tailnet and receives routes
3. **User makes request** to `http://10.0.2.x:8000/ask`
4. **Tailscale encrypts** traffic via WireGuard and routes through coordination server
5. **Subnet router receives** encrypted traffic and forwards to private service
6. **Private service processes** request and calls Bedrock for AI/LLM responses (via IAM role)
7. **Response returns** through the same secure path

---

## Overview of Technical Choices made

### Cloud Provider: AWS

I chose AWS because:
- **Familiarity**: Industry-standard cloud platform with hands-on experience
- **Terraform support**: Mature provider with good documentation
- **Customer alignment**: Mirrors typical Tailscale customer environments
- **Bedrock integration**: Native AI service with IAM role support


**Alternatives I considered:**
- **GCP/Azure**: Would work fine, but AWS Bedrock made the AI integration cleaner
- **Local VMs**: Possible with VirtualBox, but wouldn't demonstrate cloud-native patterns

### IaC Tool: Terraform

I went with Terraform because:
- **Industry standard**: De facto IaC tool used by most enterprises
- **Reproducibility**: Infrastructure can be deployed, torn down, and redeployed identically
- **Version control**: All infrastructure changes tracked in Git with full audit history
- **Tailscale integration**: Official Terraform provider supports ACLs, auth keys, and DNS as code
- **Customer alignment**: Reflects how Tailscale customers manage infrastructure and network policies together

**Alternatives I considered:**
- **Pulumi**: Modern and supports multiple languages, but Terraform's Tailscale provider is more mature
- **CloudFormation**: AWS-native but doesn't support Tailscale resources

### Backend Service: FastAPI + Amazon Bedrock

I built a FastAPI service with AI integration because:
- **FastAPI**: Lightweight, production-ready Python framework—easy to demonstrate quickly
- **Bedrock**: Managed AI service with IAM integration (no secrets to manage)
- **Real use case**: Shows something more compelling than "hello world"
- **Practical scenario**: Teams actually do expose internal AI tools this way

**Alternatives I considered:**
- **Simple web server**: Would satisfy requirements but less interesting
- **Database**: Common use case, but harder to demo interactively
- **OpenAI API**: Requires API key management vs. Bedrock's IAM roles

### Tailscale Subnet Router

- **Simplicity**: No complex VPN configuration or bastion hosts required
- **Identity-based**: Access control tied to user identity, not network location
- **Zero-trust model**: Every connection authenticated and encrypted via WireGuard
- **Minimal infrastructure**: Single EC2 instance provides secure access to entire subnet
- **Real-world use case**: Common pattern for accessing internal tools, databases, and admin panels

### Why Subnet Routing?

I used subnet routing instead of installing Tailscale on every service because:
- **Scalability**: In real environments, you might have dozens of services in a private subnet
- **Legacy compatibility**: Not every service can run Tailscale (databases, managed services, etc.)
- **Customer pattern**: This mirrors how customers actually use Tailscale for internal access

---

## Security & Design Considerations

### No Public Exposure 

The private service does not have a public IP and cannot be reached directly from the internet. And no inbound ports from the public internet are opened to either the subnet router or the private service.

### Least-Privilege Networking

The service security group **only** allows inbound traffic **from the subnet router security group on port `8000`**.

### Identity-First Access

Access to the private service occurs via Tailscale identity, not network perimeter rules.

### SSH Disabled by Default 

The subnet router does not allow inbound SSH unless explicitly enabled for temporary debugging.

### Credentialless Design 

The service EC2 instance uses an **IAM instance role** to call LLM Model in Amazon Bedrock - **no API keys in code or GitHub**.

### Intentional Sequencing

Networking and security are established first, followed by compute, routing, and application layers.


### Defense in Depth

Multiple security layers protect the private service:

- **Network layer**: Private subnet with no internet gateway
- **Transport layer**: WireGuard encryption via Tailscale
- **Application layer**: FastAPI with input validation
- **Identity layer**: Tailscale ACLs with group-based authorization
- **AWS layer**: IAM roles with least-privilege permissions

---

## Infrastructure as Code

**All Infrastructure as Code deployment code for this project is located in the `terraform/` directory at the root of this repository**

All infrastructure is defined and created using **Terraform**.

### AWS resources created using Terraform:
- VPC, subnets, route tables
- Security groups
- NAT Gateway
- EC2 instances
- IAM roles and policies

AWS resources are provisioned declaratively


### Tailscale is also managed via Terraform, including:

- Tailscale ACL configuration (policy as code)
- Ephemeral Tailscale authentication key used by the subnet router - The subnet router uses an ephemeral, single-use Tailscale auth key to reduce risk if the key is leaked.
- Device tagging

The subnet router uses an ephemeral (single-use, short-lived) Tailscale auth key so that no long-lived credentials exist in the environment, reducing risk if the key is ever exposed.

Provider versions are locked via `.terraform.lock.hcl`

Environment can be recreated from scratch with:
```bash
  terraform apply
```
  and torn down safely with:
```bash
  terraform destroy
```
This aligns with real customer practices where both cloud infrastructure and Tailscale policies are automated together.

### Tailscale Access Control

The ACL restricts access to the private subnet:

```json
{
  "groups": {
    "group:engineers": [
      "meetbhamani2212-sketch@github"
    ]
  },

  "tagOwners": {
    "tag:subnet-router": ["autogroup:admin"]
  },

  "acls": [
    {
      "action": "accept",
      "src": ["group:engineers"],
      "dst": ["10.0.2.0/24:8000"]
    }
  ]
}
```

This demonstrates:

- **Role-based access**: Only `group:engineers` can reach the private service
- **Least privilege**: Access restricted to port 8000 on `10.0.2.0/24`
- **Identity-first security**: Router ownership limited to admins via `tag:subnet-router`

**These ACLs are applied automatically via Terraform, ensuring network policy is version-controlled alongside cloud infrastructure.**

---

## Deployment Instructions

### Prerequisites

Before deploying this solution, ensure you have:

#### 1. AWS Account & CLI

- AWS account with appropriate permissions (VPC, EC2, IAM, Bedrock)
- AWS CLI configured with credentials:
  ```bash
  aws configure
  ```

#### 2. Tailscale Account

- Create a free Tailscale account at [https://tailscale.com/](https://tailscale.com/)
- Install Tailscale on your local machine
- Generate a Tailscale API key from [https://login.tailscale.com/admin/settings/keys](https://login.tailscale.com/admin/settings/keys)

#### 3. Terraform

- Install Terraform (version ≥ 1.5.0)
- Verify installation:
  ```bash
  terraform version
  ```

#### 4. Amazon Bedrock Access

- Enable Amazon Bedrock in the AWS Console
- Request access to Claude 3 Haiku model
- Wait for approval (usually instant for Haiku)

### Deployment Steps

#### Step 1: Clone the Repository

```bash
git clone <repository-url>
cd <repository-directory>
```

#### Step 2: Configure Environment Variables

Set your Tailscale API key as an environment variable:

**Linux/macOS:**
```bash
export TAILSCALE_API_KEY="tskey-api-*****"
```

**Windows (PowerShell):**
```powershell
$env:TAILSCALE_API_KEY="tskey-api-*****"
```

#### Step 3: Initialize Terraform

```bash
cd terraform
terraform init
```

This will:
- Download the AWS and Tailscale providers
- Initialize the backend
- Create `.terraform.lock.hcl` to lock provider versions

#### Step 4: Review the Deployment Plan

```bash
terraform plan
```

Expected output: ~25-30 resources to be created.

#### Step 5: Deploy Infrastructure

```bash
terraform apply
```

Type `yes` when prompted.

**Deployment time**: ~3-5 minutes

Terraform will output important information including the service private IP.

#### Step 6: Approve the Subnet Route

After Terraform completes:

1. Go to [https://login.tailscale.com/admin/machines](https://login.tailscale.com/admin/machines)
2. Find the device named `meet-private-ai-gateway-subnet-router`
3. Click the device -> **Routes** tab
4. Click **Approve** next to `10.0.2.0/24`

---

## Validation Technique

This section describes how I validated that the private service is accessible securely via Tailscale

| Validation step        | What it proves                                  |
|------------------------|--------------------------------------------------|
| `/health`              | Secure connectivity through the Tailnet         |
| `/whoami`              | Service truly runs inside the private subnet    |
| `/ask`                 | AI/LLM Responses, AWS Bedrock and IAM role working correctly            |
| Disconnect Tailscale   | Confirms there is no public exposure            |


### 1. Infrastructure Validation

VPC, subnets, routing, and security groups created via Terraform:
```bash
terraform output
```
**Results:**
- VPC with public and private subnets created
- NAT Gateway operational for private egress
- Two EC2 instances successfully provisioned (router in public, service in private)

### 2. Tailscale Connectivity Validation

**Subnet router verification:**
1. Router appears in the Tailscale admin console
2. Private CIDR (`10.0.2.0/24`) advertised and approved in the Tailnet

### 3. Service Validation (Basic Connectivity)

**Secure access through Tailnet**

From my laptop (connected to Tailscale):

**Request:**
```bash
curl http://<service-private-ip>:8000/health
```

**Response:**
```json
{"status":"ok"}
```

**Confirmed**: Service is reachable via Tailscale subnet routing

### 4. Service Identity Validation

Check that it's truly running in the private subnet:
```bash
curl http://<service-private-ip>:8000/whoami
```

**Example response:**
```json
{
  "hostname": "ip-10-0-2-27.ca-central-1.compute.internal",
  "private_ip": "10.0.2.27",
  "instance_id": "i-0abc123def456",
  "service": "meet-private-ai-gateway",
  "aws_region": "ca-central-1",
  "model": "anthropic.claude-3-haiku-20240307-v1:0",
  "note": "Running in private subnet behind Tailscale subnet router"
}
```

**This clearly demonstrates that requests originate from a private EC2 instance inside AWS, accessed only via Tailscale.**

### 5. AI/LLM Integration Validation

From a client on the Tailnet  which is in this case **my laptop (connected to Tailscale)**, I have tested the real AI functionality:

**Windows (PowerShell):**
```powershell
Invoke-RestMethod `
  -Method POST `
  -Uri "http://<service-private-ip>:8000/ask" `
  -ContentType "application/json" `
  -Body '{"prompt":"Explain what a Tailscale subnet router does in simple terms"}' |
ConvertTo-Json -Depth 5
```

**Linux/macOS:**
```bash
curl -X POST http://<service-private-ip>:8000/ask \
  -H "Content-Type: application/json" \
  -d '{"prompt":"Explain what a Tailscale subnet router does in simple terms"}'
```

**Typical response:**
```json
{
  "model": "anthropic.claude-3-haiku-20240307-v1:0",
  "latency_ms": 380,
  "answer": "A Tailscale subnet router shares access to private IP ranges with your Tailnet so approved users can reach internal services without opening inbound firewall rules."
}
```

**Confirmed**: Real AI/LLM integration with Amazon Bedrock functional via IAM roles

### 6. No Public Access Validation

Tried accessing the service **without** Tailscale (disconnect or use a different device):
```bash
curl http://<service-private-ip>:8000/health --connect-timeout 5
```

**Result:** Timeout or connection refused.

**This confirms the service has no public exposure.**


### Automated Validation

I have incldued a Powershell script for quick end-to-end validation:

**Location:** `scripts/validate.ps1`

**Usage:**
```powershell
.\scripts\validate.ps1 -ServiceIP <service-private-ip>
```

The script automatically validates:
- `/health` endpoint (connectivity)
- `/whoami` endpoint (service identity)
- `/ask` endpoint (AI integration)

This provides fast evidence for demos and presentations.

### Evidence

Screenshots are saved in `evidence/` directory:
- Tailscale admin console showing approved route
- Terminal output of `/health` via Tailnet
- Terminal output of `/ask` with real AI/LLM response

---

## Tools & Technologies

- **Terraform** - Infrastructure as Code
- **AWS** - Cloud provider (VPC, EC2, Security Groups, Networking, NAT, IAM, SSM)
- **Tailscale** - Secure connectivity (Subnet Routing, ACLs, Tags)
- **FastAPI** - Private API Service
- **Amazon Bedrock** - LLM inference (Claude 3 Haiku)

---

## Reflection & AI Disclosure

### What I Used AI Assistance For

AI assistance (Claude) was used selectively for:

- **Bedrock request formatting**: Understanding the boto3 API structure and request/response patterns for Amazon Bedrock
- **Terraform syntax reference**: Looking up provider-specific syntax and resource dependencies
- **Documentation structure**: Organizing documentation sections and improving clarity
- **PowerShell scripting**: Syntax for the validation script and error handling patterns

### What I Owned

**All core architectural and security decisions were my own**, including:
- Designing a VPC with clear separation between public and private subnets
- Implementing least-privilege security groups so the private service is reachable only via the subnet router
- Choosing IAM instance roles instead of static API keys for Bedrock access
- Designing identity-first Tailscale ACLs that restrict access to a small, intentional group
- Selecting FastAPI as the private service and integrating it with Amazon Bedrock

**All testing and validation:**
- Iteratively deploying and refining the Terraform configuration
- Approving and validating Tailscale subnet routes
- Testing end-to-end connectivity via /health, /whoami, and /ask
- Confirming that the service is not reachable without Tailscale
- Debugging real issues encountered during deployment and using them as learning opportunities

### What I Learned

- **Tailscale simplifies networking**: No complex routing rules or VPN client configuration needed
- **ACLs are powerful**: Identity-based access is more flexible and maintainable than IP-based firewall rules
- **IAM roles eliminate secrets**: Instance roles are cleaner and more secure than managing API keys
- **Ephemeral auth keys**: Single-use, time-limited keys improve security posture
- **Infrastructure as code alignment**: Managing both cloud infrastructure and network policies in Terraform creates a cohesive, auditable system

### What alternatives I might consider

- Deploy multiple subnet routers across AZs for high availability
- Add CloudWatch logging for the FastAPI service
- Implement rate limiting on the API endpoints

---

## Notes

- This repository demonstrates a production-ready approach to secure internal service access
- No production secrets or credentials are committed to this repository
- The Tailnet used for this project is named: **`meet-private-ai-gateway`**

---

## Cleanup

To destroy all infrastructure:

```bash
cd terraform
terraform destroy
```
Type `yes` when prompted.

---
