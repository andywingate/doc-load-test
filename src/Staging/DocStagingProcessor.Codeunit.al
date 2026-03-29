namespace DefaultPublisher.docloadtest;

using Microsoft.Sales.Document;
using Microsoft.Purchases.Document;

codeunit 50103 "Doc Staging Processor"
{
    TableNo = "Doc Staging Line";

    trigger OnRun()
    begin
        CreateDocumentFromGroup(Rec);
    end;

    procedure ProcessBatch(BatchId: Code[35])
    var
        StagingLine: Record "Doc Staging Line";
        GroupLine: Record "Doc Staging Line";
        DocGroupId: Code[35];
        PrevGroupId: Code[35];
        DocsCreated: Integer;
        DocsFailed: Integer;
        TotalGroups: Integer;
    begin
        StagingLine.SetRange("Batch ID", BatchId);
        StagingLine.SetRange(Status, StagingLine.Status::Pending);
        if not StagingLine.FindSet() then
            exit;

        PrevGroupId := '';
        repeat
            DocGroupId := StagingLine."Document Group ID";
            if DocGroupId <> PrevGroupId then begin
                PrevGroupId := DocGroupId;
                TotalGroups += 1;

                MarkGroupStatus(BatchId, DocGroupId,
                    StagingLine.Status::Processing, '', '');

                Commit();

                GroupLine.SetRange("Batch ID", BatchId);
                GroupLine.SetRange("Document Group ID", DocGroupId);
                GroupLine.SetRange(Status, GroupLine.Status::Processing);
                GroupLine.FindFirst();

                if Codeunit.Run(Codeunit::"Doc Staging Processor", GroupLine) then begin
                    DocsCreated += 1;
                end else begin
                    DocsFailed += 1;
                    HandleGroupError(BatchId, DocGroupId, GetLastErrorText());
                    Commit();
                end;
            end;
        until StagingLine.Next() = 0;

        Message('Batch %1 processed: %2 documents created, %3 failed (of %4 groups).',
            BatchId, DocsCreated, DocsFailed, TotalGroups);
    end;

    procedure ReprocessErrors(BatchId: Code[35])
    var
        StagingLine: Record "Doc Staging Line";
    begin
        StagingLine.SetRange("Batch ID", BatchId);
        StagingLine.SetRange(Status, StagingLine.Status::Error);
        StagingLine.SetFilter("Retry Count", '<%1', StagingLine."Max Retries");
        if not StagingLine.FindSet() then begin
            Message('No retryable errors found for batch %1.', BatchId);
            exit;
        end;

        StagingLine.ModifyAll(Status, StagingLine.Status::Pending);
        StagingLine.ModifyAll("Error Message", '');
        Commit();

        ProcessBatch(BatchId);
    end;

    procedure ReprocessAllErrors()
    var
        StagingLine: Record "Doc Staging Line";
        BatchId: Code[35];
        PrevBatch: Code[35];
    begin
        StagingLine.SetRange(Status, StagingLine.Status::Error);
        StagingLine.SetCurrentKey("Batch ID", "Document Group ID", Status);
        if not StagingLine.FindSet() then begin
            Message('No errors to reprocess.');
            exit;
        end;

        PrevBatch := '';
        repeat
            BatchId := StagingLine."Batch ID";
            if BatchId <> PrevBatch then begin
                PrevBatch := BatchId;
                ReprocessErrors(BatchId);
            end;
        until StagingLine.Next() = 0;
    end;

    procedure GetBatchStats(BatchId: Code[35]; var Pending: Integer; var Processing: Integer; var Completed: Integer; var Errored: Integer)
    var
        StagingLine: Record "Doc Staging Line";
    begin
        StagingLine.SetRange("Batch ID", BatchId);

        StagingLine.SetRange(Status, StagingLine.Status::Pending);
        Pending := StagingLine.Count();

        StagingLine.SetRange(Status, StagingLine.Status::Processing);
        Processing := StagingLine.Count();

        StagingLine.SetRange(Status, StagingLine.Status::Completed);
        Completed := StagingLine.Count();

        StagingLine.SetRange(Status, StagingLine.Status::Error);
        Errored := StagingLine.Count();
    end;

    procedure ClearBatch(BatchId: Code[35])
    var
        StagingLine: Record "Doc Staging Line";
    begin
        StagingLine.SetRange("Batch ID", BatchId);
        StagingLine.DeleteAll();
    end;

    // ──────────────────────────── Internal ────────────────────────────

    local procedure CreateDocumentFromGroup(var TriggerLine: Record "Doc Staging Line")
    begin
        case TriggerLine."Document Type" of
            TriggerLine."Document Type"::"Sales Order":
                CreateSalesOrderFromGroup(TriggerLine);
            TriggerLine."Document Type"::"Purchase Order":
                CreatePurchaseOrderFromGroup(TriggerLine);
        end;
    end;

    local procedure CreateSalesOrderFromGroup(var TriggerLine: Record "Doc Staging Line")
    var
        StagingLine: Record "Doc Staging Line";
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        LineNo: Integer;
    begin
        SalesHeader.Init();
        SalesHeader.Validate("Document Type", SalesHeader."Document Type"::Order);
        SalesHeader.Insert(true);

        SalesHeader.Validate("Sell-to Customer No.", TriggerLine."Customer No.");
        if TriggerLine."Order Date" <> 0D then
            SalesHeader.Validate("Order Date", TriggerLine."Order Date");
        if TriggerLine."Posting Date" <> 0D then
            SalesHeader.Validate("Posting Date", TriggerLine."Posting Date");
        if TriggerLine."External Document No." <> '' then
            SalesHeader.Validate("External Document No.", TriggerLine."External Document No.");
        SalesHeader.Modify(true);

        StagingLine.SetRange("Batch ID", TriggerLine."Batch ID");
        StagingLine.SetRange("Document Group ID", TriggerLine."Document Group ID");
        StagingLine.SetRange(Status, StagingLine.Status::Processing);
        if StagingLine.FindSet() then
            repeat
                LineNo += 10000;
                SalesLine.Init();
                SalesLine.Validate("Document Type", SalesHeader."Document Type");
                SalesLine.Validate("Document No.", SalesHeader."No.");
                SalesLine.Validate("Line No.", LineNo);
                SalesLine.Insert(true);

                MapLineType(SalesLine, StagingLine);

                if StagingLine."Item No." <> '' then
                    SalesLine.Validate("No.", StagingLine."Item No.");
                if StagingLine.Description <> '' then
                    SalesLine.Validate(Description, StagingLine.Description);
                if StagingLine.Quantity <> 0 then
                    SalesLine.Validate(Quantity, StagingLine.Quantity);
                if StagingLine."Unit Price" <> 0 then
                    SalesLine.Validate("Unit Price", StagingLine."Unit Price");
                if StagingLine."Location Code" <> '' then
                    SalesLine.Validate("Location Code", StagingLine."Location Code");

                SalesLine.Modify(true);
            until StagingLine.Next() = 0;

        MarkGroupStatus(
            TriggerLine."Batch ID",
            TriggerLine."Document Group ID",
            StagingLine.Status::Completed,
            SalesHeader."No.",
            '');
    end;

    local procedure CreatePurchaseOrderFromGroup(var TriggerLine: Record "Doc Staging Line")
    var
        StagingLine: Record "Doc Staging Line";
        PurchHeader: Record "Purchase Header";
        PurchLine: Record "Purchase Line";
        LineNo: Integer;
    begin
        PurchHeader.Init();
        PurchHeader.Validate("Document Type", PurchHeader."Document Type"::Order);
        PurchHeader.Insert(true);

        PurchHeader.Validate("Buy-from Vendor No.", TriggerLine."Vendor No.");
        if TriggerLine."Order Date" <> 0D then
            PurchHeader.Validate("Order Date", TriggerLine."Order Date");
        if TriggerLine."Posting Date" <> 0D then
            PurchHeader.Validate("Posting Date", TriggerLine."Posting Date");
        if TriggerLine."External Document No." <> '' then
            PurchHeader.Validate("Vendor Shipment No.", TriggerLine."External Document No.");
        PurchHeader.Modify(true);

        StagingLine.SetRange("Batch ID", TriggerLine."Batch ID");
        StagingLine.SetRange("Document Group ID", TriggerLine."Document Group ID");
        StagingLine.SetRange(Status, StagingLine.Status::Processing);
        if StagingLine.FindSet() then
            repeat
                LineNo += 10000;
                PurchLine.Init();
                PurchLine.Validate("Document Type", PurchHeader."Document Type");
                PurchLine.Validate("Document No.", PurchHeader."No.");
                PurchLine.Validate("Line No.", LineNo);
                PurchLine.Insert(true);

                MapPurchLineType(PurchLine, StagingLine);

                if StagingLine."Item No." <> '' then
                    PurchLine.Validate("No.", StagingLine."Item No.");
                if StagingLine.Description <> '' then
                    PurchLine.Validate(Description, StagingLine.Description);
                if StagingLine.Quantity <> 0 then
                    PurchLine.Validate(Quantity, StagingLine.Quantity);
                if StagingLine."Direct Unit Cost" <> 0 then
                    PurchLine.Validate("Direct Unit Cost", StagingLine."Direct Unit Cost");
                if StagingLine."Location Code" <> '' then
                    PurchLine.Validate("Location Code", StagingLine."Location Code");

                PurchLine.Modify(true);
            until StagingLine.Next() = 0;

        MarkGroupStatus(
            TriggerLine."Batch ID",
            TriggerLine."Document Group ID",
            StagingLine.Status::Completed,
            PurchHeader."No.",
            '');
    end;

    local procedure MapLineType(var SalesLine: Record "Sales Line"; var StagingLine: Record "Doc Staging Line")
    begin
        case StagingLine."Line Type" of
            StagingLine."Line Type"::Item:
                SalesLine.Validate(Type, SalesLine.Type::Item);
            StagingLine."Line Type"::"G/L Account":
                SalesLine.Validate(Type, SalesLine.Type::"G/L Account");
            StagingLine."Line Type"::Resource:
                SalesLine.Validate(Type, SalesLine.Type::Resource);
            StagingLine."Line Type"::"Fixed Asset":
                SalesLine.Validate(Type, SalesLine.Type::"Fixed Asset");
            StagingLine."Line Type"::"Charge (Item)":
                SalesLine.Validate(Type, SalesLine.Type::"Charge (Item)");
        end;
    end;

    local procedure MapPurchLineType(var PurchLine: Record "Purchase Line"; var StagingLine: Record "Doc Staging Line")
    begin
        case StagingLine."Line Type" of
            StagingLine."Line Type"::Item:
                PurchLine.Validate(Type, PurchLine.Type::Item);
            StagingLine."Line Type"::"G/L Account":
                PurchLine.Validate(Type, PurchLine.Type::"G/L Account");
            StagingLine."Line Type"::Resource:
                PurchLine.Validate(Type, PurchLine.Type::Resource);
            StagingLine."Line Type"::"Fixed Asset":
                PurchLine.Validate(Type, PurchLine.Type::"Fixed Asset");
            StagingLine."Line Type"::"Charge (Item)":
                PurchLine.Validate(Type, PurchLine.Type::"Charge (Item)");
        end;
    end;

    local procedure MarkGroupStatus(
        BatchId: Code[35];
        DocGroupId: Code[35];
        NewStatus: Option;
        CreatedDocNo: Code[20];
        ErrorMsg: Text)
    var
        StagingLine: Record "Doc Staging Line";
    begin
        StagingLine.SetRange("Batch ID", BatchId);
        StagingLine.SetRange("Document Group ID", DocGroupId);
        if (NewStatus = StagingLine.Status::Completed) or (NewStatus = StagingLine.Status::Error) then
            StagingLine.ModifyAll("Processed At", CurrentDateTime());
        StagingLine.ModifyAll(Status, NewStatus);
        if CreatedDocNo <> '' then
            StagingLine.ModifyAll("Created Doc No.", CreatedDocNo);
        if ErrorMsg <> '' then begin
            StagingLine.ModifyAll("Error Message", CopyStr(ErrorMsg, 1, 2048));
            if StagingLine.FindSet() then
                repeat
                    StagingLine."Retry Count" += 1;
                    StagingLine.Modify();
                until StagingLine.Next() = 0;
        end;
    end;

    local procedure HandleGroupError(
        BatchId: Code[35];
        DocGroupId: Code[35];
        ErrorText: Text)
    begin
        MarkGroupStatus(BatchId, DocGroupId, 3, '', ErrorText); // 3 = Error
    end;
}
