# bc-staging-load.ps1
# Loads document staging rows into the BC staging table via the flat API.
# Supports both Sales Orders and Purchase Orders.
# No deep insert — just simple flat POSTs, one per line.
#
# Usage:
#   # Quick validation (1 SO with 3 lines):
#   .\scripts\bc-staging-load.ps1 -Mode Validate
#
#   # Load 100 SOs with 3 lines each:
#   .\scripts\bc-staging-load.ps1 -Mode Load -SalesOrders 100 -LinesPerDoc 3
#
#   # Load 50 POs with 5 lines each:
#   .\scripts\bc-staging-load.ps1 -Mode Load -PurchaseOrders 50 -LinesPerDoc 5
#
#   # Load mix of SOs and POs with multi-threading:
#   .\scripts\bc-staging-load.ps1 -Mode Load -SalesOrders 200 -PurchaseOrders 100 -LinesPerDoc 3 -Threads 5
#
#   # Check batch status:
#   .\scripts\bc-staging-load.ps1 -Mode Status -BatchId "LT-20260329-120000"

param(
    [ValidateSet("Validate", "Load", "Status")]
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
    [int]$PurchaseOrders = 0,
    [int]$LinesPerDoc = 3,
    [int]$Threads = 1,
    [int]$RetryCount = 3,
    [int]$RetryDelaySeconds = 10,
    [string]$BatchId = "",
    [switch]$DebugLog
)

$ErrorActionPreference = "Stop"

function Write-Debug-Log {
    param([string]$Message)
    if ($DebugLog) {
        Write-Host "  [DBG $(Get-Date -Format 'HH:mm:ss.fff')] $Message" -ForegroundColor DarkGray
    }
}

# ─────────────────────────── Auth ───────────────────────────

Write-Host "=== BC Staging Load ===" -ForegroundColor Cyan
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

$bcRoot    = "https://api.businesscentral.dynamics.com/v2.0/$TenantId/$Environment"
$apiBase   = "$bcRoot/api/v2.0"

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

$customApi   = "$bcRoot/api/defaultpublisher/docloadtest/v1.0/companies($companyId)"
$stagingUrl  = "$customApi/docStagingLinesLT"

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
                Uri        = $Url
                Method     = $Method
                Headers    = $headers
                TimeoutSec = 30
            }
            if ($jsonBody) {
                $params.Body = $jsonBody
            }

            $response = Invoke-RestMethod @params
            $sw.Stop()
            Write-Debug-Log "  -> 200 OK ($($sw.ElapsedMilliseconds)ms)"
            return @{ Success = $true; Data = $response; StatusCode = 200; Retries = $attempt; ElapsedMs = $sw.ElapsedMilliseconds }
        }
        catch {
            $sw.Stop()
            $statusCode = 0
            try { $statusCode = [int]$_.Exception.Response.StatusCode.value__ } catch { }
            $errorBody = ""
            try { $errorBody = $_.ErrorDetails.Message } catch { $errorBody = $_.Exception.Message }

            Write-Debug-Log "  -> $statusCode FAILED ($($sw.ElapsedMilliseconds)ms): $errorBody"

            if ($statusCode -eq 429) {
                $retryAfter = $RetryDelaySeconds
                try { $retryAfter = [int]$_.Exception.Response.Headers["Retry-After"] } catch { }
                Write-Host "  Rate limited (429). Waiting ${retryAfter}s... (attempt $($attempt+1)/$MaxRetries)" -ForegroundColor DarkYellow
                Start-Sleep -Seconds $retryAfter
                continue
            }

            if ($statusCode -eq 400) {
                Write-Host "  Bad Request (400): $errorBody" -ForegroundColor Red
                return @{ Success = $false; StatusCode = $statusCode; Error = $errorBody; Retries = $attempt; ElapsedMs = $sw.ElapsedMilliseconds }
            }

            if ($attempt -eq $MaxRetries) {
                return @{ Success = $false; StatusCode = $statusCode; Error = $errorBody; Retries = $attempt; ElapsedMs = $sw.ElapsedMilliseconds }
            }

            Write-Host "  Request failed ($statusCode). Retrying in 2s... (attempt $($attempt+1)/$MaxRetries)" -ForegroundColor DarkYellow
            Start-Sleep -Seconds 2
        }
    }
}

