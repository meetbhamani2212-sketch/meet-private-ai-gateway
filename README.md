# Private AI Gateway  
*Tailscale Take-Home Assignment – Round 1*

---

## Overview

This repository contains a **reproducible proof-of-concept** that is being built incrementally to demonstrate how **Tailscale subnet routing** can securely provide access to a **private internal service** - in this case, an **AI-powered API designed to call Amazon Bedrock for LLM responses** - without exposing that service to the public internet.

The solution mirrors a real-world commercial customer scenario: teams want to safely access internal tools such as APIs, admin services, AI-powered services or AI assistants from anywhere, while avoiding traditional VPN complexity and inbound network exposure.

In this design, **Tailscale** acts as the secure access layer, **AWS** hosts the private application environment, and **Terraform provides repeatable Infrastructure as Code (IaC) automation** for both Taiscale and AWS resources.

---

## Current Status

The **networking, security, compute, and routing foundation is now in place.**

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
  - The private service only accepts traffic from the subnet router on port `8000`  
  - No inbound SSH is enabled by default  

The subnet router is running, advertising the private CIDR to the Tailnet, and the route has been approved in the Tailscale admin console.

End-to-end access to the private service via Tailscale has now been validated.

---

## Architecture (High-Level)

- **AWS VPC**
  - **Public Subnet**
    - Hosts the Tailscale subnet router EC2 instance
    - Provides outbound internet access for control-plane connectivity
  - **Private Subnet**
    - Hosts the private FastAPI service on EC2 instance
    - Has no public IPs and is not directly reachable from the internet  

- **Tailscale**
  - The subnet router advertises the private subnet CIDR to the Tailnet  
  - Access will be governed by identity, tags, and ACLs (managed as code)

- **Private Service**
  - FastAPI application running on port `8000`
  - Exposes:
    - `GET /health` for connectivity validation
    - `POST /ask` (currently a placeholder) for future AI-powered responses backed by Amazon Bedrock

---

## Security & Design Considerations

- **No public exposure**  
  The private service does not have a public IP and cannot be reached directly from the internet.

- **Least-privilege networking**  
  The service security group only allows inbound traffic from the subnet router security group on port `8000`.

- **SSH disabled by default**  
  The subnet router does not allow inbound SSH unless explicitly enabled for temporary debugging.

- **Intentional sequencing**  
  Networking and security are established first, followed by compute, routing, and application layers.

This mirrors how customer environments are typically designed and reviewed in production.

---

## Infrastructure as Code

All infrastructure is defined using **Terraform**.

- AWS resources are provisioned declaratively
- Provider versions are locked via `.terraform.lock.hcl`
- The configuration is reproducible and safe to tear down using `terraform apply` and `terraform destroy` respectively

**Accurate to current state:** Terraform is **already managing Tailscale resources**, including:  
- Tailscale ACL configuration (policy as code)  
- Ephemeral Tailscale authentication key used by the subnet router  

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

**Service validation (local to AWS)**
- FastAPI service starts automatically via systemd  
- `GET /health` returns:
  ```json
  {"status":"ok"}

**Tailscale validation (completed)**
- Subnet router appears in the Tailscale admin console
- The private CIDR (`10.0.2.0/24`) is advertised **and approved** in the Tailnet
- End-to-end Tailnet validation completed
- From a client device on the Tailnet, the private service was successfully accessed using its private IP:
```bash
  curl http://<service-private-ip>:8000/health
```
  **Response**:
```json
  {"status":"ok"}
```
- The service remains unreachable from the public internet (no public IP and restricted security group)

**Next validation activities**:
- Integrating POST `/ask` with Amazon Bedrock to return real LLM responses
---

## Tools & Technologies

- Terraform
- AWS (VPC, EC2, Security Groups, Networking, NAT, IAM, SSM)
- Tailscale (Subnet Routing, ACLs, Tags)
- FastAPI (Private API Service)
- Amazon Bedrock (LLM inference - — planned integration)

---

## Reflection & AI Disclosure

AI assistance was used selectively for:
- Terraform syntax reference
- Documentation clarity and structure
- Validation checklist preparation

All infrastructure design decisions, security boundaries, and validation steps were reviewed and verified manually.

---

## Notes

- This repository is intentionally built step-by-step to mirror real customer engagements.
- No production secrets or credentials are committed to this repository.
- The Tailnet used for this project is named: **`meet-private-ai-gateway`**.
