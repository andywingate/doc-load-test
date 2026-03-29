# bc-load-test.ps1
# PowerShell load test script for BC Cloud API — no external tools needed.
# Uses the standard BC v2.0 API to create/read Sales Orders and Purchase Orders.
#
# Usage:
#   # Quick validation (1 SO + 1 PO):
#   .\scripts\bc-load-test.ps1 -Mode Validate
#
#   # Full stress test:
#   .\scripts\bc-load-test.ps1 -Mode Full -SalesOrders 100 -PurchaseOrders 100 -LinesPerDoc 5
#
#   # Read-only stress test:
#   .\scripts\bc-load-test.ps1 -Mode Read
#
#   # Custom concurrent test:
#   .\scripts\bc-load-test.ps1 -Mode Concurrent -ConcurrentJobs 5 -SalesOrders 50
#
#   # Endurance test (repeating 10-min SO/PO cycles, max 2 hours):
#   .\scripts\bc-load-test.ps1 -Mode Endurance -CycleMinutes 10 -EnduranceMaxHours 2
#
#   # Deep insert test (header + lines in 1 API call):
#   .\scripts\bc-load-test.ps1 -Mode DeepInsert -RaceMinutes 5 -LinesPerDoc 3

param(
    [ValidateSet("Validate", "Full", "Read", "Concurrent", "Race", "Endurance", "DeepInsert")]
    [string]$Mode = "Validate",

    [string]$TenantId = $env:BC_TENANT_ID,
    [string]$ClientId = $env:BC_CLIENT_ID,
    [string]$ClientSecret = $env:BC_CLIENT_SECRET,
    [string]$Environment = $(if ($env:BC_ENVIRONMENT) { $env:BC_ENVIRONMENT } else { "Production" }),
    [string]$CompanyName = $(if ($env:BC_COMPANY) { $env:BC_COMPANY } else { "docs-test" }),

    [string]$CustomerNo = "",
    [string]$VendorNo = "",
    [string]$ItemNo = "",

    [int]$SalesOrders = 10,
    [int]$PurchaseOrders = 10,
    [int]$LinesPerDoc = 3,
    [int]$ConcurrentJobs = 3,
    [int]$RaceMinutes = 5,
    [int]$CycleMinutes = 10,
    [int]$EnduranceMaxMinutes = 120,
    [int]$RetryCount = 3,
    [int]$RetryDelaySeconds = 10,
    [switch]$DebugLog,
    [switch]$UseDeepInsert
)

$ErrorActionPreference = "Stop"

function Write-Debug-Log {
    param([string]$Message)
    if ($DebugLog) {
        Write-Host "  [DBG $(Get-Date -Format 'HH:mm:ss.fff')] $Message" -ForegroundColor DarkGray
    }
}

# ─────────────────────────── Auth ───────────────────────────

Write-Host "=== BC API Load Test ===" -ForegroundColor Cyan
Write-Host "Environment: $Environment | Company: $CompanyName | Mode: $Mode" -ForegroundColor Gray
Write-Host ""

Write-Host "Acquiring OAuth2 token via client credentials..." -ForegroundColor Yellow
$token = & "$PSScriptRoot\get-bc-token.ps1" -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret

if (-not $token) {
    Write-Host "Failed to acquire token. Exiting." -ForegroundColor Red
    exit 1
}

$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type"  = "application/json"
    "Accept"        = "application/json"
}

# ─────────────────────────── API URLs ───────────────────────────

$bcRoot = "https://api.businesscentral.dynamics.com/v2.0/$TenantId/$Environment"
$apiBase = "$bcRoot/api/v2.0"

# ─────────────────────────── Resolve Company ───────────────────────────

Write-Host "Resolving company '$CompanyName'..." -ForegroundColor Yellow
$companiesUrl = "$apiBase/companies?`$filter=name eq '$CompanyName'"
$companyResp = Invoke-RestMethod -Uri $companiesUrl -Headers $headers -Method Get

if (-not $companyResp.value -or $companyResp.value.Count -eq 0) {
    Write-Host "Company '$CompanyName' not found. Available companies:" -ForegroundColor Red
    $allCompanies = Invoke-RestMethod -Uri "$apiBase/companies" -Headers $headers -Method Get
    $allCompanies.value | ForEach-Object { Write-Host "  - $($_.name) ($($_.id))" }
    exit 1
}

$companyId = $companyResp.value[0].id
Write-Host "Resolved: $CompanyName -> $companyId" -ForegroundColor Green
Write-Host ""

$companyApi = "$apiBase/companies($companyId)"
$customApi = "$bcRoot/api/defaultpublisher/docloadtest/v1.0/companies($companyId)"

# ─────────────────────────── Batch ID ───────────────────────────

$BatchId = "LT-" + (Get-Date -Format "yyyyMMdd-HHmmss")
Write-Host "Batch ID: $BatchId" -ForegroundColor Cyan
Write-Host ""

# ─────────────────────────── Helpers ───────────────────────────

function Invoke-BCApi {
    param(
        [string]$Method,
        [string]$Url,
        [object]$Body = $null,
        [int]$MaxRetries = $RetryCount
    )

    $jsonBody = $null
    if ($Body) {
        $jsonBody = ($Body | ConvertTo-Json -Depth 10)
    }

    Write-Debug-Log "$Method $Url"
    if ($jsonBody) { Write-Debug-Log "  Body: $jsonBody" }

    for ($attempt = 0; $attempt -le $MaxRetries; $attempt++) {
        try {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $params = @{
                Uri            = $Url
                Method         = $Method
                Headers        = $headers
                TimeoutSec     = 15
            }
            if ($jsonBody) {
                $params.Body = $jsonBody
            }

            $response = Invoke-RestMethod @params
            $sw.Stop()
            Write-Debug-Log "  -> 200 OK (${($sw.ElapsedMilliseconds)}ms)"
            return @{ Success = $true; Data = $response; StatusCode = 200; Retries = $attempt }
        }
        catch {
            $sw.Stop()
            $statusCode = 0
            try { $statusCode = [int]$_.Exception.Response.StatusCode.value__ } catch { }
            $errorBody = ""
            try { $errorBody = $_.ErrorDetails.Message } catch { $errorBody = $_.Exception.Message }

            Write-Debug-Log "  -> $statusCode FAILED (${($sw.ElapsedMilliseconds)}ms): $errorBody"

            if ($statusCode -eq 429) {
                $retryAfter = $RetryDelaySeconds
                try {
                    $retryAfter = [int]$_.Exception.Response.Headers["Retry-After"]
                } catch { }
                Write-Host "  Rate limited (429). Waiting ${retryAfter}s... (attempt $($attempt+1)/$MaxRetries)" -ForegroundColor DarkYellow
                Start-Sleep -Seconds $retryAfter
                continue
            }

            # 400 Bad Request = code/data bug, not transient — don't retry
            if ($statusCode -eq 400) {
                Write-Host "  Bad Request (400): $errorBody" -ForegroundColor Red
                return @{ Success = $false; StatusCode = $statusCode; Error = $errorBody; Retries = $attempt }
            }

            if ($attempt -eq $MaxRetries) {
                return @{ Success = $false; StatusCode = $statusCode; Error = $errorBody; Retries = $attempt }
            }

            Write-Host "  Request failed ($statusCode). Retrying in 2s... (attempt $($attempt+1)/$MaxRetries)" -ForegroundColor DarkYellow
            Start-Sleep -Seconds 2
        }
    }
}

