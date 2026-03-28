namespace DefaultPublisher.docloadtest;

page 50101 "Doc Load Test Results"
{
    Caption = 'Document Load Test Results';
    PageType = List;
    SourceTable = "Doc Load Test Result";
    ApplicationArea = All;
    UsageCategory = Lists;
    Editable = false;
    SourceTableView = sorting("Entry No.") order(descending);

    layout
    {
        area(content)
        {
            repeater(Results)
            {
                field("Entry No."; Rec."Entry No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Entry number.';
                }
                field("Test Type"; Rec."Test Type")
                {
                    ApplicationArea = All;
                    ToolTip = 'Type of test that was run.';
                }
                field(Success; Rec.Success)
                {
                    ApplicationArea = All;
                    ToolTip = 'Whether the test ran successfully.';
                    StyleExpr = SuccessStyle;
                }
                field("Start Date-Time"; Rec."Start Date-Time")
                {
                    ApplicationArea = All;
                    ToolTip = 'When the test started.';
                }
                field("End Date-Time"; Rec."End Date-Time")
                {
                    ApplicationArea = All;
                    ToolTip = 'When the test ended.';
                }
                field("Duration (ms)"; Rec."Duration (ms)")
                {
                    ApplicationArea = All;
                    ToolTip = 'Total duration in milliseconds.';
                }
                field("Documents Requested"; Rec."Documents Requested")
                {
                    ApplicationArea = All;
                    ToolTip = 'Number of documents requested.';
                }
                field("Documents Created"; Rec."Documents Created")
                {
                    ApplicationArea = All;
                    ToolTip = 'Number of documents successfully created.';
                }
                field("Lines Per Document"; Rec."Lines Per Document")
                {
                    ApplicationArea = All;
                    ToolTip = 'Lines per document.';
                }
                field("Total Lines Created"; Rec."Total Lines Created")
                {
                    ApplicationArea = All;
                    ToolTip = 'Total lines created across all documents.';
                }
                field("Documents Read"; Rec."Documents Read")
                {
                    ApplicationArea = All;
                    ToolTip = 'Number of documents read.';
                }
                field("Docs Per Second"; Rec."Docs Per Second")
                {
                    ApplicationArea = All;
                    ToolTip = 'Document throughput per second.';
                }
                field("Lines Per Second"; Rec."Lines Per Second")
                {
                    ApplicationArea = All;
                    ToolTip = 'Line throughput per second.';
                }
                field("Batch Size Used"; Rec."Batch Size Used")
                {
                    ApplicationArea = All;
                    ToolTip = 'Batch / commit interval used.';
                }
                field(Errors; Rec.Errors)
                {
                    ApplicationArea = All;
                    ToolTip = 'Number of errors during the test.';
                }
                field("Last Error Message"; Rec."Last Error Message")
                {
                    ApplicationArea = All;
                    ToolTip = 'Last error message encountered.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ClearResults)
            {
                Caption = 'Clear All Results';
                ApplicationArea = All;
                ToolTip = 'Delete all test results.';
                Image = Delete;
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                var
                    Results: Record "Doc Load Test Result";
                begin
                    if not Confirm('Delete all test results?') then
                        exit;
                    Results.DeleteAll();
                    CurrPage.Update(false);
                end;
            }
        }
    }

    var
        SuccessStyle: Text;

    trigger OnAfterGetRecord()
    begin
        if Rec.Success then
            SuccessStyle := 'Favorable'
        else
            SuccessStyle := 'Unfavorable';
    end;
}
