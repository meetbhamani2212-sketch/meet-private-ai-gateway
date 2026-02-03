#!/bin/bash
set -euo pipefail

# Log everything (super helpful for debugging userdata)
exec > >(tee /var/log/private-api-userdata.log | logger -t private-api-userdata -s 2>/dev/console) 2>&1
set -x

dnf -y install python3 python3-pip

# App directory
mkdir -p /opt/private-api

cat > /opt/private-api/app.py << 'PY'
import os
import json
import time
import boto3
import socket
import urllib.request
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI()

AWS_REGION = os.environ.get("AWS_REGION", "ca-central-1")
BEDROCK_MODEL_ID = os.environ.get("BEDROCK_MODEL_ID", "anthropic.claude-3-haiku-20240307-v1:0")

brt = boto3.client("bedrock-runtime", region_name=AWS_REGION)

class AskRequest(BaseModel):
    prompt: str

def imds_get(path: str, timeout: float = 1.0) -> str:
    base = "http://169.254.169.254"
    try:
        # IMDSv2 token
        token_req = urllib.request.Request(
            f"{base}/latest/api/token",
            method="PUT",
            headers={"X-aws-ec2-metadata-token-ttl-seconds": "60"},
        )
        with urllib.request.urlopen(token_req, timeout=timeout) as r:
            token = r.read().decode("utf-8")

        # Metadata request
        data_req = urllib.request.Request(
            f"{base}{path}",
            headers={"X-aws-ec2-metadata-token": token},
        )
        with urllib.request.urlopen(data_req, timeout=timeout) as r:
            return r.read().decode("utf-8")
    except Exception:
        return "unknown"

@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/whoami")
def whoami():
    return {
        "hostname": socket.gethostname(),
        "private_ip": imds_get("/latest/meta-data/local-ipv4"),
        "instance_id": imds_get("/latest/meta-data/instance-id"),
        "service": "meet-private-ai-gateway",
        "aws_region": AWS_REGION,
        "model": BEDROCK_MODEL_ID,
        "note": "Running in private subnet behind Tailscale subnet router",
    }

@app.post("/ask")
def ask(req: AskRequest):
    prompt = (req.prompt or "").strip()
    if not prompt:
        raise HTTPException(status_code=400, detail="prompt is required")

    payload = {
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": 300,
        "temperature": 0.2,
        "messages": [
            {"role": "user", "content": [{"type": "text", "text": prompt}]}
        ],
    }

    try:
        t0 = time.time()
        resp = brt.invoke_model(
            modelId=BEDROCK_MODEL_ID,
            contentType="application/json",
            accept="application/json",
            body=json.dumps(payload).encode("utf-8"),
        )
        latency_ms = int((time.time() - t0) * 1000)

        data = json.loads(resp["body"].read())

        answer = ""
        if isinstance(data, dict) and isinstance(data.get("content"), list) and data["content"]:
            first = data["content"][0]
            if isinstance(first, dict):
                answer = first.get("text", "")

        return {"model": BEDROCK_MODEL_ID, "latency_ms": latency_ms, "answer": answer or "(empty response)"}

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Bedrock invoke failed: {str(e)}")
PY

# Create venv to avoid rpm-managed pip conflicts
python3 -m venv /opt/private-api/venv
/opt/private-api/venv/bin/pip install --upgrade pip
/opt/private-api/venv/bin/pip install fastapi uvicorn boto3

cat > /etc/systemd/system/private-api.service << 'SVC'
[Unit]
Description=Private FastAPI Service
After=network-online.target
Wants=network-online.target

[Service]
WorkingDirectory=/opt/private-api
Environment=AWS_REGION=ca-central-1
Environment=BEDROCK_MODEL_ID=anthropic.claude-3-haiku-20240307-v1:0
ExecStart=/opt/private-api/venv/bin/python -m uvicorn app:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
SVC

systemctl daemon-reload
systemctl enable --now private-api.service

# Print status into userdata logs for easy troubleshooting
systemctl status private-api.service --no-pager || true
