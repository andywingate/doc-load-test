namespace DefaultPublisher.docloadtest;

using Microsoft.Sales.Document;

codeunit 50103 "SO Staging Processor"
{
    TableNo = "SO Staging Line";

    trigger OnRun()
    begin
        // Entry point for Codeunit.Run() error isolation pattern.
        // Rec is set to a staging line whose Document Group ID identifies the SO to create.
        CreateSalesOrderFromGroup(Rec);
    end;

    /// <summary>
    /// Process all pending staging lines for a given Batch ID.
    /// Groups lines by Document Group ID and creates one SO per group.
    /// Uses Codeunit.Run() with result capture for error isolation between SOs.
    /// </summary>
    procedure ProcessBatch(BatchId: Code[35])
    var
        StagingLine: Record "SO Staging Line";
        GroupLine: Record "SO Staging Line";
        DocGroupId: Code[35];
        PrevGroupId: Code[35];
        SOsCreated: Integer;
        SOsFailed: Integer;
        TotalGroups: Integer;
    begin
        // Find distinct Document Group IDs with Pending lines in this batch
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

                // Mark group as Processing
                MarkGroupStatus(BatchId, DocGroupId,
                    StagingLine.Status::Processing, '', '');

                // Commit before Codeunit.Run — required for error isolation
                Commit();

                // Use first line as the record to pass to OnRun
                GroupLine.SetRange("Batch ID", BatchId);
                GroupLine.SetRange("Document Group ID", DocGroupId);
                GroupLine.SetRange(Status, GroupLine.Status::Processing);
                GroupLine.FindFirst();

                if Codeunit.Run(Codeunit::"SO Staging Processor", GroupLine) then begin
                    SOsCreated += 1;
                end else begin
                    SOsFailed += 1;
                    // Capture error — Codeunit.Run rolled back the SO creation,
                    // so we need to update staging rows with the error in a new transaction
                    HandleGroupError(BatchId, DocGroupId, GetLastErrorText());
                    Commit();
                end;
            end;
        until StagingLine.Next() = 0;

        Message('Batch %1 processed: %2 SOs created, %3 failed (of %4 groups).',
            BatchId, SOsCreated, SOsFailed, TotalGroups);
    end;

    /// <summary>
    /// Reprocess all staging lines that previously errored, up to their Max Retries limit.
    /// </summary>
    procedure ReprocessErrors(BatchId: Code[35])
    var
        StagingLine: Record "SO Staging Line";
    begin
        StagingLine.SetRange("Batch ID", BatchId);
        StagingLine.SetRange(Status, StagingLine.Status::Error);
        StagingLine.SetFilter("Retry Count", '<%1', StagingLine."Max Retries");
        if not StagingLine.FindSet() then begin
            Message('No retryable errors found for batch %1.', BatchId);
            exit;
        end;

        // Reset to Pending so ProcessBatch will pick them up
        StagingLine.ModifyAll(Status, StagingLine.Status::Pending);
        StagingLine.ModifyAll("Error Message", '');
        Commit();

        ProcessBatch(BatchId);
    end;

    /// <summary>
    /// Reprocess ALL error lines across all batches (up to retry limit).
    /// </summary>
    procedure ReprocessAllErrors()
    var
        StagingLine: Record "SO Staging Line";
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

    /// <summary>
    /// Get processing stats for a batch.
    /// </summary>
    procedure GetBatchStats(BatchId: Code[35]; var Pending: Integer; var Processing: Integer; var Completed: Integer; var Errored: Integer)
    var
        StagingLine: Record "SO Staging Line";
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

    // ──────────────────────────── Internal ────────────────────────────

    local procedure CreateSalesOrderFromGroup(var TriggerLine: Record "SO Staging Line")
    var
        StagingLine: Record "SO Staging Line";
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        LineNo: Integer;
    begin
        // Create Sales Header from the header fields on any line in the group
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

        // Create Sales Lines from all staging lines in this group
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

        // Success — mark all lines in the group as Completed with the SO No.
        MarkGroupStatus(
            TriggerLine."Batch ID",
            TriggerLine."Document Group ID",
            StagingLine.Status::Completed,
            SalesHeader."No.",
            ''
        );
    end;

    local procedure MarkGroupStatus(
        BatchId: Code[35];
        DocGroupId: Code[35];
        NewStatus: Option;
        CreatedSONo: Code[20];
        ErrorMsg: Text)
    var
        StagingLine: Record "SO Staging Line";
    begin
        StagingLine.SetRange("Batch ID", BatchId);
        StagingLine.SetRange("Document Group ID", DocGroupId);
        if (NewStatus = StagingLine.Status::Completed) or (NewStatus = StagingLine.Status::Error) then
            StagingLine.ModifyAll("Processed At", CurrentDateTime());
        StagingLine.ModifyAll(Status, NewStatus);
        if CreatedSONo <> '' then
            StagingLine.ModifyAll("Created SO No.", CreatedSONo);
        if ErrorMsg <> '' then begin
            StagingLine.ModifyAll("Error Message", CopyStr(ErrorMsg, 1, 2048));
            // Increment retry count on errors
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
