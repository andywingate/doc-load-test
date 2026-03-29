# Release Notes

## Version 1.0.0.10 — 2026-03-29 (unreleased)

### Staging Table Approach
- **New table**: SO Staging Line (50102) — flat denormalized staging table for Sales Order data. One row per line, grouped by Batch ID + Document Group ID.
- **New API page**: SO Staging API (50118) — lightweight API page for fast POSTs with no BC validation overhead. Entity: `soStagingLinesLT`.
- **New codeunit**: SO Staging Processor (50103) — groups staging rows by Document Group ID and creates real Sales Orders using `Codeunit.Run()` error isolation with `Commit()` before each attempt.
- **New script**: `bc-staging-load.ps1` — PowerShell script to load staging rows via API with Validate, Load, and Status modes. Supports multi-threading via `Start-Job`.
- **Credit limit skip**: Added codeunit 50102 `Skip Credit Limit Check` — event subscriber that suppresses credit limit checks during bulk test loads.
- **Deep insert fix**: Removed `Editable = false` from the `number` field on SO and PO Deep Insert API pages (50114, 50116) to allow explicit document number assignment.
- **Permission set updated**: Added SO Staging Line table/tabledata, SO Staging API page, SO Staging Processor codeunit, and Skip Credit Limit Check codeunit.

### Staging Table Features
- Status tracking: Pending → Processing → Completed / Error
- Error capture with message and retry count (default max 3)
- Reprocess failed rows by batch or globally
- Batch statistics via `GetBatchStats()` procedure
- Created SO number stamped back to staging rows on success

---

## Version 1.0.0.7 — 2026-03-29

### Changes
- **Overview dashboard**: Added master overview page (`docs/overview.html`) with test trend charts and KPI summary across all test runs.
- **Technical analysis**: Added comprehensive technical analysis page with API rate limit math, throughput theory, and Microsoft docs citations.
- **Test data**: Added `docs/test-data.json` for chart data.
- **Docs improvements**: Separated SO/PO throughput lines in charts, thread scaling study (5/10/15 threads), log-scale bar charts.

---

## Version 1.0.0.6 — 2026-03-29

### Changes
- **Sprint test mode**: New high-throughput mode combining multi-threading + deep insert to maximise document creation in a fixed time window.
- **Multi-app support**: Separate Entra app credentials for SO and PO threads (`BC_CLIENT_ID_SO`, `BC_CLIENT_SECRET_SO`, `BC_CLIENT_ID_PO`, `BC_CLIENT_SECRET_PO`) to avoid sharing API rate limit quotas.
- **Sprint parameters**: `-SprintDurationSeconds`, `-SprintThreads` for configuring sprint runs.
- **README updated**: Documented Sprint mode, dual-app configuration, and full parameter table.

---

## Version 1.0.0.5 — 2026-03-28

### Changes
- **Deep Insert API pages**: Added SO Deep Insert API (50114), SO Lines Deep Insert (50115), PO Deep Insert API (50116), PO Lines Deep Insert (50117) — header + lines in a single POST, ~75% fewer API calls.
- **Results table**: Added Doc Load Test Result table (50101), Results list page (50101), and Doc Load Test Type enum (50100).
- **New test modes**: Endurance (long-running cyclic), Race (time-boxed), DeepInsert (race with deep insert).
- **GitHub Pages**: Published interactive HTML test reports to `/docs` site.
- **Script improvements**: HTML report generation, endurance cycle management, deep insert payloads.

---

## Version 1.0.0.4 — 2026-03-27

### Changes
- **Concurrent mode**: Multi-threaded document creation using PowerShell `Start-Job`.
- **Read mode**: Read-only stress test for fetching existing documents.
- **Rate limit handling improvements**: Enhanced 429 retry logic in the main load test script.

---

## Version 1.0.0.3 — 2026-03-26

### Changes
- **Removed dead code**: Removed orphaned `CreateSingleSOFromAPI` and `CreateSinglePOFromAPI` procedures from the engine codeunit.
- **Removed unused enum values**: Removed `Create SO via API` and `Create PO via API` from the `Doc Load Test Type` enum (values 4 and 5).
- **Minor fix**: Removed a dead variable assignment (`LineNo := 10000`) in `CreateSalesOrder`.

---

## Version 1.0.0.2 — 2026-03-26

### Changes
- **Custom CRUD API pages**: Rewrote API pages 50110 and 50111 to directly source `Sales Header` and `Purchase Header` as standard CRUD endpoints with batch ID fields.
- **New line sub-pages**: Added SO Lines API page (50112) and PO Lines API page (50113).
- **Batch ID support**: Sales Orders stamp batch ID on `External Document No.`; Purchase Orders on `Vendor Shipment No.` with `LT-` prefix.
- **Permission set updated**: Added pages 50112 and 50113.
- **Engine updated**: `CreateSalesOrder` and `CreatePurchaseOrder` now accept a `BatchId` parameter.

---

## Version 1.0.0.1 — 2026-03-25

### Changes
- **Permission set**: Added `Doc Load Test` permission set (50100) to resolve PTE0004 deployment error.
- **PowerShell scripts**: Converted from k6/JavaScript to pure PowerShell with OAuth2 client credentials flow.
- **Client credentials auth**: Replaced device code flow with client credentials via Entra app registration.
- **Rate limit handling**: Added retry logic with 429 backoff in the PowerShell helper function.

---

## Version 1.0.0.0 — 2026-03-25

### Initial Release
- **Tables**: Doc Load Test Setup (50100), Doc Load Test Result (50101)
- **Pages**: Setup card (50100), Results list (50101)
- **Codeunits**: Test engine (50100) with bulk SO/PO creation, read stress tests, and cleanup; Data generation helper (50101) with auto-creation of test customer, vendor, and item.
- **Enum**: Doc Load Test Type (50100) — Create Sales Orders, Create Purchase Orders, Read Sales Orders, Read Purchase Orders.
- **Test modes**: Bulk creation from BC UI, result logging with throughput metrics (docs/sec, lines/sec).
