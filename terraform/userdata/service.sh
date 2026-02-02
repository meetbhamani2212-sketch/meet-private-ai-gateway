#!/bin/bash
set -euo pipefail

dnf -y update
dnf -y install python3 python3-pip

# App directory
mkdir -p /opt/private-api
cat > /opt/private-api/app.py << 'PY'
from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI()

class AskRequest(BaseModel):
    prompt: str

@app.get("/health")
def health():
    return {"status": "ok"}

# Bedrock will be wired later
@app.post("/ask")
def ask(req: AskRequest):
    return {
        "model": "bedrock (planned)",
        "answer": f"Received prompt: {req.prompt}. (Bedrock integration added later)"
    }
PY

python3 -m pip install --upgrade pip
python3 -m pip install fastapi uvicorn boto3

cat > /etc/systemd/system/private-api.service << 'SVC'
[Unit]
Description=Private FastAPI Service
After=network-online.target
Wants=network-online.target

[Service]
WorkingDirectory=/opt/private-api
ExecStart=/usr/bin/python3 -m uvicorn app:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
SVC

systemctl daemon-reload
systemctl enable private-api
systemctl start private-api
