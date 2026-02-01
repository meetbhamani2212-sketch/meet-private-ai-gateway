# Private AI Gateway (Tailscale Take-Home Assignment – Round 1)

This repository contains the infrastructure-as-code and documentation developed as part of a Tailscale Solutions Engineer take-home assignment.

The goal of this project is to demonstrate how Tailscale can be used to securely provide access to a private internal service (an AI-powered API) via subnet routing, without exposing services to the public internet.

## Current Status

This repository is being built incrementally.

At this stage, it contains:
- Terraform project scaffolding and baseline configuration
- Provider configuration for AWS and Tailscale
- Version locking via `.terraform.lock.hcl`

Infrastructure resources and services will be added in subsequent steps.

## Planned Architecture (High-Level)

- AWS VPC with public and private subnets
- EC2-based Tailscale subnet router advertising a private CIDR
- Private FastAPI service running in a private subnet
- AI-powered endpoint backed by Amazon Bedrock
- Secure access enforced via Tailscale identity, tags, and ACLs

## Deployment

Deployment instructions will be added as infrastructure resources are implemented and validated.

## Tools & Technologies

- Terraform
- AWS (EC2, VPC, networking)
- Tailscale (Subnet Routing, ACLs, Tags)
- FastAPI (private service)
- Amazon Bedrock (LLM inference)

## Notes

- This repository will be updated as the implementation progresses.
- No production secrets are committed to this repository.
