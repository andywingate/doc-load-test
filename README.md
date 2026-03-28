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
| `-Mode` | `Validate` | Test mode: `Validate`, `Full`, `Read`, `Concurrent` |
| `-SalesOrders` | 10 | Number of Sales Orders to create |
| `-PurchaseOrders` | 10 | Number of Purchase Orders to create |
| `-LinesPerDoc` | 3 | Lines per document |
| `-ConcurrentJobs` | 3 | Parallel jobs (Concurrent mode only) |
| `-CustomerNo` | *(auto-detect)* | Customer number to use |
| `-VendorNo` | *(auto-detect)* | Vendor number to use |
| `-ItemNo` | *(auto-detect)* | Item number to use |
| `-ClientSecret` | *(required)* | Entra app client secret |

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
