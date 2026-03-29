# Document Load Test for Business Central

A Business Central extension and PowerShell test harness for stress testing the BC API's ability to create and read Sales Orders and Purchase Orders at scale.

## Overview

This project has two components:

1. **AL Extension** — Custom API pages that expose Sales Order and Purchase Order creation with a batch ID field for filtering/cleanup. Also includes a BC-side UI for running tests directly from the client.
2. **PowerShell Scripts** — External load test scripts that call the BC API to create and read documents, with support for sequential, concurrent, and read-only test modes.

## Project Structure

```
├── app.json                          # AL app manifest
├── src/
│   ├── API/
│   │   ├── SalesOrderLoadTestAPI.Page.al     # Custom SO API (page 50110)
│   │   ├── SOLinesLoadTestAPI.Page.al        # Custom SO Lines sub-page (page 50112)
│   │   ├── PurchaseOrderLoadTestAPI.Page.al  # Custom PO API (page 50111)
│   │   └── POLinesLoadTestAPI.Page.al        # Custom PO Lines sub-page (page 50113)
│   ├── Engine/
│   │   ├── DocLoadTestEngine.Codeunit.al     # Core test engine (codeunit 50100)
│   │   └── DocLoadTestDataGen.Codeunit.al    # Test data generation (codeunit 50101)
│   ├── Setup/
│   │   ├── DocLoadTestSetup.Table.al         # Configuration table (table 50100)
│   │   └── DocLoadTestSetup.Page.al          # Configuration card (page 50100)
│   ├── Results/
│   │   ├── DocLoadTestResult.Table.al        # Results log table (table 50101)
│   │   ├── DocLoadTestResults.Page.al        # Results list (page 50101)
│   │   └── DocLoadTestType.Enum.al           # Test type enum (enum 50100)
│   └── Permissions/
│       └── DocLoadTest.PermissionSet.al      # Permission set (50100)
├── scripts/
│   ├── bc-load-test.ps1                      # Main load test script
│   └── get-bc-token.ps1                      # OAuth2 token helper
```

## Prerequisites

- Business Central Cloud (SaaS) environment
- An **Entra (Azure AD) application** registered with:
  - A client secret
  - API permission: `https://api.businesscentral.dynamics.com/.default`
  - Registered in BC via **Microsoft Entra Application** card with appropriate permissions
- PowerShell 7+ (for the external scripts)
- At least one customer, vendor, and item with valid posting groups configured

## Quick Start

### 1. Deploy the Extension

Build the `.app` file (Ctrl+Shift+B in VS Code) and upload it to your BC environment via **Extension Management**.

### 2. Run a Validation Test

```powershell
.\scripts\bc-load-test.ps1 -Mode Validate -LinesPerDoc 3 -ClientSecret "your-secret"
```

This creates 1 Sales Order and 1 Purchase Order to confirm the API connection works.

### 3. Run a Full Load Test

```powershell
.\scripts\bc-load-test.ps1 -Mode Full -SalesOrders 100 -PurchaseOrders 100 -LinesPerDoc 5 -ClientSecret "your-secret"
```

## Test Modes

The script supports multiple test modes:

### Validate
Quick smoke test — creates 1 SO and 1 PO with lines to verify connectivity.
```powershell
.\scripts\bc-load-test.ps1 -Mode Validate
```

### Full
Creates a specified number of documents sequentially.
```powershell
.\scripts\bc-load-test.ps1 -Mode Full -SalesOrders 100 -PurchaseOrders 100 -LinesPerDoc 5
```

### Read
Read-only stress test — fetches existing documents.
```powershell
.\scripts\bc-load-test.ps1 -Mode Read
```

### Concurrent
Multi-threaded document creation using PowerShell jobs.
```powershell
.\scripts\bc-load-test.ps1 -Mode Concurrent -ConcurrentJobs 5 -SalesOrders 50
```

### Race
Time-based test — creates as many documents as possible in a fixed time window.
```powershell
.\scripts\bc-load-test.ps1 -Mode Race -RaceMinutes 5 -LinesPerDoc 3
```

### Endurance
Long-running cyclic test — alternates between SO and PO creation phases for hours.
```powershell
.\scripts\bc-load-test.ps1 -Mode Endurance -CycleMinutes 10 -EnduranceMaxMinutes 120 -UseDeepInsert
```

