<# 
validate.ps1
Purpose: Quick end-to-end validation for the Private AI Gateway over Tailnet.

Usage examples:
  .\validate.ps1 -ServiceIp 10.0.2.93
  .\validate.ps1 -ServiceIp 10.0.2.93 -Prompt "Explain Tailscale subnet routing in 2 sentences."
  .\validate.ps1 -ServiceIp 10.0.2.93 -TimeoutSeconds 8

Notes:
- Designed for Windows PowerShell.
- Uses Invoke-WebRequest / Invoke-RestMethod (no external dependencies).
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$ServiceIp,

  [Parameter(Mandatory = $false)]
  [int]$Port = 8000,

  [Parameter(Mandatory = $false)]
  [string]$Prompt = "Explain what a Tailscale subnet router does in simple terms and 2 sentences only",

  [Parameter(Mandatory = $false)]
  [int]$TimeoutSeconds = 6
)

$ErrorActionPreference = "Stop"

function Write-Section([string]$title) {
  Write-Host ""
  Write-Host "=== $title ==="
}

function Pass([string]$msg) {
  Write-Host ("[PASS] " + $msg)
}

function Fail([string]$msg) {
  Write-Host ("[FAIL] " + $msg)
}

function Try-JsonParse([string]$s) {
  try { return $s | ConvertFrom-Json } catch { return $null }
}

$baseUrl = "http://$ServiceIp`:$Port"

Write-Host ""
Write-Host "Private AI Gateway Validation"
Write-Host "Target: $baseUrl"
Write-Host "Timestamp: $(Get-Date -Format s)"
Write-Host ""

# 1) /health
try {
  Write-Section "/health"
  $resp = Invoke-WebRequest -Uri "$baseUrl/health" -UseBasicParsing -TimeoutSec $TimeoutSeconds
  $body = $resp.Content.Trim()

  $json = Try-JsonParse $body
  if ($null -ne $json -and $json.status -eq "ok") {
    Pass "/health returned status=ok"
  } else {
    Pass "/health reachable (response below)"
  }

  Write-Host $body
} catch {
  Fail "/health not reachable: $($_.Exception.Message)"
  exit 1
}

# 2) /whoami
try {
  Write-Section "/whoami"
  $resp = Invoke-WebRequest -Uri "$baseUrl/whoami" -UseBasicParsing -TimeoutSec $TimeoutSeconds
  $body = $resp.Content.Trim()
  $json = Try-JsonParse $body

  if ($null -ne $json) {
    $hn = $json.hostname
    $ip = $json.private_ip
    Pass "/whoami reachable (hostname=$hn, private_ip=$ip)"
  } else {
    Pass "/whoami reachable (non-JSON response)"
  }

  Write-Host $body
} catch {
  Fail "/whoami not reachable: $($_.Exception.Message)"
  exit 1
}

# 3) /ask (Bedrock)
try {
  Write-Section "/ask"
  $payloadObj = @{ prompt = $Prompt }
  $payloadJson = $payloadObj | ConvertTo-Json -Depth 5

  $respObj = Invoke-RestMethod `
    -Method POST `
    -Uri "$baseUrl/ask" `
    -ContentType "application/json" `
    -Body $payloadJson `
    -TimeoutSec $TimeoutSeconds

  # Normalize to JSON output for clean printing
  $outJson = $respObj | ConvertTo-Json -Depth 10

  # Basic sanity checks
  $hasModel = $false
  $hasAnswer = $false

  if ($null -ne $respObj.PSObject.Properties["model"]) { $hasModel = $true }
  if ($null -ne $respObj.PSObject.Properties["answer"] -and ($respObj.answer -as [string]).Length -gt 0) { $hasAnswer = $true }

  if ($hasModel -and $hasAnswer) {
    Pass "/ask returned model + non-empty answer"
  } elseif ($hasAnswer) {
    Pass "/ask returned non-empty answer"
  } else {
    Pass "/ask reachable (response below)"
  }

  Write-Host $outJson
} catch {
  Fail "/ask failed: $($_.Exception.Message)"
  Write-Host ""
  Write-Host "Tip: If /health and /whoami work but /ask fails, it is usually IAM/Bedrock permissions or model access."
  exit 1
}

Write-Host ""
Write-Host "All checks completed."
Pass "Tailnet reachability + private service validation succeeded"
