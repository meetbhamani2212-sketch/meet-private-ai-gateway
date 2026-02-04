A short walkthrough of this project is available here:

**Demo Video walkthrough:** https://www.loom.com/share/d933de9f9e3f451bb38b32a51b9dd1b6

What the video covers:
1. Problem statement and use case  
2. Architecture overview  
3. Terraform structure and reproducibility (`terraform plan` & `terraform apply`)  
4. AWS management console (showing resources provisioned) 
5. Tailscale admin console (approved route) 
6. Live Tailnet access  private API service with below endpoints:
   - /health  - Secure connectivity through the Tailnet 
   - /whoami  - Service truly runs inside the private subnet
   - /ask     - AI/LLM Responses with Amazon Bedrock via IAM role