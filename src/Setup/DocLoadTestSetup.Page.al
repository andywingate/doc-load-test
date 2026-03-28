namespace DefaultPublisher.docloadtest;

using Microsoft.Sales.Document;
using Microsoft.Purchases.Document;

page 50100 "Doc Load Test Setup"
{
    Caption = 'Document Load Test Setup';
    PageType = Card;
    SourceTable = "Doc Load Test Setup";
    ApplicationArea = All;
    UsageCategory = Administration;
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(content)
        {
            group(SalesOrders)
            {
                Caption = 'Sales Order Generation';

                field("No. of Sales Orders"; Rec."No. of Sales Orders")
                {
                    ApplicationArea = All;
                    ToolTip = 'Number of Sales Orders to create.';
                }
                field("SO Lines Per Document"; Rec."SO Lines Per Document")
                {
                    ApplicationArea = All;
                    ToolTip = 'Number of lines per Sales Order.';
                }
                field("Customer No."; Rec."Customer No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Customer to use. Leave blank to auto-generate.';
                }
            }
            group(PurchaseOrders)
            {
                Caption = 'Purchase Order Generation';

                field("No. of Purchase Orders"; Rec."No. of Purchase Orders")
                {
                    ApplicationArea = All;
                    ToolTip = 'Number of Purchase Orders to create.';
                }
                field("PO Lines Per Document"; Rec."PO Lines Per Document")
                {
                    ApplicationArea = All;
                    ToolTip = 'Number of lines per Purchase Order.';
                }
                field("Vendor No."; Rec."Vendor No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Vendor to use. Leave blank to auto-generate.';
                }
            }
            group(General)
            {
                Caption = 'General Settings';

                field("Item No."; Rec."Item No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Item to use on lines. Leave blank to auto-generate.';
                }
                field("Batch Size"; Rec."Batch Size")
                {
                    ApplicationArea = All;
                    ToolTip = 'Number of documents to create before committing. Larger batches = faster but uses more memory.';
                }
                field("Auto-Generate Test Data"; Rec."Auto-Generate Test Data")
                {
                    ApplicationArea = All;
                    ToolTip = 'Automatically generate a test customer, vendor, and item if not specified.';
                }
                field("API Page Size"; Rec."API Page Size")
                {
                    ApplicationArea = All;
                    ToolTip = 'Page size for API read stress tests.';
                }
            }
            group(Status)
            {
                Caption = 'Status';

                field("Last Run Date-Time"; Rec."Last Run Date-Time")
                {
                    ApplicationArea = All;
                    ToolTip = 'Date and time of the last test run.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(RunCreateSO)
            {
                Caption = 'Create Sales Orders';
                ApplicationArea = All;
                ToolTip = 'Generate bulk Sales Orders for stress testing.';
                Image = Sales;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;

                trigger OnAction()
                var
                    Engine: Codeunit "Doc Load Test Engine";
                begin
                    Rec.GetSetup();
                    Engine.RunSalesOrderTest(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(RunCreatePO)
            {
                Caption = 'Create Purchase Orders';
                ApplicationArea = All;
                ToolTip = 'Generate bulk Purchase Orders for stress testing.';
                Image = Purchase;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;

                trigger OnAction()
                var
                    Engine: Codeunit "Doc Load Test Engine";
                begin
                    Rec.GetSetup();
                    Engine.RunPurchaseOrderTest(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(RunCreateBoth)
            {
                Caption = 'Create SO + PO';
                ApplicationArea = All;
                ToolTip = 'Generate both Sales Orders and Purchase Orders.';
                Image = Start;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;

                trigger OnAction()
                var
                    Engine: Codeunit "Doc Load Test Engine";
                begin
                    Rec.GetSetup();
                    Engine.RunSalesOrderTest(Rec);
                    Engine.RunPurchaseOrderTest(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(RunReadSO)
            {
                Caption = 'Read All Sales Orders';
                ApplicationArea = All;
                ToolTip = 'Stress test reading all Sales Orders.';
                Image = ViewDetails;
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                var
                    Engine: Codeunit "Doc Load Test Engine";
                begin
                    Rec.GetSetup();
                    Engine.RunReadSalesOrders();
                    CurrPage.Update(false);
                end;
            }
            action(RunReadPO)
            {
                Caption = 'Read All Purchase Orders';
                ApplicationArea = All;
                ToolTip = 'Stress test reading all Purchase Orders.';
                Image = ViewDetails;
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                var
                    Engine: Codeunit "Doc Load Test Engine";
                begin
                    Rec.GetSetup();
                    Engine.RunReadPurchaseOrders();
                    CurrPage.Update(false);
                end;
            }
            action(CleanupTestData)
            {
                Caption = 'Cleanup Test Documents';
                ApplicationArea = All;
                ToolTip = 'Delete all documents created by this test tool.';
                Image = Delete;
                Promoted = true;
                PromotedCategory = Process;

                trigger OnAction()
                var
                    Engine: Codeunit "Doc Load Test Engine";
                begin
                    if not Confirm('This will delete all Sales Orders and Purchase Orders created by the stress test. Continue?') then
                        exit;
                    Engine.CleanupTestDocuments();
                    Message('Cleanup complete.');
                end;
            }
            action(ViewResults)
            {
                Caption = 'View Results';
                ApplicationArea = All;
                ToolTip = 'View all stress test run results.';
                Image = Log;
                Promoted = true;
                PromotedCategory = Report;
                RunObject = page "Doc Load Test Results";
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.GetSetup();
    end;
}
