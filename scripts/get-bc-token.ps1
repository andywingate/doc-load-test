# get-bc-token.ps1
# Gets an OAuth2 access token for BC Cloud API using client credentials flow.
# Requires an Entra app registered in BC with a client secret.
#
# Usage:
#   $token = .\scripts\get-bc-token.ps1 -ClientSecret "your-secret"

param(
    [string]$TenantId = $env:BC_TENANT_ID,
    [string]$ClientId = $env:BC_CLIENT_ID,
    [Parameter(Mandatory=$true)]
    [string]$ClientSecret = $env:BC_CLIENT_SECRET
)

$scope = "https://api.businesscentral.dynamics.com/.default"

try {
    $tokenResponse = Invoke-RestMethod -Method POST `
        -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" `
        -Body @{
            grant_type    = "client_credentials"
            client_id     = $ClientId
            client_secret = $ClientSecret
            scope         = $scope
        }

    Write-Host "Token acquired successfully!" -ForegroundColor Green
    Write-Host "Expires in: $($tokenResponse.expires_in) seconds" -ForegroundColor Gray
    return $tokenResponse.access_token
}
catch {
    $errMsg = ""
    try { $errMsg = ($_.ErrorDetails.Message | ConvertFrom-Json).error_description } catch { $errMsg = $_.Exception.Message }
    Write-Host "Failed to acquire token: $errMsg" -ForegroundColor Red
    return $null
}
