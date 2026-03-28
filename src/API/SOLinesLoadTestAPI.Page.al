namespace DefaultPublisher.docloadtest;

using Microsoft.Sales.Document;

page 50112 "SO Lines Load Test API"
{
    PageType = API;
    APIPublisher = 'defaultpublisher';
    APIGroup = 'docloadtest';
    APIVersion = 'v1.0';
    EntityName = 'salesOrderLineLT';
    EntitySetName = 'salesOrderLinesLT';
    SourceTable = "Sales Line";
    SourceTableView = where("Document Type" = const(Order));
    DelayedInsert = true;
    AutoSplitKey = true;
    ODataKeyFields = SystemId;
    Extensible = false;

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field(id; Rec.SystemId)
                {
                    Caption = 'id';
                    Editable = false;
                }
                field(documentNo; Rec."Document No.")
                {
                    Caption = 'documentNo';
                    Editable = false;
                }
                field(lineNo; Rec."Line No.")
                {
                    Caption = 'lineNo';
                    Editable = false;
                }
                field(lineType; Rec.Type)
                {
                    Caption = 'lineType';
                }
                field(itemNumber; Rec."No.")
                {
                    Caption = 'itemNumber';
                }
                field(description; Rec.Description)
                {
                    Caption = 'description';
                }
                field(quantity; Rec.Quantity)
                {
                    Caption = 'quantity';
                }
                field(unitPrice; Rec."Unit Price")
                {
                    Caption = 'unitPrice';
                }
                field(amount; Rec."Line Amount")
                {
                    Caption = 'amount';
                    Editable = false;
                }
            }
        }
    }

    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    begin
        Rec.Validate("Document Type", Rec."Document Type"::Order);
    end;
}
