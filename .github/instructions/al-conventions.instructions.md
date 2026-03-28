---
description: "Use when writing AL code for Business Central extensions, creating API pages, codeunits, tables, or permission sets. Covers BC Cloud SaaS conventions, API page patterns, and object ID management."
applyTo: "**/*.al"
---
# AL / Business Central Conventions

## Project Identity
- Publisher: Wingate365
- Namespace: DefaultPublisher.docloadtest
- Object ID range: 50100–50149
- Runtime: 16.0, Application: 27.0.0.0
- Target: BC Cloud (SaaS) — never assume on-prem

## Build & Deploy
- Before building/deploying, always bump the version in `app.json` by incrementing the 4th segment: `n.n.n.+1` (e.g. 1.0.0.4 → 1.0.0.5)
- Never skip the version bump — BC will reject an upload with the same version already installed

## API Pages
- Use CRUD-style API pages sourced from standard BC tables (Sales Header, Purchase Header, etc.)
- Do NOT use ServiceEnabled bound actions — they have URL/entity binding issues in BC Cloud
- Always set `AutoSplitKey = true` on line sub-pages (Sales Line, Purchase Line) to auto-assign Line No.
- Always set `DelayedInsert = true` and `ODataKeyFields = SystemId` on API pages
- Always set `Extensible = false` on API pages
- Validate `Document Type` in `OnInsertRecord` trigger when sourcing from header/line tables with multiple document types
- Entity names should use the `LT` suffix to avoid collisions with standard BC API entities (e.g. `salesOrderLT`, `purchaseOrderLT`)

## Code Hygiene
- No dead code — remove orphaned procedures, unused enum values, and unreferenced variables immediately
- No unnecessary objects — update existing pages/codeunits rather than creating new ones unless there's a clear reason
- Every page and table must be included in the permission set (50100)
- Keep `using` statements to the minimum required

## Naming
- API EntityName: camelCase with `LT` suffix (e.g. `salesOrderLineLT`)
- API EntitySetName: plural camelCase with `LT` suffix (e.g. `salesOrderLinesLT`)
- Batch IDs: prefix with `LT-` for easy filtering and cleanup
