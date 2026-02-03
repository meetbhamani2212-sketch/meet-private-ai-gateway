# Private AI Gateway  
*Tailscale Take-Home Assignment – Round 1*

---

## Overview

This repository contains a **reproducible proof-of-concept** that demonstrates how **Tailscale subnet routing** can securely provide access to a **private internal service** - in this case, an **AI-powered FastAPI designed to call Amazon Bedrock for real LLM responses** - without exposing that service to the public internet.

The solution mirrors **a real-world commercial customer scenario**: Teams want to safely access internal tools such as APIs, admin services, AI-powered services or AI assistants from anywhere, while avoiding traditional VPN complexity, inbound network exposure, and shared credentials.

In this design, **Tailscale** provides identity-based secure connectivity and acts as the secure access layer, **AWS** hosts the isolated application environment, and **Terraform** delivers repeatable **Infrastructure as Code (IaC)** for **both AWS and Tailscale resources**

---

## Current Status

The **networking, security, compute, routing, and application layers are now fully implemented.**

At this stage, the project includes:

- An AWS VPC with clear separation between public and private subnets  
- A **public subnet hosting a Tailscale subnet router EC2 instance**  
- A **private subnet hosting a FastAPI service EC2 instance**  
- An Internet Gateway attached to the VPC  
- Route tables configured so:
  - the public subnet can reach the internet  
  - the private subnet remains private by default  
- A **NAT Gateway** enabling the private instance to install dependencies and communicate with AWS services  
- Security groups designed with least-privilege access:
  - The private service accepts inbound traffic **only from the subnet router on port 8000** `  
  - No inbound SSH is enabled by default
  - **Tailscale subnet route `10.0.2.0/24`) advertised and approved** in the Tailnet  
- **FastAPI service running under systemd**  
- **Real AI/LLM integration with Amazon Bedrock (Claude)** via IAM instance role (no secrets in code)  
- Additional observability endpoint `/whoami`) for clear demos and debugging   

The tailscale subnet router is running as EC2 instance in AWS, advertising the private CIDR to the Tailnet, and the route has been approved in the Tailscale admin console.

**End-to-end access to the private service via Tailscale has now been validated**

---

## Architecture (High-Level)

### AWS VPC
  - **Public Subnet**
    - Hosts the Tailscale subnet router EC2 instance
    - Provides outbound internet access for control-plane connectivity
  - **Private Subnet**
    - Hosts the private FastAPI service on EC2 instance
    - Has no public IPs and is not directly reachable from the internet  

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

---

## Security & Design Considerations

- **No public exposure**  
  The private service does not have a public IP and cannot be reached directly from the internet.

- **Least-privilege networking**  
  The service security group **only** allows inbound traffic **from the subnet router security group on port `8000`**.

- **Identity-first access**  
  Access to the private service occurs via Tailscale identity, not network perimeter rules.

- **SSH disabled by default**  
  The subnet router does not allow inbound SSH unless explicitly enabled for temporary debugging.

- **Credentialless design**  
  The service EC2 instance uses an **IAM instance role** to call LLM Model in Amazon Bedrock - **no API keys in code or GitHub**.

- **Intentional sequencing**  
  Networking and security are established first, followed by compute, routing, and application layers.

---

## Infrastructure as Code

All infrastructure is defined using **Terraform**.

- AWS resources are provisioned declaratively
- Provider versions are locked via `.terraform.lock.hcl`
- Environment can be recreated from scratch with:
```bash
  terraform apply
```
  and torn down safely with:
```bash
  terraform destroy
```

**Tailscale is also managed via Terraform**, including:

* Tailscale ACL configuration (policy as code)
* Ephemeral Tailscale authentication key used by the subnet router
* Device tagging

This aligns with real customer practices where both cloud infrastructure and Tailscale policies are automated together.

---

## Deployment & Validation

Detailed deployment and validation instructions will be added later as each functional milestone will get completed.

### What has been deployed and validated so far 

**Infrastructure validation**
- VPC, subnets, routing, and security groups created via Terraform  
- NAT Gateway operational for private egress  
- Two EC2 instances successfully provisioned:
  - Tailscale subnet router in the public subnet  
  - FastAPI service in the private subnet  

**Service validation (inside AWS)**
- FastAPI service starts automatically via systemd  
- `GET /health` returns:
  ```json
  {"status":"ok"}

**Tailscale validation**
- Subnet router appears in the Tailscale admin console
- The private CIDR (`10.0.2.0/24`) is advertised **and approved** in the Tailnet
- End-to-end Tailnet validation completed
- From a client device on the Tailnet, the private service was successfully accessed using its private IP:
```bash
  curl http://<service-private-ip>:8000/health
```
  - **Response**:
```json
  {"status":"ok"}
```
- The service remains unreachable from the public internet (no public IP and restricted security group)



**Real AI/LLM responses with Amazon Bedrock validation**

From a client on the Tailnet:
```bash
Invoke-RestMethod `
  -Method POST `
  -Uri "http://<service-private-ip>/ask" `
  -ContentType "application/json" `
  -Body '{"prompt":"Explain what a Tailscale subnet router does in simple terms"}'|
ConvertTo-Json -Depth 5
```

Typical response:
```json
{
  "model": "anthropic.claude-3-haiku-20240307-v1:0",
  "latency_ms": 380,
  "answer": "A subnet router shares access to private IP ranges with your Tailnet so approved users can reach internal services without opening inbound firewall rules."
}
```
#### Observability demo endpoint
```bash
curl http://<service-private-ip>:8000/whoami
```

Example output:
```json
{
  "hostname": "ip-10-0-2-27.ca-central-1.compute.internal",
  "private_ip": "10.0.2.27",
  "service": "private-ai-gateway",
  "note": "Running in private subnet behind Tailscale subnet router"
}
```

This clearly demonstrates that requests originate from a private EC2 inside AWS accessed only via Tailscale.

---

## Tools & Technologies

- **Terraform**
- **AWS** (VPC, EC2, Security Groups, Networking, NAT, IAM, SSM)
- **Tailscale** (Subnet Routing, ACLs, Tags)
- **FastAPI** (Private API Service)
- **Amazon Bedrock** (LLM inference - Claude 3 Haiku)

---

## Reflection & AI Disclosure

AI assistance was used selectively for:

- Bedrock request formatting and boto3 patterns
- Terraform syntax reference
- Documentation clarity and structure
- Validation checklist preparation

All architecture decisions, security boundaries, IAM design, and validation steps were reviewed and validated manually.

---

## Notes

- This repository is intentionally built step-by-step to mirror real customer engagements.
- No production secrets or credentials are committed to this repository.
- The Tailnet used for this project is named: **`meet-private-ai-gateway`**.