function Write-TestResult {
    param(
        [string]$TestName,
        [datetime]$Start,
        [datetime]$End,
        [int]$SuccessCount,
        [int]$ErrorCount,
        [int]$TotalDocs,
        [int]$TotalLines
    )

    $duration = ($End - $Start).TotalMilliseconds
    $docsPerSec = if ($duration -gt 0 -and $TotalDocs -gt 0) { [math]::Round(($TotalDocs / $duration) * 1000, 2) } else { 0 }
    $linesPerSec = if ($duration -gt 0 -and $TotalLines -gt 0) { [math]::Round(($TotalLines / $duration) * 1000, 2) } else { 0 }

    Write-Host ""
    Write-Host "─────────────────────────────────────────" -ForegroundColor Cyan
    Write-Host "  $TestName" -ForegroundColor Cyan
    Write-Host "─────────────────────────────────────────" -ForegroundColor Cyan
    Write-Host "  Duration:       $([math]::Round($duration))ms ($([math]::Round($duration/1000, 1))s)"
    Write-Host "  Success:        $SuccessCount"
    Write-Host "  Errors:         $ErrorCount" -ForegroundColor $(if ($ErrorCount -gt 0) { "Red" } else { "Green" })
    if ($TotalDocs -gt 0) {
        Write-Host "  Documents:      $TotalDocs"
        Write-Host "  Docs/sec:       $docsPerSec"
    }
    if ($TotalLines -gt 0) {
        Write-Host "  Total Lines:    $TotalLines"
        Write-Host "  Lines/sec:      $linesPerSec"
    }
    Write-Host "─────────────────────────────────────────" -ForegroundColor Cyan
}

# ─────────────────────────── Create a Sales Order ───────────────────────────

function New-TestSalesOrder {
    param(
        [string]$CustNo,
        [string]$ItmNo,
        [int]$Lines
    )

    # Create SO header via custom API
    Write-Debug-Log "Creating SO header for customer $CustNo, batch $BatchId"
    $headerBody = @{
        customerNumber         = $CustNo
        orderDate              = (Get-Date -Format "yyyy-MM-dd")
        externalDocumentNumber = $BatchId
    }
    $headerResult = Invoke-BCApi -Method Post -Url "$customApi/salesOrdersLT" -Body $headerBody
    if (-not $headerResult.Success) {
        Write-Debug-Log "SO header FAILED: $($headerResult.StatusCode) - $($headerResult.Error)"
        return @{ Success = $false; Error = "Header: $($headerResult.Error)" }
    }

    $soId = $headerResult.Data.id
    $soNo = $headerResult.Data.number
    $lineErrors = 0
    Write-Debug-Log "SO $soNo created (id=$soId). Adding $Lines lines..."

    # Create lines
    for ($l = 1; $l -le $Lines; $l++) {
        $lineBody = @{
            lineType   = "Item"
            itemNumber = $ItmNo
            quantity   = 1
        }
        $lineResult = Invoke-BCApi -Method Post -Url "$customApi/salesOrdersLT($soId)/salesOrderLinesLT" -Body $lineBody
        if (-not $lineResult.Success) {
            $lineErrors++
            Write-Debug-Log "SO $soNo line $l FAILED: $($lineResult.StatusCode) - $($lineResult.Error)"
        } else {
            Write-Debug-Log "SO $soNo line $l OK"
        }
    }

    Write-Debug-Log "SO $soNo complete: $Lines lines, $lineErrors errors"
    return @{ Success = $true; OrderNo = $soNo; LineErrors = $lineErrors }
}

# ─────────────────────────── Create a Purchase Order ───────────────────────────

function New-TestPurchaseOrder {
    param(
        [string]$VndNo,
        [string]$ItmNo,
        [int]$Lines
    )

    # Create PO header via custom API
    Write-Debug-Log "Creating PO header for vendor $VndNo, batch $BatchId"
    $headerBody = @{
        vendorNumber     = $VndNo
        orderDate        = (Get-Date -Format "yyyy-MM-dd")
        vendorShipmentNo = $BatchId
    }
    $headerResult = Invoke-BCApi -Method Post -Url "$customApi/purchaseOrdersLT" -Body $headerBody
    if (-not $headerResult.Success) {
        Write-Debug-Log "PO header FAILED: $($headerResult.StatusCode) - $($headerResult.Error)"
        return @{ Success = $false; Error = "Header: $($headerResult.Error)" }
    }

    $poId = $headerResult.Data.id
    $poNo = $headerResult.Data.number
    $lineErrors = 0
    Write-Debug-Log "PO $poNo created (id=$poId). Adding $Lines lines..."

    # Create lines
    for ($l = 1; $l -le $Lines; $l++) {
        $lineBody = @{
            lineType   = "Item"
            itemNumber = $ItmNo
            quantity   = 1
        }
        $lineResult = Invoke-BCApi -Method Post -Url "$customApi/purchaseOrdersLT($poId)/purchaseOrderLinesLT" -Body $lineBody
        if (-not $lineResult.Success) {
            $lineErrors++
            Write-Debug-Log "PO $poNo line $l FAILED: $($lineResult.StatusCode) - $($lineResult.Error)"
        } else {
            Write-Debug-Log "PO $poNo line $l OK"
        }
    }

    Write-Debug-Log "PO $poNo complete: $Lines lines, $lineErrors errors"
    return @{ Success = $true; OrderNo = $poNo; LineErrors = $lineErrors }
}

# ─────────────────────────── Deep Insert (header + lines in 1 call) ───────────────────────────

