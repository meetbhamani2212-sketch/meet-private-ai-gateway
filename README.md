# Private AI Gateway  
*Tailscale Take-Home Assignment – Round 1*

---

## Overview

This repository contains a reproducible proof-of-concept that is being built incrementally to demonstrate how **Tailscale subnet routing** can securely provide access to a **private internal service** — in this case, an AI-powered API-without exposing that service to the public internet.

The solution mirrors a real-world commercial customer scenario: teams want to safely access internal tools such as APIs, admin services, AI-powered services or AI assistants from anywhere, while avoiding traditional VPN complexity and inbound network exposure.

---

## Current Status

The **networking and security foundation** is now in place.

At this stage, the project includes:

- An AWS VPC with clear separation between public and private subnets
- A public subnet intended for a future Tailscale subnet router
- A private subnet intended for a private FastAPI service
- Internet Gateway and routing configured only for the public subnet
- A private subnet with no direct internet route by default
- Security groups designed with least-privilege access:
  - The private service will only accept traffic from the subnet router
  - No inbound SSH is enabled by default

Application services and Tailscale routing will be added in the next steps.

---

## Architecture (High-Level)

- **AWS VPC**
  - **Public Subnet**
    - Hosts the Tailscale subnet router EC2 instance
    - Provides outbound internet access for control-plane connectivity
  - **Private Subnet**
    - Hosts the private FastAPI service
    - Has no public IPs and no internet route by default

- **Tailscale**
  - Subnet router will advertise the private subnet CIDR to the tailnet
  - Access will be governed by identity, tags, and ACLs

- **Private Service**
  - FastAPI application running on port `8000`
  - Exposes:
    - `GET /health` for connectivity validation
    - `POST /ask` for AI-powered responses backed by Amazon Bedrock

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
- The configuration is reproducible and safe to tear down using `terraform destroy`

Terraform will also be used to manage Tailscale resources in later steps, aligning with how customers automate network access and policy.

---

## Deployment & Validation

Detailed deployment and validation instructions will be added as each functional milestone is completed.

Upcoming validation steps (to be demonstrated and documented) include:
- Approving subnet routes in the Tailscale admin console
- Accessing the private service via Tailnet routing from a client device
- Verifying that the service is inaccessible from the public internet

---

## Tools & Technologies

- Terraform
- AWS (VPC, EC2, Security Groups, Networking)
- Tailscale (Subnet Routing, ACLs, Tags)
- FastAPI (Private API Service)
- Amazon Bedrock (LLM inference)

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
- The Tailnet used for this project is named: **`private-ai-gateway`**.