### DeepInsert
Race test using deep insert API (header + lines in 1 call) — 75% fewer API calls.
```powershell
.\scripts\bc-load-test.ps1 -Mode DeepInsert -RaceMinutes 5 -LinesPerDoc 3
```

### Sprint (NEW)
**Maximum throughput test** — uses multi-threading + deep insert to create as many documents as possible in 1 minute.

**Single App Mode:**
```powershell
.\scripts\bc-load-test.ps1 -Mode Sprint -SprintDurationSeconds 60 -SprintThreads 10 -LinesPerDoc 3
```

**Dual App Mode (Recommended):**
For maximum performance, create two separate Entra apps and configure them in `.env`:
```bash
BC_CLIENT_ID_SO=your-so-app-id
BC_CLIENT_SECRET_SO=your-so-secret
BC_CLIENT_ID_PO=your-po-app-id
BC_CLIENT_SECRET_PO=your-po-secret
```

This gives:
- SO threads use dedicated SO app (independent rate limit)
- PO threads use dedicated PO app (independent rate limit)
- True parallel execution without sharing rate limit quotas
- 2x throughput potential vs single app

Run with:
```powershell
.\scripts\bc-load-test.ps1 -Mode Sprint -SprintDurationSeconds 60 -SprintThreads 20 -LinesPerDoc 3
```

## Custom API Endpoints

The extension exposes custom API pages under:

```
/api/defaultpublisher/docloadtest/v1.0/companies({companyId})/
```

| Endpoint | Method | Description |
|---|---|---|
| `salesOrdersLT` | GET/POST | Sales Orders with `externalDocumentNumber` batch field |
| `salesOrdersLT({id})/salesOrderLinesLT` | GET/POST | Sales Order Lines |
| `purchaseOrdersLT` | GET/POST | Purchase Orders with `vendorShipmentNo` batch field |
| `purchaseOrdersLT({id})/purchaseOrderLinesLT` | GET/POST | Purchase Order Lines |

## Configuration

All script parameters can be overridden on the command line:

| Parameter | Default | Description |
|---|---|---|
| `-Mode` | `Validate` | Test mode: `Validate`, `Full`, `Read`, `Concurrent`, `Race`, `Endurance`, `DeepInsert`, `Sprint` |
| `-SalesOrders` | 10 | Number of Sales Orders to create |
| `-PurchaseOrders` | 10 | Number of Purchase Orders to create |
| `-LinesPerDoc` | 3 | Lines per document |
| `-ConcurrentJobs` | 3 | Parallel jobs (Concurrent mode only) |
| `-RaceMinutes` | 5 | Duration for Race/DeepInsert modes (minutes) |
| `-CycleMinutes` | 10 | Cycle duration for Endurance mode (minutes) |
| `-EnduranceMaxMinutes` | 120 | Maximum runtime for Endurance mode (minutes) |
| `-SprintDurationSeconds` | 60 | Sprint test duration (seconds) |
| `-SprintThreads` | 10 | Number of parallel threads for Sprint mode |
| `-UseDeepInsert` | (switch) | Use deep insert API in Endurance mode |
| `-CustomerNo` | *(auto-detect)* | Customer number to use |
| `-VendorNo` | *(auto-detect)* | Vendor number to use |
| `-ItemNo` | *(auto-detect)* | Item number to use |
| `-ClientSecret` | *(required)* | Entra app client secret |
| `-ClientId_SO` | `$env:BC_CLIENT_ID_SO` | Sales Order app client ID (Sprint mode) |
| `-ClientSecret_SO` | `$env:BC_CLIENT_SECRET_SO` | Sales Order app secret (Sprint mode) |
| `-ClientId_PO` | `$env:BC_CLIENT_ID_PO` | Purchase Order app client ID (Sprint mode) |
| `-ClientSecret_PO` | `$env:BC_CLIENT_SECRET_PO` | Purchase Order app secret (Sprint mode) |

## Object ID Range

| Range | Objects |
|---|---|
| 50100–50101 | Tables (Setup, Results) |
| 50100–50101 | Pages (Setup Card, Results List) |
| 50110–50113 | API Pages (SO, SO Lines, PO, PO Lines) |
| 50100–50101 | Codeunits (Engine, Data Gen) |
| 50100 | Enum (Test Type), Permission Set |

## License

Internal use only.