function New-TestSalesOrderDeepInsert {
    param(
        [string]$CustNo,
        [string]$ItmNo,
        [int]$Lines
    )

    $linesArray = @()
    for ($l = 1; $l -le $Lines; $l++) {
        $linesArray += @{
            lineType   = "Item"
            itemNumber = $ItmNo
            quantity   = 1
        }
    }

    $body = @{
        customerNumber         = $CustNo
        orderDate              = (Get-Date -Format "yyyy-MM-dd")
        externalDocumentNumber = $BatchId
        salesOrderLinesDI      = $linesArray
    }

    Write-Debug-Log "Deep insert SO for customer $CustNo, batch $BatchId, $Lines lines"
    $result = Invoke-BCApi -Method Post -Url "$customApi/salesOrdersDI" -Body $body
    if (-not $result.Success) {
        Write-Debug-Log "Deep insert SO FAILED: $($result.StatusCode) - $($result.Error)"
        return @{ Success = $false; Error = $result.Error; LineErrors = 0; Retries = $result.Retries }
    }

    $soNo = $result.Data.number
    Write-Debug-Log "Deep insert SO $soNo complete with $Lines lines"
    return @{ Success = $true; OrderNo = $soNo; LineErrors = 0; Retries = $result.Retries }
}

function New-TestPurchaseOrderDeepInsert {
    param(
        [string]$VndNo,
        [string]$ItmNo,
        [int]$Lines
    )

    $linesArray = @()
    for ($l = 1; $l -le $Lines; $l++) {
        $linesArray += @{
            lineType   = "Item"
            itemNumber = $ItmNo
            quantity   = 1
        }
    }

    $body = @{
        vendorNumber          = $VndNo
        orderDate             = (Get-Date -Format "yyyy-MM-dd")
        vendorShipmentNo      = $BatchId
        purchaseOrderLinesDI  = $linesArray
    }

    Write-Debug-Log "Deep insert PO for vendor $VndNo, batch $BatchId, $Lines lines"
    $result = Invoke-BCApi -Method Post -Url "$customApi/purchaseOrdersDI" -Body $body
    if (-not $result.Success) {
        Write-Debug-Log "Deep insert PO FAILED: $($result.StatusCode) - $($result.Error)"
        return @{ Success = $false; Error = $result.Error; LineErrors = 0; Retries = $result.Retries }
    }

    $poNo = $result.Data.number
    Write-Debug-Log "Deep insert PO $poNo complete with $Lines lines"
    return @{ Success = $true; OrderNo = $poNo; LineErrors = 0; Retries = $result.Retries }
}

# ─────────────────────────── Discover Test Data ───────────────────────────

function Get-TestCustomer {
    if ($CustomerNo) { return $CustomerNo }

    Write-Host "  Looking up first available customer..." -ForegroundColor Gray
    $resp = Invoke-BCApi -Method Get -Url "$companyApi/customers?`$top=1&`$select=number,displayName"
    if ($resp.Success -and $resp.Data.value.Count -gt 0) {
        $no = $resp.Data.value[0].number
        Write-Host "  Using customer: $no ($($resp.Data.value[0].displayName))" -ForegroundColor Gray
        return $no
    }
    Write-Host "  No customers found! Please specify -CustomerNo" -ForegroundColor Red
    exit 1
}

function Get-TestVendor {
    if ($VendorNo) { return $VendorNo }

    Write-Host "  Looking up first available vendor..." -ForegroundColor Gray
    $resp = Invoke-BCApi -Method Get -Url "$companyApi/vendors?`$top=1&`$select=number,displayName"
    if ($resp.Success -and $resp.Data.value.Count -gt 0) {
        $no = $resp.Data.value[0].number
        Write-Host "  Using vendor: $no ($($resp.Data.value[0].displayName))" -ForegroundColor Gray
        return $no
    }
    Write-Host "  No vendors found! Please specify -VendorNo" -ForegroundColor Red
    exit 1
}

function Get-TestItem {
    if ($ItemNo) { return $ItemNo }

    Write-Host "  Looking up first available item..." -ForegroundColor Gray
    $resp = Invoke-BCApi -Method Get -Url "$companyApi/items?`$top=1&`$filter=type eq 'Inventory'&`$select=number,displayName"
    if ($resp.Success -and $resp.Data.value.Count -gt 0) {
        $no = $resp.Data.value[0].number
        Write-Host "  Using item: $no ($($resp.Data.value[0].displayName))" -ForegroundColor Gray
        return $no
    }
    Write-Host "  No items found! Please specify -ItemNo" -ForegroundColor Red
    exit 1
}

# ─────────────────────────── Test Modes ───────────────────────────

