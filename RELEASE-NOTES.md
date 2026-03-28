# Release Notes

## Version 1.0.0.3 — 2026-03-26

### Changes
- **Removed dead code**: Removed orphaned `CreateSingleSOFromAPI` and `CreateSinglePOFromAPI` procedures from the engine codeunit. These were leftover from an earlier bound-action API approach that has been replaced by CRUD-style API pages.
- **Removed unused enum values**: Removed `Create SO via API` and `Create PO via API` from the `Doc Load Test Type` enum (values 4 and 5) — they were only referenced by the removed procedures.
- **Minor fix**: Removed a dead variable assignment (`LineNo := 10000`) in `CreateSalesOrder` that was immediately overwritten by the for-loop.

---

## Version 1.0.0.2 — 2026-03-26

### Changes
- **Custom CRUD API pages**: Rewrote API pages 50110 and 50111 from sourcing the results table to directly sourcing `Sales Header` and `Purchase Header`. These now function as standard CRUD endpoints that mirror the built-in BC API but with batch ID fields.
- **New line sub-pages**: Added SO Lines API page (50112) and PO Lines API page (50113) for creating document lines via the custom API.
- **Batch ID support**: Sales Orders stamp the batch ID on `External Document No.`; Purchase Orders stamp it on `Vendor Shipment No.`. Both use the `LT-` prefix for easy filtering and cleanup.
- **Permission set updated**: Added pages 50112 and 50113 to the `Doc Load Test` permission set.
- **Engine updated**: `CreateSalesOrder` and `CreatePurchaseOrder` procedures now accept a `BatchId` parameter.

### API Endpoints
Custom API pages are exposed at:
```
POST /api/defaultpublisher/docloadtest/v1.0/companies({id})/salesOrdersLT
POST /api/defaultpublisher/docloadtest/v1.0/companies({id})/salesOrdersLT({id})/salesOrderLinesLT
POST /api/defaultpublisher/docloadtest/v1.0/companies({id})/purchaseOrdersLT
POST /api/defaultpublisher/docloadtest/v1.0/companies({id})/purchaseOrdersLT({id})/purchaseOrderLinesLT
```

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
