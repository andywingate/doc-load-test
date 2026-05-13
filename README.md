[![View Reports Site](https://img.shields.io/badge/Reports%20Site-View%20Interactive%20Docs-blue?style=for-the-badge&logo=github)](https://andywingate.github.io/doc-load-test/)

# Document Load Test for Business Central

A Business Central extension and PowerShell test harness for stress testing the BC Cloud SaaS API. Creates Sales Orders and Purchase Orders at scale using multiple strategies — from simple sequential inserts to multi-threaded deep insert sprints and staging table batch processing.

## What You Can Do

### Direct API Load Testing (`bc-load-test.ps1`)

| Mode | Description |
|---|---|
| **Validate** | Quick smoke test — 1 SO + 1 PO to verify connectivity |
| **Full** | Sequential creation of N documents |
| **Read** | Read-only stress test — fetches existing documents |
| **Concurrent** | Multi-threaded creation using PowerShell jobs |
| **Race** | Time-boxed — creates as many documents as possible in N minutes |
| **Endurance** | Long-running cyclic test — alternates SO/PO phases for hours |
| **DeepInsert** | Race mode using deep insert API (header + lines in 1 call, ~75% fewer API calls) |
| **Sprint** | Maximum throughput — multi-threading + deep insert + optional dual-app credentials |

### Staging Table Batch Processing (`bc-staging-load.ps1`)

Bulk-load Sales Order data into a flat staging table via a lightweight API page, then process into real Sales Orders server-side with error isolation and retry.

| Mode | Description |
|---|---|
| **Validate** | Posts 1 test staging row to confirm API connectivity |
| **Load** | Bulk-loads staging rows with multi-threading, then triggers server-side processing |
| **Status** | Queries batch processing status and statistics |

**Staging features**: Status tracking (Pending → Processing → Completed / Error), automatic retry with configurable max attempts, error message capture, batch statistics, created SO number stamped back to staging rows.

### Dual-App Rate Limit Bypass

For Sprint mode, configure two separate Entra app registrations so SO and PO threads get independent API rate limit quotas — up to 2x throughput vs single app.

### Interactive Reports

Test results are published as interactive HTML reports on GitHub Pages with:
- Per-run throughput charts and timelines
- Master overview dashboard with trends across all test runs
- Technical analysis page with API rate limit math and throughput theory
- Thread scaling studies (5/10/15 threads)

## Project Structure

```
├── app.json                          # AL app manifest (v1.0.0.10)
├── src/
│   ├── API/
│   │   ├── SalesOrderLoadTestAPI.Page.al     # SO CRUD API (50110)
│   │   ├── SOLinesLoadTestAPI.Page.al        # SO Lines sub-page (50112)
│   │   ├── PurchaseOrderLoadTestAPI.Page.al  # PO CRUD API (50111)
│   │   ├── POLinesLoadTestAPI.Page.al        # PO Lines sub-page (50113)
│   │   ├── SalesOrderDeepInsertAPI.Page.al   # SO Deep Insert API (50114)
│   │   ├── SOLinesDeepInsertAPI.Page.al      # SO Lines Deep Insert (50115)
│   │   ├── PurchaseOrderDeepInsertAPI.Page.al # PO Deep Insert API (50116)
│   │   └── POLinesDeepInsertAPI.Page.al      # PO Lines Deep Insert (50117)
│   ├── Staging/
│   │   ├── SOStagingLine.Table.al            # Staging table (50102)
│   │   ├── SOStagingAPI.Page.al              # Staging API page (50118)
│   │   └── SOStagingProcessor.Codeunit.al    # Server-side processor (50103)
│   ├── Engine/
│   │   ├── DocLoadTestEngine.Codeunit.al     # Core test engine (50100)
│   │   ├── DocLoadTestDataGen.Codeunit.al    # Data generation (50101)
│   │   └── SkipCreditLimitCheck.Codeunit.al  # Credit limit bypass (50102)
│   ├── Setup/
│   │   ├── DocLoadTestSetup.Table.al         # Configuration table (50100)
│   │   └── DocLoadTestSetup.Page.al          # Configuration card (50100)
│   ├── Results/
│   │   ├── DocLoadTestResult.Table.al        # Results log (50101)
│   │   ├── DocLoadTestResults.Page.al        # Results list (50101)
│   │   └── DocLoadTestType.Enum.al           # Test type enum (50100)
│   └── Permissions/
│       └── DocLoadTest.PermissionSet.al      # Permission set (50100)
├── scripts/
│   ├── bc-load-test.ps1                      # Main load test script
│   ├── bc-staging-load.ps1                   # Staging table load script
│   └── get-bc-token.ps1                      # OAuth2 token helper
├── docs/                                     # GitHub Pages reports site
└── results/                                  # Local CSV results (gitignored)
```

## Prerequisites

- Business Central Cloud (SaaS) environment
- An **Entra (Azure AD) application** registered with:
  - A client secret
  - API permission: `https://api.businesscentral.dynamics.com/.default`
  - Registered in BC via **Microsoft Entra Application** card with appropriate permissions
- PowerShell 7+
- At least one customer, vendor, and item with valid posting groups configured

## Quick Start

### 1. Deploy the Extension

Build the `.app` file (Ctrl+Shift+B in VS Code) and upload to your BC environment via **Extension Management**.

### 2. Validate Connectivity

```powershell
.\scripts\bc-load-test.ps1 -Mode Validate -LinesPerDoc 3 -ClientSecret "your-secret"
```

### 3. Run a Sprint Test

```powershell
.\scripts\bc-load-test.ps1 -Mode Sprint -SprintDurationSeconds 60 -SprintThreads 10 -LinesPerDoc 3
```

### 4. Try the Staging Approach

```powershell
.\scripts\bc-staging-load.ps1 -Mode Validate -ClientSecret "your-secret"
.\scripts\bc-staging-load.ps1 -Mode Load -SalesOrders 50 -LinesPerDoc 3 -Threads 5
.\scripts\bc-staging-load.ps1 -Mode Status -BatchId "BATCH-20260329-123456"
```

## Custom API Endpoints

Base URL: `/api/defaultpublisher/docloadtest/v1.0/companies({companyId})/`

| Endpoint | Description |
|---|---|
| `salesOrdersLT` | SO CRUD with batch field on `externalDocumentNumber` |
| `salesOrdersLT({id})/salesOrderLinesLT` | SO Lines |
| `purchaseOrdersLT` | PO CRUD with batch field on `vendorShipmentNo` |
| `purchaseOrdersLT({id})/purchaseOrderLinesLT` | PO Lines |
| `salesOrdersDI` | SO Deep Insert (header + lines in 1 POST) |
| `purchaseOrdersDI` | PO Deep Insert (header + lines in 1 POST) |
| `soStagingLinesLT` | SO Staging table (flat, no validation) |

## Configuration

### bc-load-test.ps1 Parameters

| Parameter | Default | Description |
|---|---|---|
| `-Mode` | `Validate` | `Validate`, `Full`, `Read`, `Concurrent`, `Race`, `Endurance`, `DeepInsert`, `Sprint` |
| `-SalesOrders` | 10 | Number of Sales Orders |
| `-PurchaseOrders` | 10 | Number of Purchase Orders |
| `-LinesPerDoc` | 3 | Lines per document |
| `-ConcurrentJobs` | 3 | Parallel jobs (Concurrent mode) |
| `-RaceMinutes` | 5 | Duration (Race/DeepInsert modes) |
| `-CycleMinutes` | 10 | Cycle duration (Endurance mode) |
| `-EnduranceMaxMinutes` | 120 | Max runtime (Endurance mode) |
| `-SprintDurationSeconds` | 60 | Sprint duration |
| `-SprintThreads` | 10 | Sprint parallel threads |
| `-UseDeepInsert` | (switch) | Use deep insert in Endurance mode |

### bc-staging-load.ps1 Parameters

| Parameter | Default | Description |
|---|---|---|
| `-Mode` | `Validate` | `Validate`, `Load`, `Status` |
| `-SalesOrders` | 10 | Number of Sales Orders to stage |
| `-LinesPerDoc` | 3 | Lines per document |
| `-Threads` | 5 | Parallel load threads |
| `-BatchId` | (auto) | Batch ID for Status queries |

### Dual-App Configuration

Set in `.env` for independent SO/PO rate limits:
```
BC_CLIENT_ID_SO=your-so-app-id
BC_CLIENT_SECRET_SO=your-so-secret
BC_CLIENT_ID_PO=your-po-app-id
BC_CLIENT_SECRET_PO=your-po-secret
```

## Object ID Range

| Range | Objects |
|---|---|
| 50100–50102 | Tables (Setup, Results, SO Staging Line) |
| 50100–50101 | Pages (Setup Card, Results List) |
| 50110–50118 | API Pages (SO, SO Lines, PO, PO Lines, Deep Insert x4, Staging) |
| 50100–50103 | Codeunits (Engine, Data Gen, Credit Limit Skip, Staging Processor) |
| 50100 | Enum (Test Type), Permission Set |

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