function Start-ValidateTest {
    Write-Host "=== VALIDATION TEST ===" -ForegroundColor Cyan
    Write-Host "Creating 1 SO and 1 PO with $LinesPerDoc lines each to validate the API connection." -ForegroundColor Gray
    Write-Host ""

    $custNo = Get-TestCustomer
    $vndNo = Get-TestVendor
    $itmNo = Get-TestItem
    Write-Host ""

    # Test Sales Order
    Write-Host "Creating Sales Order..." -ForegroundColor Yellow
    $soStart = Get-Date
    $soResult = New-TestSalesOrder -CustNo $custNo -ItmNo $itmNo -Lines $LinesPerDoc
    $soEnd = Get-Date

    if ($soResult.Success) {
        Write-Host "  SO $($soResult.OrderNo) created successfully ($LinesPerDoc lines) in $([math]::Round(($soEnd - $soStart).TotalMilliseconds))ms" -ForegroundColor Green
    } else {
        Write-Host "  SO creation FAILED: $($soResult.Error)" -ForegroundColor Red
    }

    # Test Purchase Order
    Write-Host "Creating Purchase Order..." -ForegroundColor Yellow
    $poStart = Get-Date
    $poResult = New-TestPurchaseOrder -VndNo $vndNo -ItmNo $itmNo -Lines $LinesPerDoc
    $poEnd = Get-Date

    if ($poResult.Success) {
        Write-Host "  PO $($poResult.OrderNo) created successfully ($LinesPerDoc lines) in $([math]::Round(($poEnd - $poStart).TotalMilliseconds))ms" -ForegroundColor Green
    } else {
        Write-Host "  PO creation FAILED: $($poResult.Error)" -ForegroundColor Red
    }

    # Test Read
    Write-Host "Reading Sales Orders..." -ForegroundColor Yellow
    $readStart = Get-Date
    $readResult = Invoke-BCApi -Method Get -Url "$companyApi/salesOrders?`$top=10"
    $readEnd = Get-Date

    if ($readResult.Success) {
        Write-Host "  Read $($readResult.Data.value.Count) sales orders in $([math]::Round(($readEnd - $readStart).TotalMilliseconds))ms" -ForegroundColor Green
    } else {
        Write-Host "  Read FAILED: $($readResult.Error)" -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "=== Validation Complete ===" -ForegroundColor Cyan
    Write-Host "API connection is " -NoNewline
    if ($soResult.Success -and $poResult.Success -and $readResult.Success) {
        Write-Host "WORKING" -ForegroundColor Green
    } else {
        Write-Host "FAILING" -ForegroundColor Red
    }
}

function Start-FullTest {
    Write-Host "=== FULL LOAD TEST ===" -ForegroundColor Cyan
    Write-Host "Creating $SalesOrders SOs + $PurchaseOrders POs with $LinesPerDoc lines each (sequential)" -ForegroundColor Gray
    Write-Host ""

    $custNo = Get-TestCustomer
    $vndNo = Get-TestVendor
    $itmNo = Get-TestItem
    Write-Host ""

    # Sales Orders
    if ($SalesOrders -gt 0) {
        Write-Host "Creating $SalesOrders Sales Orders..." -ForegroundColor Yellow
        $soStart = Get-Date
        $soSuccess = 0; $soErrors = 0

        for ($i = 1; $i -le $SalesOrders; $i++) {
            $result = New-TestSalesOrder -CustNo $custNo -ItmNo $itmNo -Lines $LinesPerDoc
            if ($result.Success) { $soSuccess++ } else { $soErrors++ }

            $pct = [math]::Round(($i / $SalesOrders) * 100)
            Write-Progress -Activity "Creating Sales Orders" -Status "$i / $SalesOrders ($pct%)" -PercentComplete $pct
        }

        Write-Progress -Activity "Creating Sales Orders" -Completed
        Write-TestResult -TestName "Sales Order Creation" -Start $soStart -End (Get-Date) `
            -SuccessCount $soSuccess -ErrorCount $soErrors `
            -TotalDocs $soSuccess -TotalLines ($soSuccess * $LinesPerDoc)
    }

    # Purchase Orders
    if ($PurchaseOrders -gt 0) {
        Write-Host "Creating $PurchaseOrders Purchase Orders..." -ForegroundColor Yellow
        $poStart = Get-Date
        $poSuccess = 0; $poErrors = 0

        for ($i = 1; $i -le $PurchaseOrders; $i++) {
            $result = New-TestPurchaseOrder -VndNo $vndNo -ItmNo $itmNo -Lines $LinesPerDoc
            if ($result.Success) { $poSuccess++ } else { $poErrors++ }

            $pct = [math]::Round(($i / $PurchaseOrders) * 100)
            Write-Progress -Activity "Creating Purchase Orders" -Status "$i / $PurchaseOrders ($pct%)" -PercentComplete $pct
        }

        Write-Progress -Activity "Creating Purchase Orders" -Completed
        Write-TestResult -TestName "Purchase Order Creation" -Start $poStart -End (Get-Date) `
            -SuccessCount $poSuccess -ErrorCount $poErrors `
            -TotalDocs $poSuccess -TotalLines ($poSuccess * $LinesPerDoc)
    }
}

function Start-ReadTest {
    Write-Host "=== READ STRESS TEST ===" -ForegroundColor Cyan
    Write-Host "Reading all Sales Orders and Purchase Orders page by page." -ForegroundColor Gray
    Write-Host ""

    # Read all Sales Orders
    Write-Host "Reading Sales Orders..." -ForegroundColor Yellow
    $soStart = Get-Date
    $soCount = 0
    $nextUrl = "$companyApi/salesOrders?`$top=100"

    while ($nextUrl) {
        $result = Invoke-BCApi -Method Get -Url $nextUrl
        if (-not $result.Success) {
            Write-Host "  Read failed at $soCount docs: $($result.Error)" -ForegroundColor Red
            break
        }
        $soCount += $result.Data.value.Count
        $nextUrl = $result.Data.'@odata.nextLink'
        Write-Host "  Read $soCount sales orders so far..." -ForegroundColor Gray
    }

    Write-TestResult -TestName "Read Sales Orders" -Start $soStart -End (Get-Date) `
        -SuccessCount $soCount -ErrorCount 0 -TotalDocs $soCount -TotalLines 0

    # Read all Purchase Orders
    Write-Host "Reading Purchase Orders..." -ForegroundColor Yellow
    $poStart = Get-Date
    $poCount = 0
    $nextUrl = "$companyApi/purchaseOrders?`$top=100"

    while ($nextUrl) {
        $result = Invoke-BCApi -Method Get -Url $nextUrl
        if (-not $result.Success) {
            Write-Host "  Read failed at $poCount docs: $($result.Error)" -ForegroundColor Red
            break
        }
        $poCount += $result.Data.value.Count
        $nextUrl = $result.Data.'@odata.nextLink'
        Write-Host "  Read $poCount purchase orders so far..." -ForegroundColor Gray
    }

    Write-TestResult -TestName "Read Purchase Orders" -Start $poStart -End (Get-Date) `
        -SuccessCount $poCount -ErrorCount 0 -TotalDocs $poCount -TotalLines 0
}

function Start-ConcurrentTest {
    Write-Host "=== CONCURRENT LOAD TEST ===" -ForegroundColor Cyan
    Write-Host "Running $ConcurrentJobs parallel jobs, each creating documents." -ForegroundColor Gray
    Write-Host "NOTE: BC Cloud rate limits apply (~600 calls/5min per user)." -ForegroundColor DarkYellow
    Write-Host ""

    $custNo = Get-TestCustomer
    $vndNo = Get-TestVendor
    $itmNo = Get-TestItem

    $docsPerJob = [math]::Ceiling($SalesOrders / $ConcurrentJobs)
    Write-Host "Each job will create $docsPerJob sales orders." -ForegroundColor Gray
    Write-Host ""

    $overallStart = Get-Date
    $jobs = @()

    for ($j = 1; $j -le $ConcurrentJobs; $j++) {
        $jobs += Start-Job -ScriptBlock {
            param($ApiBase, $CompanyId, $CustNo, $ItmNo, $Lines, $DocsToCreate, $Token, $JobNum)

            $headers = @{
                "Authorization" = "Bearer $Token"
                "Content-Type"  = "application/json"
                "Accept"        = "application/json"
            }
            $companyApi = "$ApiBase/companies($CompanyId)"
            $success = 0; $errors = 0

            for ($i = 1; $i -le $DocsToCreate; $i++) {
                try {
                    $soBody = @{ customerNumber = $CustNo; orderDate = (Get-Date -Format "yyyy-MM-dd") } | ConvertTo-Json
                    $so = Invoke-RestMethod -Uri "$companyApi/salesOrders" -Method Post -Headers $headers -Body $soBody
                    $soId = $so.id

                    for ($l = 1; $l -le $Lines; $l++) {
                        $lineBody = @{ lineObjectNumber = $ItmNo; lineType = "Item"; quantity = 1 } | ConvertTo-Json
                        $null = Invoke-RestMethod -Uri "$companyApi/salesOrders($soId)/salesOrderLines" -Method Post -Headers $headers -Body $lineBody
                    }
                    $success++
                } catch {
                    $errors++
                    $statusCode = $_.Exception.Response.StatusCode.value__
                    if ($statusCode -eq 429) {
                        Start-Sleep -Seconds 10
                    }
                }
            }

            return @{ Job = $JobNum; Success = $success; Errors = $errors }
        } -ArgumentList $apiBase, $companyId, $custNo, $itmNo, $LinesPerDoc, $docsPerJob, $token, $j
    }

    Write-Host "Waiting for $($jobs.Count) jobs to complete..." -ForegroundColor Yellow
    $results = $jobs | Wait-Job | Receive-Job
    $jobs | Remove-Job

    $totalSuccess = ($results | Measure-Object -Property Success -Sum).Sum
    $totalErrors = ($results | Measure-Object -Property Errors -Sum).Sum

    Write-TestResult -TestName "Concurrent SO Creation ($ConcurrentJobs jobs)" `
        -Start $overallStart -End (Get-Date) `
        -SuccessCount $totalSuccess -ErrorCount $totalErrors `
        -TotalDocs $totalSuccess -TotalLines ($totalSuccess * $LinesPerDoc)

    Write-Host ""
    Write-Host "Per-job breakdown:" -ForegroundColor Gray
    foreach ($r in $results) {
        Write-Host "  Job $($r.Job): $($r.Success) success, $($r.Errors) errors"
    }
}

# ─────────────────────────── Race (Time-Based) Test ───────────────────────────

function Start-RaceTest {
    Write-Host "=== RACE TEST ($RaceMinutes min per doc type) ===" -ForegroundColor Cyan
    Write-Host "Creating as many documents as possible in $RaceMinutes minutes each." -ForegroundColor Gray
    Write-Host "Lines per doc: $LinesPerDoc" -ForegroundColor Gray
    Write-Host ""

    $custNo = Get-TestCustomer
    $vndNo = Get-TestVendor
    $itmNo = Get-TestItem
    Write-Host ""

    $timeLimit = [TimeSpan]::FromMinutes($RaceMinutes)

    # ── Sales Orders Race ──
    Write-Host "Racing: Sales Orders ($RaceMinutes min)..." -ForegroundColor Yellow
    $soStart = Get-Date
    $soDeadline = $soStart + $timeLimit
    $soSuccess = 0; $soErrors = 0; $soLineErrors = 0

    while ((Get-Date) -lt $soDeadline) {
        $result = New-TestSalesOrder -CustNo $custNo -ItmNo $itmNo -Lines $LinesPerDoc
        if ($result.Success) {
            $soSuccess++
            $soLineErrors += $result.LineErrors
        } else {
            $soErrors++
        }

        $elapsed = (Get-Date) - $soStart
        $remaining = $timeLimit - $elapsed
        $pct = [math]::Min(100, [math]::Round(($elapsed.TotalSeconds / $timeLimit.TotalSeconds) * 100))
        Write-Progress -Activity "SO Race" -Status "$soSuccess created, $soErrors failed | $([math]::Round($remaining.TotalSeconds))s left" -PercentComplete $pct
    }
    $soEnd = Get-Date
    Write-Progress -Activity "SO Race" -Completed

    Write-TestResult -TestName "Sales Order Race ($RaceMinutes min)" -Start $soStart -End $soEnd `
        -SuccessCount $soSuccess -ErrorCount $soErrors `
        -TotalDocs $soSuccess -TotalLines ($soSuccess * $LinesPerDoc)
    if ($soLineErrors -gt 0) {
        Write-Host "  Line errors:    $soLineErrors" -ForegroundColor Red
    }

    # ── Purchase Orders Race ──
    Write-Host ""
    Write-Host "Racing: Purchase Orders ($RaceMinutes min)..." -ForegroundColor Yellow
    $poStart = Get-Date
    $poDeadline = $poStart + $timeLimit
    $poSuccess = 0; $poErrors = 0; $poLineErrors = 0

    while ((Get-Date) -lt $poDeadline) {
        $result = New-TestPurchaseOrder -VndNo $vndNo -ItmNo $itmNo -Lines $LinesPerDoc
        if ($result.Success) {
            $poSuccess++
            $poLineErrors += $result.LineErrors
        } else {
            $poErrors++
        }

        $elapsed = (Get-Date) - $poStart
        $remaining = $timeLimit - $elapsed
        $pct = [math]::Min(100, [math]::Round(($elapsed.TotalSeconds / $timeLimit.TotalSeconds) * 100))
        Write-Progress -Activity "PO Race" -Status "$poSuccess created, $poErrors failed | $([math]::Round($remaining.TotalSeconds))s left" -PercentComplete $pct
    }
    $poEnd = Get-Date
    Write-Progress -Activity "PO Race" -Completed

    Write-TestResult -TestName "Purchase Order Race ($RaceMinutes min)" -Start $poStart -End $poEnd `
        -SuccessCount $poSuccess -ErrorCount $poErrors `
        -TotalDocs $poSuccess -TotalLines ($poSuccess * $LinesPerDoc)
    if ($poLineErrors -gt 0) {
        Write-Host "  Line errors:    $poLineErrors" -ForegroundColor Red
    }

    # ── Summary ──
    $totalDocs = $soSuccess + $poSuccess
    $totalTime = ($soEnd - $soStart) + ($poEnd - $poStart)
    Write-Host ""
    Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  RACE SUMMARY" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  Total time:     $($RaceMinutes * 2) min ($RaceMinutes per type)"
    Write-Host "  Sales Orders:   $soSuccess (+ $soErrors errors)"
    Write-Host "  Purchase Orders: $poSuccess (+ $poErrors errors)"
    Write-Host "  Total docs:     $totalDocs"
    Write-Host "  Total lines:    $($totalDocs * $LinesPerDoc)"
    Write-Host "  Batch ID:       $BatchId"
    Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
}

# ─────────────────────────── Endurance ───────────────────────────

function Refresh-Token {
    Write-Host "Refreshing OAuth2 token..." -ForegroundColor Yellow
    $newToken = & "$PSScriptRoot\get-bc-token.ps1" -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret
    if (-not $newToken) {
        Write-Host "Token refresh failed!" -ForegroundColor Red
        return $false
    }
    $script:headers = @{
        "Authorization" = "Bearer $newToken"
        "Content-Type"  = "application/json"
        "Accept"        = "application/json"
    }
    $script:tokenAcquired = Get-Date
    Write-Debug-Log "Token refreshed at $($script:tokenAcquired.ToString('HH:mm:ss'))"
    return $true
}

function Start-EnduranceTest {
    $insertMethod = if ($UseDeepInsert) { "DEEP INSERT (header + lines in 1 call)" } else { "TRADITIONAL (separate header + line calls)" }
    Write-Host "" 
    Write-Host "═══════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host "  ENDURANCE TEST" -ForegroundColor Magenta
    Write-Host "  Insert Method: $insertMethod" -ForegroundColor $(if ($UseDeepInsert) { 'Green' } else { 'Cyan' })
    Write-Host "  Cycle: ${CycleMinutes}min SO + ${CycleMinutes}min PO" -ForegroundColor Magenta
    Write-Host "  Max duration: ${EnduranceMaxMinutes}min" -ForegroundColor Magenta
    Write-Host "  Lines/doc: $LinesPerDoc | Batch: $BatchId" -ForegroundColor Magenta
    Write-Host "═══════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host ""

    # ── CSV log setup ──
    $resultsDir = Join-Path $PSScriptRoot "..\results"
    if (-not (Test-Path $resultsDir)) { New-Item -ItemType Directory -Path $resultsDir -Force | Out-Null }
    $runStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $csvPath = Join-Path $resultsDir "endurance-$runStamp.csv"
    $detailCsvPath = Join-Path $resultsDir "endurance-detail-$runStamp.csv"
    "Timestamp,Cycle,Phase,Docs,Errors,Rate_Per_Sec,Phase_Secs,Cumulative_SO,Cumulative_PO,Cumulative_SO_Errors,Cumulative_PO_Errors,Cumulative_Total_Docs,Cumulative_Total_Lines,Elapsed_Min,BatchId" | Out-File $csvPath -Encoding utf8
    "Timestamp,Cycle,Phase,DocNo,Success,LineErrors,Duration_Ms,Elapsed_Sec,BatchId" | Out-File $detailCsvPath -Encoding utf8
    Write-Host "  Summary CSV: $csvPath" -ForegroundColor Gray
    Write-Host "  Detail CSV:  $detailCsvPath" -ForegroundColor Gray
    Write-Host ""

    $custNo = Get-TestCustomer
    $vndNo  = Get-TestVendor
    $itmNo  = Get-TestItem
    Write-Host ""

    $enduranceStart = Get-Date
    $enduranceDeadline = $enduranceStart.AddMinutes($EnduranceMaxMinutes)
    $script:tokenAcquired = $enduranceStart
    $cycleNum = 0
    $timeLimit = [TimeSpan]::FromMinutes($CycleMinutes)

    $cycleResults = @()
    $cumSO = 0; $cumPO = 0; $cumSOErr = 0; $cumPOErr = 0

    while ((Get-Date) -lt $enduranceDeadline) {
        $cycleNum++
        $cycleStart = Get-Date
        $remainingTotal = $enduranceDeadline - $cycleStart
        Write-Host ""
        Write-Host "───── Cycle $cycleNum ─────  ($([math]::Round($remainingTotal.TotalMinutes))min remaining)" -ForegroundColor Cyan

        # Refresh token if older than 45 minutes
        $tokenAge = (Get-Date) - $script:tokenAcquired
        if ($tokenAge.TotalMinutes -gt 45) {
            if (-not (Refresh-Token)) { break }
        }

        # ── SO phase ──
        $phaseEnd = (Get-Date) + $timeLimit
        $phaseDeadline = if ($phaseEnd -lt $enduranceDeadline) { $phaseEnd } else { $enduranceDeadline }
        Write-Host "  SO phase ($CycleMinutes min)..." -ForegroundColor Yellow
        $soStart = Get-Date
        $soOK = 0; $soFail = 0

        while ((Get-Date) -lt $phaseDeadline) {
            $docStart = Get-Date
            if ($UseDeepInsert) {
                $r = New-TestSalesOrderDeepInsert -CustNo $custNo -ItmNo $itmNo -Lines $LinesPerDoc
            } else {
                $r = New-TestSalesOrder -CustNo $custNo -ItmNo $itmNo -Lines $LinesPerDoc
            }
            $docMs = [math]::Round(((Get-Date) - $docStart).TotalMilliseconds)
            $docElapsed = [math]::Round(((Get-Date) - $enduranceStart).TotalSeconds, 1)
            if ($r.Success) {
                $soOK++
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'),$cycleNum,SO,$($r.OrderNo),1,$($r.LineErrors),$docMs,$docElapsed,$BatchId" | Out-File $detailCsvPath -Append -Encoding utf8
            } else {
                $soFail++
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'),$cycleNum,SO,,0,0,$docMs,$docElapsed,$BatchId" | Out-File $detailCsvPath -Append -Encoding utf8
            }

            $elapsed = (Get-Date) - $soStart
            $pct = [math]::Min(100, [math]::Round(($elapsed.TotalSeconds / $timeLimit.TotalSeconds) * 100))
            Write-Progress -Activity "Endurance C$cycleNum - SO" -Status "$soOK ok, $soFail err" -PercentComplete $pct
        }
        $soEnd = Get-Date
        Write-Progress -Activity "Endurance C$cycleNum - SO" -Completed
        $soSecs = [math]::Round(($soEnd - $soStart).TotalSeconds)
        $soRate = if ($soSecs -gt 0) { [math]::Round($soOK / $soSecs, 2) } else { 0 }
        $cumSO += $soOK; $cumSOErr += $soFail
        $elapsedMin = [math]::Round(($soEnd - $enduranceStart).TotalMinutes, 1)

        Write-Host "  SO phase: $soOK docs, $soFail errors, $soRate/s" -ForegroundColor $(if ($soFail -eq 0) { 'Green' } else { 'Yellow' })

        $soRow = [PSCustomObject]@{ Cycle=$cycleNum; Phase='SO'; Docs=$soOK; Errors=$soFail; Rate=$soRate; Elapsed=$soSecs }
        $cycleResults += $soRow
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$cycleNum,SO,$soOK,$soFail,$soRate,$soSecs,$cumSO,$cumPO,$cumSOErr,$cumPOErr,$($cumSO+$cumPO),$(($cumSO+$cumPO)*$LinesPerDoc),$elapsedMin,$BatchId" | Out-File $csvPath -Append -Encoding utf8

        # Check if time is up before PO phase
        if ((Get-Date) -ge $enduranceDeadline) { break }

        # Refresh token between phases if needed
        $tokenAge = (Get-Date) - $script:tokenAcquired
        if ($tokenAge.TotalMinutes -gt 45) {
            if (-not (Refresh-Token)) { break }
        }

        # ── PO phase ──
        $phaseEnd = (Get-Date) + $timeLimit
        $phaseDeadline = if ($phaseEnd -lt $enduranceDeadline) { $phaseEnd } else { $enduranceDeadline }
        Write-Host "  PO phase ($CycleMinutes min)..." -ForegroundColor Yellow
        $poStart = Get-Date
        $poOK = 0; $poFail = 0

        while ((Get-Date) -lt $phaseDeadline) {
            $docStart = Get-Date
            if ($UseDeepInsert) {
                $r = New-TestPurchaseOrderDeepInsert -VndNo $vndNo -ItmNo $itmNo -Lines $LinesPerDoc
            } else {
                $r = New-TestPurchaseOrder -VndNo $vndNo -ItmNo $itmNo -Lines $LinesPerDoc
            }
            $docMs = [math]::Round(((Get-Date) - $docStart).TotalMilliseconds)
            $docElapsed = [math]::Round(((Get-Date) - $enduranceStart).TotalSeconds, 1)
            if ($r.Success) {
                $poOK++
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'),$cycleNum,PO,$($r.OrderNo),1,$($r.LineErrors),$docMs,$docElapsed,$BatchId" | Out-File $detailCsvPath -Append -Encoding utf8
            } else {
                $poFail++
                "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'),$cycleNum,PO,,0,0,$docMs,$docElapsed,$BatchId" | Out-File $detailCsvPath -Append -Encoding utf8
            }

            $elapsed = (Get-Date) - $poStart
            $pct = [math]::Min(100, [math]::Round(($elapsed.TotalSeconds / $timeLimit.TotalSeconds) * 100))
            Write-Progress -Activity "Endurance C$cycleNum - PO" -Status "$poOK ok, $poFail err" -PercentComplete $pct
        }
        $poEnd = Get-Date
        Write-Progress -Activity "Endurance C$cycleNum - PO" -Completed
        $poSecs = [math]::Round(($poEnd - $poStart).TotalSeconds)
        $poRate = if ($poSecs -gt 0) { [math]::Round($poOK / $poSecs, 2) } else { 0 }
        $cumPO += $poOK; $cumPOErr += $poFail
        $elapsedMin = [math]::Round(($poEnd - $enduranceStart).TotalMinutes, 1)

        Write-Host "  PO phase: $poOK docs, $poFail errors, $poRate/s" -ForegroundColor $(if ($poFail -eq 0) { 'Green' } else { 'Yellow' })

        $poRow = [PSCustomObject]@{ Cycle=$cycleNum; Phase='PO'; Docs=$poOK; Errors=$poFail; Rate=$poRate; Elapsed=$poSecs }
        $cycleResults += $poRow
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),$cycleNum,PO,$poOK,$poFail,$poRate,$poSecs,$cumSO,$cumPO,$cumSOErr,$cumPOErr,$($cumSO+$cumPO),$(($cumSO+$cumPO)*$LinesPerDoc),$elapsedMin,$BatchId" | Out-File $csvPath -Append -Encoding utf8

        # ── Cycle summary line ──
        $cycleTotal = $soOK + $poOK
        Write-Host "  Cycle $cycleNum total: $cycleTotal docs | Cumulative: $($cumSO+$cumPO)" -ForegroundColor Green
    }

    # ── Final summary ──
    $enduranceEnd = Get-Date
    $totalElapsed = $enduranceEnd - $enduranceStart
    Write-Host ""
    Write-Host "═══════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host "  ENDURANCE SUMMARY" -ForegroundColor Magenta
    Write-Host "═══════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host "  Total time:       $([math]::Round($totalElapsed.TotalMinutes, 1)) min"
    Write-Host "  Cycles completed: $cycleNum"
    Write-Host "  Sales Orders:     $cumSO (+ $cumSOErr errors)"
    Write-Host "  Purchase Orders:  $cumPO (+ $cumPOErr errors)"
    Write-Host "  Total docs:       $($cumSO + $cumPO)"
    Write-Host "  Total lines:      $(($cumSO + $cumPO) * $LinesPerDoc)"
    Write-Host "  Batch ID:         $BatchId"
    Write-Host "  Summary CSV:      $csvPath"
    Write-Host "  Detail CSV:       $detailCsvPath"
    Write-Host "═══════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host ""

    # ── Trend table ──
    Write-Host "  Cycle Trend:" -ForegroundColor Cyan
    Write-Host ("  {0,-6} {1,-6} {2,-8} {3,-8} {4,-10} {5,-8}" -f 'Cycle','Phase','Docs','Errors','Rate(/s)','Secs')
    Write-Host ("  {0,-6} {1,-6} {2,-8} {3,-8} {4,-10} {5,-8}" -f '-----','-----','-------','-------','---------','-------')
    foreach ($row in $cycleResults) {
        $color = if ($row.Errors -gt 0) { 'Yellow' } else { 'White' }
        Write-Host ("  {0,-6} {1,-6} {2,-8} {3,-8} {4,-10} {5,-8}" -f $row.Cycle, $row.Phase, $row.Docs, $row.Errors, $row.Rate, $row.Elapsed) -ForegroundColor $color
    }

    Write-Host ""
    Write-Host "  CSVs saved:" -ForegroundColor Green
    Write-Host "    Summary: $csvPath" -ForegroundColor Green
    Write-Host "    Detail:  $detailCsvPath" -ForegroundColor Green
}