function Get-TestCustomer {
    if ($CustomerNo) { return $CustomerNo }
    Write-Host "Looking up first customer..." -ForegroundColor Yellow
    $resp = Invoke-BCApi -Method GET -Url "$apiBase/companies($companyId)/customers?`$top=1&`$select=number"
    if ($resp.Success -and $resp.Data.value.Count -gt 0) {
        $no = $resp.Data.value[0].number
        Write-Host "  Using customer: $no" -ForegroundColor Green
        return $no
    }
    Write-Host "ERROR: No customers found." -ForegroundColor Red
    exit 1
}

function Get-TestVendor {
    if ($VendorNo) { return $VendorNo }
    Write-Host "Looking up first vendor..." -ForegroundColor Yellow
    $resp = Invoke-BCApi -Method GET -Url "$apiBase/companies($companyId)/vendors?`$top=1&`$select=number"
    if ($resp.Success -and $resp.Data.value.Count -gt 0) {
        $no = $resp.Data.value[0].number
        Write-Host "  Using vendor: $no" -ForegroundColor Green
        return $no
    }
    Write-Host "ERROR: No vendors found." -ForegroundColor Red
    exit 1
}

function Get-TestItem {
    if ($ItemNo) { return $ItemNo }
    Write-Host "Looking up first item..." -ForegroundColor Yellow
    $resp = Invoke-BCApi -Method GET -Url "$apiBase/companies($companyId)/items?`$top=1&`$select=number"
    if ($resp.Success -and $resp.Data.value.Count -gt 0) {
        $no = $resp.Data.value[0].number
        Write-Host "  Using item: $no" -ForegroundColor Green
        return $no
    }
    Write-Host "ERROR: No items found." -ForegroundColor Red
    exit 1
}

# ─────────────────────────── Validate Mode ───────────────────────────

