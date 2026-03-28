---
description: "Use when writing or modifying PowerShell scripts for BC API testing, OAuth2 authentication, or load testing. Covers client credentials flow, debug logging, and error handling patterns."
applyTo: "scripts/**/*.ps1"
---
# PowerShell / BC API Scripting Conventions

## General
- Pure PowerShell only — no k6, no JavaScript, no external test frameworks
- Use `Invoke-RestMethod` for API calls, not `Invoke-WebRequest`
- Always use `$ErrorActionPreference = "Stop"`

## Authentication
- Always use OAuth2 client credentials flow (not device code, not delegated)
- Token acquisition via separate `get-bc-token.ps1` helper
- Scope: `https://api.businesscentral.dynamics.com/.default`

## API Calls
- Standard BC API: `https://api.businesscentral.dynamics.com/v2.0/{tenant}/{env}/api/v2.0/companies({id})/`
- Custom API: `https://api.businesscentral.dynamics.com/v2.0/{tenant}/{env}/api/defaultpublisher/docloadtest/v1.0/companies({id})/`
- Use standard BC API for read/discovery (customers, vendors, items)
- Use custom API for document creation (salesOrdersLT, purchaseOrdersLT)
- Always include retry logic with 429 rate-limit backoff
- Create header first, then POST lines to the sub-entity URL: `entitySet({headerId})/linesEntitySet`

## Debug Logging
- All scripts must support a `-DebugLog` switch parameter
- Use a `Write-Debug-Log` helper that only emits when `-DebugLog` is set
- Debug output must include: timestamp (HH:mm:ss.fff), HTTP method, URL, request body, response status, elapsed time, and full error body on failure
- Format: `[DBG {timestamp}] {message}` in DarkGray

## Error Handling
- Always capture and surface the full error body from BC API responses (`$_.ErrorDetails.Message`)
- Never swallow errors silently — log the status code and error detail even during retries
- On 400 errors, do NOT retry blindly — log the error detail so the root cause is visible
