namespace DefaultPublisher.docloadtest;

using Microsoft.Sales.Document;
using Microsoft.Purchases.Document;

codeunit 50100 "Doc Load Test Engine"
{
    // ──────────────────────────── Sales Order Creation ────────────────────────────
    procedure RunSalesOrderTest(var Setup: Record "Doc Load Test Setup")
    var
        Result: Record "Doc Load Test Result";
        DataGen: Codeunit "Doc Load Test Data Gen";
        CustomerNo: Code[20];
        ItemNo: Code[20];
        StartDT: DateTime;
        i: Integer;
        j: Integer;
        DocCount: Integer;
        LineCount: Integer;
        ErrorCount: Integer;
        LastErr: Text[2048];
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        BatchId: Text[35];
    begin
        CustomerNo := DataGen.EnsureTestCustomer(Setup);
        ItemNo := DataGen.EnsureTestItem(Setup);

        BatchId := 'LT-' + Format(CurrentDateTime(), 0, '<Year4><Month,2><Day,2>-<Hours24,2><Minutes,2><Seconds,2>');
        StartDT := CurrentDateTime();
        DocCount := 0;
        LineCount := 0;
        ErrorCount := 0;

        for i := 1 to Setup."No. of Sales Orders" do begin
            if CreateSalesOrder(CustomerNo, ItemNo, Setup."SO Lines Per Document", SalesHeader, LastErr, BatchId) then begin
                DocCount += 1;
                LineCount += Setup."SO Lines Per Document";
            end else
                ErrorCount += 1;

            if (i mod Setup."Batch Size") = 0 then
                Commit();
        end;
        Commit();

        LogResult(
            "Doc Load Test Type"::"Create Sales Orders",
            StartDT,
            Setup."No. of Sales Orders",
            DocCount,
            Setup."SO Lines Per Document",
            LineCount,
            0,
            ErrorCount,
            LastErr,
            Setup."Batch Size"
        );

        Setup."Last Run Date-Time" := CurrentDateTime();
        Setup.Modify();

        Message('Sales Order stress test complete.\Documents: %1 created (%2 requested)\Lines: %3\Duration: %4 ms\Errors: %5',
            DocCount, Setup."No. of Sales Orders", LineCount,
            CurrentDateTime() - StartDT, ErrorCount);
    end;

    local procedure CreateSalesOrder(
        CustomerNo: Code[20];
        ItemNo: Code[20];
        LinesPer: Integer;
        var SalesHeader: Record "Sales Header";
        var ErrorMsg: Text[2048];
        BatchId: Text[35]
    ): Boolean
    var
        SalesLine: Record "Sales Line";
        LineNo: Integer;
    begin
        Clear(SalesHeader);
        SalesHeader.Init();
        SalesHeader.Validate("Document Type", SalesHeader."Document Type"::Order);
        SalesHeader.Insert(true);
        SalesHeader.Validate("Sell-to Customer No.", CustomerNo);
        SalesHeader.Validate("External Document No.", BatchId);
        SalesHeader.Modify(true);

        for LineNo := 1 to LinesPer do begin
            Clear(SalesLine);
            SalesLine.Init();
            SalesLine.Validate("Document Type", SalesHeader."Document Type");
            SalesLine.Validate("Document No.", SalesHeader."No.");
            SalesLine.Validate("Line No.", LineNo * 10000);
            SalesLine.Insert(true);
            SalesLine.Validate(Type, SalesLine.Type::Item);
            SalesLine.Validate("No.", ItemNo);
            SalesLine.Validate(Quantity, 1);
            SalesLine.Modify(true);
        end;
        exit(true);
    end;

    // ──────────────────────────── Purchase Order Creation ─────────────────────────
    procedure RunPurchaseOrderTest(var Setup: Record "Doc Load Test Setup")
    var
        DataGen: Codeunit "Doc Load Test Data Gen";
        VendorNo: Code[20];
        ItemNo: Code[20];
        StartDT: DateTime;
        i: Integer;
        DocCount: Integer;
        LineCount: Integer;
        ErrorCount: Integer;
        LastErr: Text[2048];
        PurchHeader: Record "Purchase Header";
        BatchId: Text[35];
    begin
        VendorNo := DataGen.EnsureTestVendor(Setup);
        ItemNo := DataGen.EnsureTestItem(Setup);

        BatchId := 'LT-' + Format(CurrentDateTime(), 0, '<Year4><Month,2><Day,2>-<Hours24,2><Minutes,2><Seconds,2>');
        StartDT := CurrentDateTime();
        DocCount := 0;
        LineCount := 0;
        ErrorCount := 0;

        for i := 1 to Setup."No. of Purchase Orders" do begin
            if CreatePurchaseOrder(VendorNo, ItemNo, Setup."PO Lines Per Document", PurchHeader, LastErr, BatchId) then begin
                DocCount += 1;
                LineCount += Setup."PO Lines Per Document";
            end else
                ErrorCount += 1;

            if (i mod Setup."Batch Size") = 0 then
                Commit();
        end;
        Commit();

        LogResult(
            "Doc Load Test Type"::"Create Purchase Orders",
            StartDT,
            Setup."No. of Purchase Orders",
            DocCount,
            Setup."PO Lines Per Document",
            LineCount,
            0,
            ErrorCount,
            LastErr,
            Setup."Batch Size"
        );

        Setup."Last Run Date-Time" := CurrentDateTime();
        Setup.Modify();

        Message('Purchase Order stress test complete.\Documents: %1 created (%2 requested)\Lines: %3\Duration: %4 ms\Errors: %5',
            DocCount, Setup."No. of Purchase Orders", LineCount,
            CurrentDateTime() - StartDT, ErrorCount);
    end;

    local procedure CreatePurchaseOrder(
        VendorNo: Code[20];
        ItemNo: Code[20];
        LinesPer: Integer;
        var PurchHeader: Record "Purchase Header";
        var ErrorMsg: Text[2048];
        BatchId: Text[35]
    ): Boolean
    var
        PurchLine: Record "Purchase Line";
        LineNo: Integer;
    begin
        Clear(PurchHeader);
        PurchHeader.Init();
        PurchHeader.Validate("Document Type", PurchHeader."Document Type"::Order);
        PurchHeader.Insert(true);
        PurchHeader.Validate("Buy-from Vendor No.", VendorNo);
        PurchHeader.Validate("Vendor Shipment No.", BatchId);
        PurchHeader.Modify(true);

        for LineNo := 1 to LinesPer do begin
            Clear(PurchLine);
            PurchLine.Init();
            PurchLine.Validate("Document Type", PurchHeader."Document Type");
            PurchLine.Validate("Document No.", PurchHeader."No.");
            PurchLine.Validate("Line No.", LineNo * 10000);
            PurchLine.Insert(true);
            PurchLine.Validate(Type, PurchLine.Type::Item);
            PurchLine.Validate("No.", ItemNo);
            PurchLine.Validate(Quantity, 1);
            PurchLine.Modify(true);
        end;
        exit(true);
    end;

    // ──────────────────────────── Read Stress Tests ──────────────────────────────
    procedure RunReadSalesOrders()
    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        StartDT: DateTime;
        DocCount: Integer;
        LineCount: Integer;
    begin
        StartDT := CurrentDateTime();
        DocCount := 0;
        LineCount := 0;

        SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::Order);
        if SalesHeader.FindSet() then
            repeat
                DocCount += 1;
                SalesLine.SetRange("Document Type", SalesHeader."Document Type");
                SalesLine.SetRange("Document No.", SalesHeader."No.");
                if SalesLine.FindSet() then
                    repeat
                        LineCount += 1;
                    until SalesLine.Next() = 0;
            until SalesHeader.Next() = 0;

        LogResult(
            "Doc Load Test Type"::"Read Sales Orders",
            StartDT,
            0, 0, 0, 0,
            DocCount,
            0, '', 0
        );

        Message('Read Sales Orders complete.\Documents read: %1\Lines read: %2\Duration: %3 ms',
            DocCount, LineCount, CurrentDateTime() - StartDT);
    end;

    procedure RunReadPurchaseOrders()
    var
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        StartDT: DateTime;
        DocCount: Integer;
        LineCount: Integer;
    begin
        StartDT := CurrentDateTime();
        DocCount := 0;
        LineCount := 0;

        PurchHeader.SetRange("Document Type", PurchHeader."Document Type"::Order);
        if PurchHeader.FindSet() then
            repeat
                DocCount += 1;
                PurchLine.SetRange("Document Type", PurchHeader."Document Type");
                PurchLine.SetRange("Document No.", PurchHeader."No.");
                if PurchLine.FindSet() then
                    repeat
                        LineCount += 1;
                    until PurchLine.Next() = 0;
            until PurchHeader.Next() = 0;

        LogResult(
            "Doc Load Test Type"::"Read Purchase Orders",
            StartDT,
            0, 0, 0, 0,
            DocCount,
            0, '', 0
        );

        Message('Read Purchase Orders complete.\Documents read: %1\Lines read: %2\Duration: %3 ms',
            DocCount, LineCount, CurrentDateTime() - StartDT);
    end;

    // ──────────────────────────── Cleanup ────────────────────────────────────────
    procedure CleanupTestDocuments()
    var
        SalesHeader: Record "Sales Header";
        PurchHeader: Record "Purchase Header";
    begin
        SalesHeader.SetRange("Document Type", SalesHeader."Document Type"::Order);
        SalesHeader.SetFilter("External Document No.", 'LT-*');
        SalesHeader.DeleteAll(true);

        PurchHeader.SetRange("Document Type", PurchHeader."Document Type"::Order);
        PurchHeader.SetFilter("Vendor Shipment No.", 'LT-*');
        PurchHeader.DeleteAll(true);
    end;

    // ──────────────────────────── Result Logging ─────────────────────────────────
    local procedure LogResult(
        TestType: Enum "Doc Load Test Type";
        StartDT: DateTime;
        DocsRequested: Integer;
        DocsCreated: Integer;
        LinesPerDoc: Integer;
        TotalLines: Integer;
        DocsRead: Integer;
        Errors: Integer;
        LastError: Text[2048];
        BatchSize: Integer
    )
    var
        Result: Record "Doc Load Test Result";
        DurationMS: BigInteger;
        DurationDec: Decimal;
    begin
        Result.Init();
        Result."Entry No." := 0;
        Result."Test Type" := TestType;
        Result."Start Date-Time" := StartDT;
        Result."End Date-Time" := CurrentDateTime();
        DurationMS := CurrentDateTime() - StartDT;
        Result."Duration (ms)" := DurationMS;
        Result."Documents Requested" := DocsRequested;
        Result."Documents Created" := DocsCreated;
        Result."Lines Per Document" := LinesPerDoc;
        Result."Total Lines Created" := TotalLines;
        Result."Documents Read" := DocsRead;
        Result.Errors := Errors;
        Result."Last Error Message" := CopyStr(LastError, 1, MaxStrLen(Result."Last Error Message"));
        Result."Batch Size Used" := BatchSize;
        Result.Success := (Errors = 0);

        if DurationMS > 0 then begin
            DurationDec := DurationMS;
            if DocsCreated > 0 then
                Result."Docs Per Second" := (DocsCreated / DurationDec) * 1000;
            if TotalLines > 0 then
                Result."Lines Per Second" := (TotalLines / DurationDec) * 1000;
            if DocsRead > 0 then
                Result."Docs Per Second" := (DocsRead / DurationDec) * 1000;
        end;

        Result.Insert(true);
    end;
}
