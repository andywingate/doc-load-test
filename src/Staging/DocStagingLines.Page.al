namespace DefaultPublisher.docloadtest;

page 50102 "Doc Staging Lines"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = "Doc Staging Line";
    Caption = 'Document Staging Lines';
    Editable = false;
    InsertAllowed = false;
    DeleteAllowed = true;
    ModifyAllowed = false;

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field("Entry No."; Rec."Entry No.")
                {
                    ApplicationArea = All;
                }
                field("Batch ID"; Rec."Batch ID")
                {
                    ApplicationArea = All;
                }
                field("Document Group ID"; Rec."Document Group ID")
                {
                    ApplicationArea = All;
                }
                field("Document Type"; Rec."Document Type")
                {
                    ApplicationArea = All;
                }
                field(Status; Rec.Status)
                {
                    ApplicationArea = All;
                    StyleExpr = StatusStyle;
                }
                field("Customer No."; Rec."Customer No.")
                {
                    ApplicationArea = All;
                }
                field("Vendor No."; Rec."Vendor No.")
                {
                    ApplicationArea = All;
                }
                field("Item No."; Rec."Item No.")
                {
                    ApplicationArea = All;
                }
                field("Line Type"; Rec."Line Type")
                {
                    ApplicationArea = All;
                }
                field(Quantity; Rec.Quantity)
                {
                    ApplicationArea = All;
                }
                field("Unit Price"; Rec."Unit Price")
                {
                    ApplicationArea = All;
                }
                field("Direct Unit Cost"; Rec."Direct Unit Cost")
                {
                    ApplicationArea = All;
                }
                field("Created Doc No."; Rec."Created Doc No.")
                {
                    ApplicationArea = All;
                }
                field("Error Message"; Rec."Error Message")
                {
                    ApplicationArea = All;
                }
                field("Retry Count"; Rec."Retry Count")
                {
                    ApplicationArea = All;
                }
                field("Received At"; Rec."Received At")
                {
                    ApplicationArea = All;
                }
                field("Processed At"; Rec."Processed At")
                {
                    ApplicationArea = All;
                }
            }
        }
        area(factboxes)
        {
            systempart(Notes; Notes)
            {
                ApplicationArea = All;
            }
        }
    }

    actions
    {
        area(processing)
        {
            action(ProcessBatch)
            {
                ApplicationArea = All;
                Caption = 'Process Batch';
                ToolTip = 'Process all pending staging lines for the selected row''s batch.';
                Image = Process;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;

                trigger OnAction()
                var
                    Processor: Codeunit "Doc Staging Processor";
                begin
                    Rec.TestField("Batch ID");
                    Processor.ProcessBatch(Rec."Batch ID");
                    CurrPage.Update(false);
                end;
            }
            action(ReprocessErrors)
            {
                ApplicationArea = All;
                Caption = 'Reprocess Errors';
                ToolTip = 'Retry all failed staging lines for the selected row''s batch (up to max retries).';
                Image = Restore;
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                var
                    Processor: Codeunit "Doc Staging Processor";
                begin
                    Rec.TestField("Batch ID");
                    Processor.ReprocessErrors(Rec."Batch ID");
                    CurrPage.Update(false);
                end;
            }
            action(ReprocessAllErrors)
            {
                ApplicationArea = All;
                Caption = 'Reprocess All Errors';
                ToolTip = 'Retry all failed staging lines across all batches.';
                Image = ResetStatus;
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                var
                    Processor: Codeunit "Doc Staging Processor";
                begin
                    if not Confirm('Reprocess all errors across all batches?') then
                        exit;
                    Processor.ReprocessAllErrors();
                    CurrPage.Update(false);
                end;
            }
            action(ClearBatch)
            {
                ApplicationArea = All;
                Caption = 'Clear Batch';
                ToolTip = 'Delete all staging lines for the selected row''s batch.';
                Image = Delete;
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                var
                    Processor: Codeunit "Doc Staging Processor";
                begin
                    Rec.TestField("Batch ID");
                    if not Confirm('Delete all staging lines for batch %1?', false, Rec."Batch ID") then
                        exit;
                    Processor.ClearBatch(Rec."Batch ID");
                    CurrPage.Update(false);
                end;
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        case Rec.Status of
            Rec.Status::Pending:
                StatusStyle := 'Subordinate';
            Rec.Status::Processing:
                StatusStyle := 'Attention';
            Rec.Status::Completed:
                StatusStyle := 'Favorable';
            Rec.Status::Error:
                StatusStyle := 'Unfavorable';
        end;
    end;

    var
        StatusStyle: Text;
}