# ─────────────────────────── Deep Insert Race ───────────────────────────

function Start-DeepInsertTest {
    Write-Host ""
    Write-Host "═══════════════════════════════════════════" -ForegroundColor Yellow
    Write-Host "  DEEP INSERT TEST" -ForegroundColor Yellow
    Write-Host "  1 API call = header + $LinesPerDoc lines" -ForegroundColor Yellow
    Write-Host "  Duration: $RaceMinutes min per type" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════" -ForegroundColor Yellow
    Write-Host ""

    # ── CSV log setup ──
    $resultsDir = Join-Path $PSScriptRoot "..\results"
    if (-not (Test-Path $resultsDir)) { New-Item -ItemType Directory -Path $resultsDir -Force | Out-Null }
    $runStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $detailCsvPath = Join-Path $resultsDir "deepinsert-detail-$runStamp.csv"
    "Timestamp,Phase,DocNo,Success,Duration_Ms,Elapsed_Sec,BatchId" | Out-File $detailCsvPath -Encoding utf8
    Write-Host "  Detail CSV: $detailCsvPath" -ForegroundColor Gray
    Write-Host ""

    $custNo = Get-TestCustomer
    $vndNo  = Get-TestVendor
    $itmNo  = Get-TestItem
    Write-Host ""

    $testStart = Get-Date
    $timeLimit = [TimeSpan]::FromMinutes($RaceMinutes)

    # ── SO Deep Insert Race ──
    Write-Host "Deep Insert: Sales Orders ($RaceMinutes min)..." -ForegroundColor Yellow
    $soStart = Get-Date
    $soDeadline = $soStart + $timeLimit
    $soSuccess = 0; $soErrors = 0

    while ((Get-Date) -lt $soDeadline) {
        $docStart = Get-Date
        $r = New-TestSalesOrderDeepInsert -CustNo $custNo -ItmNo $itmNo -Lines $LinesPerDoc
        $docMs = [math]::Round(((Get-Date) - $docStart).TotalMilliseconds)
        $docElapsed = [math]::Round(((Get-Date) - $testStart).TotalSeconds, 1)
        if ($r.Success) {
            $soSuccess++
            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'),SO,$($r.OrderNo),1,$docMs,$docElapsed,$BatchId" | Out-File $detailCsvPath -Append -Encoding utf8
        } else {
            $soErrors++
            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'),SO,,0,$docMs,$docElapsed,$BatchId" | Out-File $detailCsvPath -Append -Encoding utf8
        }

        $elapsed = (Get-Date) - $soStart
        $pct = [math]::Min(100, [math]::Round(($elapsed.TotalSeconds / $timeLimit.TotalSeconds) * 100))
        Write-Progress -Activity "Deep Insert SO" -Status "$soSuccess ok, $soErrors err" -PercentComplete $pct
    }
    $soEnd = Get-Date
    Write-Progress -Activity "Deep Insert SO" -Completed
    $soRate = if (($soEnd - $soStart).TotalSeconds -gt 0) { [math]::Round($soSuccess / ($soEnd - $soStart).TotalSeconds, 2) } else { 0 }

    Write-TestResult -TestName "Deep Insert SO ($RaceMinutes min)" -Start $soStart -End $soEnd `
        -SuccessCount $soSuccess -ErrorCount $soErrors `
        -TotalDocs $soSuccess -TotalLines ($soSuccess * $LinesPerDoc)

    # ── PO Deep Insert Race ──
    Write-Host ""
    Write-Host "Deep Insert: Purchase Orders ($RaceMinutes min)..." -ForegroundColor Yellow
    $poStart = Get-Date
    $poDeadline = $poStart + $timeLimit
    $poSuccess = 0; $poErrors = 0

    while ((Get-Date) -lt $poDeadline) {
        $docStart = Get-Date
        $r = New-TestPurchaseOrderDeepInsert -VndNo $vndNo -ItmNo $itmNo -Lines $LinesPerDoc
        $docMs = [math]::Round(((Get-Date) - $docStart).TotalMilliseconds)
        $docElapsed = [math]::Round(((Get-Date) - $testStart).TotalSeconds, 1)
        if ($r.Success) {
            $poSuccess++
            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'),PO,$($r.OrderNo),1,$docMs,$docElapsed,$BatchId" | Out-File $detailCsvPath -Append -Encoding utf8
        } else {
            $poErrors++
            "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'),PO,,0,$docMs,$docElapsed,$BatchId" | Out-File $detailCsvPath -Append -Encoding utf8
        }

        $elapsed = (Get-Date) - $poStart
        $pct = [math]::Min(100, [math]::Round(($elapsed.TotalSeconds / $timeLimit.TotalSeconds) * 100))
        Write-Progress -Activity "Deep Insert PO" -Status "$poSuccess ok, $poErrors err" -PercentComplete $pct
    }
    $poEnd = Get-Date
    Write-Progress -Activity "Deep Insert PO" -Completed
    $poRate = if (($poEnd - $poStart).TotalSeconds -gt 0) { [math]::Round($poSuccess / ($poEnd - $poStart).TotalSeconds, 2) } else { 0 }

    Write-TestResult -TestName "Deep Insert PO ($RaceMinutes min)" -Start $poStart -End $poEnd `
        -SuccessCount $poSuccess -ErrorCount $poErrors `
        -TotalDocs $poSuccess -TotalLines ($poSuccess * $LinesPerDoc)

    # ── Summary ──
    $totalDocs = $soSuccess + $poSuccess
    Write-Host ""
    Write-Host "═══════════════════════════════════════════" -ForegroundColor Yellow
    Write-Host "  DEEP INSERT SUMMARY" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════" -ForegroundColor Yellow
    Write-Host "  Total time:      $($RaceMinutes * 2) min ($RaceMinutes per type)"
    Write-Host "  Sales Orders:    $soSuccess ($soRate/s) + $soErrors errors"
    Write-Host "  Purchase Orders: $poSuccess ($poRate/s) + $poErrors errors"
    Write-Host "  Total docs:      $totalDocs"
    Write-Host "  Total lines:     $($totalDocs * $LinesPerDoc)"
    Write-Host "  API calls:       $totalDocs (vs $($totalDocs * (1 + $LinesPerDoc)) with separate calls)"
    Write-Host "  Batch ID:        $BatchId"
    Write-Host "  Detail CSV:      $detailCsvPath"
    Write-Host "═══════════════════════════════════════════" -ForegroundColor Yellow
}

# ─────────────────────────── Main ───────────────────────────

switch ($Mode) {
    "Validate"   { Start-ValidateTest }
    "Full"       { Start-FullTest }
    "Read"       { Start-ReadTest }
    "Concurrent" { Start-ConcurrentTest }
    "Race"       { Start-RaceTest }
    "Endurance"  { Start-EnduranceTest }
    "DeepInsert"  { Start-DeepInsertTest }
}

Write-Host ""
Write-Host "Done." -ForegroundColor Cyan