function Start-Validate {
    Write-Host "=== VALIDATE MODE ===" -ForegroundColor Cyan
    Write-Host "Inserting 1 SO with $LinesPerDoc lines into staging table..." -ForegroundColor Gray
    Write-Host ""

    $custNo = Get-TestCustomer
    $itmNo  = Get-TestItem
    $testBatchId = "LT-" + (Get-Date -Format "yyyyMMdd-HHmmss")
    $docGroupId  = "$testBatchId-SO-0001"
    $orderDate   = Get-Date -Format "yyyy-MM-dd"
    $successCount = 0
    $errorCount   = 0

    Write-Host ""
    Write-Host "Batch ID: $testBatchId" -ForegroundColor Cyan
    Write-Host "Document Group: $docGroupId" -ForegroundColor Gray
    Write-Host ""

    for ($line = 1; $line -le $LinesPerDoc; $line++) {
        $body = @{
            batchId                = $testBatchId
            documentGroupId        = $docGroupId
            documentType           = "Sales Order"
            customerNumber         = $custNo
            orderDate              = $orderDate
            externalDocumentNumber = $testBatchId
            lineType               = "Item"
            itemNumber             = $itmNo
            quantity               = 1
            unitPrice              = 100
        }

        $result = Invoke-BCApi -Method POST -Url $stagingUrl -Body $body
        if ($result.Success) {
            $successCount++
            Write-Host ('  Line ' + $line + ': OK (' + $result.ElapsedMs + 'ms) - Entry ' + $result.Data.entryNo) -ForegroundColor Green
        } else {
            $errorCount++
            Write-Host ('  Line ' + $line + ': FAILED (' + $result.StatusCode + ') ' + $result.Error) -ForegroundColor Red
        }
    }

    Write-Host ""
    Write-Host "Staging insert complete: $successCount/$LinesPerDoc lines loaded." -ForegroundColor $(if ($errorCount -eq 0) { 'Green' } else { 'Yellow' })
    Write-Host "Batch ID: $testBatchId" -ForegroundColor Cyan
    Write-Host ""

    # Verify by reading back
    Write-Host "Verifying staged data..." -ForegroundColor Yellow
    $verifyUrl = "$stagingUrl?`$filter=batchId eq '$testBatchId'"
    $verifyResp = Invoke-BCApi -Method GET -Url $verifyUrl
    if ($verifyResp.Success) {
        $rows = $verifyResp.Data.value
        Write-Host "  Found $($rows.Count) rows in staging table." -ForegroundColor Green
        foreach ($r in $rows) {
            Write-Host "    Entry $($r.entryNo): $($r.itemNumber) x$($r.quantity) @ $($r.unitPrice) — Status: $($r.status)" -ForegroundColor Gray
        }
    } else {
        Write-Host "  Verification failed: $($verifyResp.Error)" -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "Next step: Run the Doc Staging Processor in BC to create documents from these staged lines." -ForegroundColor Yellow
}

# ─────────────────────────── Load Mode ───────────────────────────

function Start-Load {
    $totalDocs = $SalesOrders + $PurchaseOrders
    if ($totalDocs -eq 0) {
        Write-Host "ERROR: Specify -SalesOrders and/or -PurchaseOrders (both are 0)." -ForegroundColor Red
        exit 1
    }
    $totalRows = $totalDocs * $LinesPerDoc
    $docParts = @()
    if ($SalesOrders -gt 0) { $docParts += "$SalesOrders SOs" }
    if ($PurchaseOrders -gt 0) { $docParts += "$PurchaseOrders POs" }
    $docLabel = $docParts -join " + "
    Write-Host "=== LOAD MODE ($docLabel x $LinesPerDoc lines = $totalRows rows, $Threads thread(s)) ===" -ForegroundColor Cyan
    Write-Host ""

    $itmNo = Get-TestItem
    $custNo = $null
    $vendNo = $null
    if ($SalesOrders -gt 0) { $custNo = Get-TestCustomer }
    if ($PurchaseOrders -gt 0) { $vendNo = Get-TestVendor }
    $loadBatchId = if ($BatchId) { $BatchId } else { "LT-" + (Get-Date -Format "yyyyMMdd-HHmmss") }
    $orderDate = Get-Date -Format "yyyy-MM-dd"

    Write-Host ""
    Write-Host "Batch ID: $loadBatchId" -ForegroundColor Cyan
    Write-Host ""

    # Generate all row payloads
    Write-Host "Generating $totalRows staging row payloads..." -ForegroundColor Yellow
    $allRows = [System.Collections.Generic.List[string]]::new()

    for ($so = 1; $so -le $SalesOrders; $so++) {
        $docGroupId = "$loadBatchId-SO-$($so.ToString().PadLeft(5, '0'))"
        for ($line = 1; $line -le $LinesPerDoc; $line++) {
            $row = @{
                batchId                = $loadBatchId
                documentGroupId        = $docGroupId
                documentType           = "Sales Order"
                customerNumber         = $custNo
                orderDate              = $orderDate
                externalDocumentNumber = $loadBatchId
                lineType               = "Item"
                itemNumber             = $itmNo
                quantity               = 1
                unitPrice              = 100
            }
            $allRows.Add(($row | ConvertTo-Json -Depth 5 -Compress))
        }
    }

    for ($po = 1; $po -le $PurchaseOrders; $po++) {
        $docGroupId = "$loadBatchId-PO-$($po.ToString().PadLeft(5, '0'))"
        for ($line = 1; $line -le $LinesPerDoc; $line++) {
            $row = @{
                batchId                = $loadBatchId
                documentGroupId        = $docGroupId
                documentType           = "Purchase Order"
                vendorNumber           = $vendNo
                orderDate              = $orderDate
                externalDocumentNumber = $loadBatchId
                lineType               = "Item"
                itemNumber             = $itmNo
                quantity               = 1
                directUnitCost         = 75
            }
            $allRows.Add(($row | ConvertTo-Json -Depth 5 -Compress))
        }
    }

    Write-Host "  Generated $($allRows.Count) rows." -ForegroundColor Green
    Write-Host ""

    $overallStart = Get-Date

    if ($Threads -le 1) {
        # Single-threaded — simple sequential POSTs
        $successCount = 0
        $errorCount = 0
        $rateLimits = 0
        $totalMs = 0

        for ($i = 0; $i -lt $allRows.Count; $i++) {
            $result = Invoke-BCApi -Method POST -Url $stagingUrl -Body ($allRows[$i] | ConvertFrom-Json)
            if ($result.Success) {
                $successCount++
                $totalMs += $result.ElapsedMs
            } elseif ($result.StatusCode -eq 429) {
                $rateLimits++
                $i-- # retry same row
            } else {
                $errorCount++
            }

            if (($i + 1) % 50 -eq 0) {
                $pct = [math]::Round(100 * ($i + 1) / $allRows.Count)
                $elapsed = ((Get-Date) - $overallStart).TotalSeconds
                $rate = [math]::Round($successCount / [math]::Max($elapsed, 0.1), 1)
                Write-Host "  Progress: $($i + 1)/$($allRows.Count) ($pct%) — $successCount OK, $errorCount errors — ${rate} rows/s" -ForegroundColor Gray
            }
        }
    } else {
        # Multi-threaded
        $resultsDir = Join-Path $PSScriptRoot ".." "results"
        if (-not (Test-Path $resultsDir)) { New-Item -ItemType Directory -Path $resultsDir | Out-Null }

        $chunkSize = [math]::Ceiling($allRows.Count / $Threads)
        $jobs = @()

        for ($t = 1; $t -le $Threads; $t++) {
            $sliceStart = ($t - 1) * $chunkSize
            $sliceEnd   = [math]::Min($t * $chunkSize - 1, $allRows.Count - 1)
            if ($sliceStart -gt $sliceEnd) { continue }

            $threadRows = $allRows[$sliceStart..$sliceEnd]
            Write-Host ('  Thread ' + $t + ': ' + $threadRows.Count + ' rows') -ForegroundColor Gray

            # Serialize rows as newline-joined string to avoid array unrolling in Start-Job
            $rowsJoined = $threadRows -join "`n"

            $jobs += Start-Job -ScriptBlock {
                param($rowsString, $url, $authToken, $maxRetries, $retryDelay)
                $ErrorActionPreference = "Stop"
                $rows = $rowsString -split "`n"
                $hdrs = @{
                    "Authorization" = "Bearer $authToken"
                    "Content-Type"  = "application/json"
                    "Accept"        = "application/json"
                }
                $success = 0; $errors = 0; $rateLimits = 0; $totalMs = 0

                foreach ($jsonRow in $rows) {
                    for ($attempt = 0; $attempt -le $maxRetries; $attempt++) {
                        try {
                            $sw = [System.Diagnostics.Stopwatch]::StartNew()
                            Invoke-RestMethod -Uri $url -Method POST -Headers $hdrs -Body $jsonRow -ContentType "application/json" -TimeoutSec 30 | Out-Null
                            $sw.Stop()
                            $success++
                            $totalMs += $sw.ElapsedMilliseconds
                            break
                        } catch {
                            $sw.Stop()
                            $sc = 0
                            try { $sc = [int]$_.Exception.Response.StatusCode.value__ } catch { }
                            if ($sc -eq 429) {
                                $rateLimits++
                                $wait = $retryDelay
                                try { $wait = [int]$_.Exception.Response.Headers["Retry-After"] } catch { }
                                Start-Sleep -Seconds $wait
                                continue
                            }
                            if ($sc -eq 400 -or $attempt -eq $maxRetries) {
                                $errors++
                                break
                            }
                            Start-Sleep -Seconds 2
                        }
                    }
                }

                [PSCustomObject]@{
                    Success    = $success
                    Errors     = $errors
                    RateLimits = $rateLimits
                    AvgMs      = if ($success -gt 0) { [math]::Round($totalMs / $success) } else { 0 }
                }
            } -ArgumentList $rowsJoined, $stagingUrl, $token, $RetryCount, $RetryDelaySeconds
        }

        Write-Host ""
        Write-Host "Waiting for $($jobs.Count) threads..." -ForegroundColor Yellow

        # Progress polling — detect Failed/Stopped jobs to avoid infinite wait
        while ($jobs | Where-Object { $_.State -notin 'Completed', 'Failed', 'Stopped' }) {
            Start-Sleep -Milliseconds 1000
            $elapsed = [math]::Round(((Get-Date) - $overallStart).TotalSeconds, 1)
            $doneCount = ($jobs | Where-Object { $_.State -eq 'Completed' } | Measure-Object).Count
            $failCount = ($jobs | Where-Object { $_.State -eq 'Failed' } | Measure-Object).Count
            $status = "$doneCount/$($jobs.Count) threads done"
            if ($failCount -gt 0) { $status += ", $failCount failed" }
            Write-Host "  ${elapsed}s elapsed — $status" -ForegroundColor Gray
        }

        # Report any failed jobs
        $failedJobs = @($jobs | Where-Object { $_.State -eq 'Failed' })
        foreach ($fj in $failedJobs) {
            Write-Host "  Thread FAILED: $($fj.ChildJobs[0].JobStateInfo.Reason.Message)" -ForegroundColor Red
        }

        $completedJobs = @($jobs | Where-Object { $_.State -eq 'Completed' })
        $threadResults = $completedJobs | Receive-Job
        $jobs | Remove-Job -Force

        $successCount = ($threadResults | Measure-Object -Property Success -Sum).Sum
        $errorCount   = ($threadResults | Measure-Object -Property Errors -Sum).Sum
        $rateLimits   = ($threadResults | Measure-Object -Property RateLimits -Sum).Sum
        # Count failed jobs as errors
        $errorCount += $failedJobs.Count
    }

    $overallEnd = Get-Date
    $duration   = ($overallEnd - $overallStart).TotalSeconds
    $throughput = [math]::Round($successCount / [math]::Max($duration, 0.1), 2)

    Write-Host ""
    Write-Host "=== STAGING LOAD RESULTS ===" -ForegroundColor Cyan
    Write-Host "Batch ID:    $loadBatchId" -ForegroundColor White
    Write-Host "Duration:    $([math]::Round($duration, 1))s" -ForegroundColor White
    Write-Host "Rows Loaded: $successCount / $totalRows" -ForegroundColor $(if ($errorCount -eq 0) { 'Green' } else { 'Yellow' })
    Write-Host "Errors:      $errorCount" -ForegroundColor $(if ($errorCount -gt 0) { 'Red' } else { 'Green' })
    Write-Host "Rate Limits: $rateLimits" -ForegroundColor $(if ($rateLimits -gt 0) { 'Yellow' } else { 'Green' })
    Write-Host "Throughput:  $throughput rows/sec" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "Documents:   $docLabel (with $LinesPerDoc lines each)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Next step: Run the Doc Staging Processor in BC to create documents from batch '$loadBatchId'." -ForegroundColor Yellow

    # Save results
    $resultsDir = Join-Path $PSScriptRoot ".." "results"
    if (-not (Test-Path $resultsDir)) { New-Item -ItemType Directory -Path $resultsDir | Out-Null }
    $timestamp   = Get-Date -Format "yyyyMMdd-HHmmss"
    $summaryFile = Join-Path $resultsDir "staging-$timestamp.csv"
    [PSCustomObject]@{
        Timestamp      = $overallStart.ToString("yyyy-MM-dd HH:mm:ss")
        Duration_Sec   = [math]::Round($duration, 2)
        BatchId        = $loadBatchId
        SalesOrders    = $SalesOrders
        PurchaseOrders = $PurchaseOrders
        LinesPerDoc    = $LinesPerDoc
        TotalRows      = $totalRows
        RowsLoaded     = $successCount
        Errors         = $errorCount
        RateLimits     = $rateLimits
        Throughput     = $throughput
        Threads        = $Threads
    } | Export-Csv -Path $summaryFile -NoTypeInformation
    Write-Host "Summary saved: $summaryFile" -ForegroundColor Gray
    Write-Host ""
}

# ─────────────────────────── Status Mode ───────────────────────────

function Start-Status {
    if (-not $BatchId) {
        Write-Host "ERROR: -BatchId is required for Status mode." -ForegroundColor Red
        exit 1
    }

    Write-Host "=== BATCH STATUS: $BatchId ===" -ForegroundColor Cyan
    Write-Host ""

    # Get all rows for this batch
    $allRows = @()
    $nextLink = "$stagingUrl?`$filter=batchId eq '$BatchId'&`$select=entryNo,documentGroupId,documentType,status,errorMessage,createdDocNumber,retryCount"
    while ($nextLink) {
        $resp = Invoke-BCApi -Method GET -Url $nextLink
        if (-not $resp.Success) {
            Write-Host "ERROR: $($resp.Error)" -ForegroundColor Red
            exit 1
        }
        $allRows += $resp.Data.value
        $nextLink = $resp.Data.'@odata.nextLink'
    }

    if ($allRows.Count -eq 0) {
        Write-Host "No staging rows found for batch '$BatchId'." -ForegroundColor Yellow
        return
    }

    # Status summary
    $groups = $allRows | Group-Object -Property status
    Write-Host "Total Rows: $($allRows.Count)" -ForegroundColor White
    foreach ($g in $groups) {
        $color = switch ($g.Name) {
            "Pending" { "Yellow" }
            "Processing" { "DarkYellow" }
            "Completed" { "Green" }
            "Error" { "Red" }
            default { "Gray" }
        }
        Write-Host "  $($g.Name): $($g.Count)" -ForegroundColor $color
    }
    Write-Host ""

    # Document groups
    $docGroups = $allRows | Group-Object -Property documentGroupId
    Write-Host "Document Groups: $($docGroups.Count)" -ForegroundColor White
    $completedDocs = ($allRows | Where-Object { $_.status -eq "Completed" -and $_.createdDocNumber } | Select-Object -Property createdDocNumber -Unique).Count
    Write-Host "Docs Created: $completedDocs" -ForegroundColor Green
    $soGroups = ($allRows | Where-Object { $_.documentType -eq "Sales Order" } | Select-Object -Property documentGroupId -Unique | Measure-Object).Count
    $poGroups = ($allRows | Where-Object { $_.documentType -eq "Purchase Order" } | Select-Object -Property documentGroupId -Unique | Measure-Object).Count
    if ($soGroups -gt 0) { Write-Host "  Sales Orders: $soGroups groups" -ForegroundColor Gray }
    if ($poGroups -gt 0) { Write-Host "  Purchase Orders: $poGroups groups" -ForegroundColor Gray }
    Write-Host ""

    # Show errors if any
    $errors = $allRows | Where-Object { $_.status -eq "Error" }
    if ($errors.Count -gt 0) {
        Write-Host "Errors:" -ForegroundColor Red
        $errorGroups = $errors | Group-Object -Property documentGroupId
        foreach ($eg in $errorGroups | Select-Object -First 10) {
            $firstErr = $eg.Group[0]
            Write-Host "  $($eg.Name): $($firstErr.errorMessage) (retries: $($firstErr.retryCount))" -ForegroundColor Red
        }
        if ($errorGroups.Count -gt 10) {
            Write-Host "  ... and $($errorGroups.Count - 10) more error groups" -ForegroundColor DarkRed
        }
    }
    Write-Host ""
}

# ─────────────────────────── Main ───────────────────────────

switch ($Mode) {
    "Validate" { Start-Validate }
    "Load"     { Start-Load }
    "Status"   { Start-Status }
}

Write-Host ""
Write-Host "Done." -ForegroundColor Cyan
