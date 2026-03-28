namespace DefaultPublisher.docloadtest;

using Microsoft.Sales.Document;

/// <summary>
/// Deep-insert API page for Sales Orders.
/// Supports creating header + lines in a single POST request.
///
/// POST /api/defaultpublisher/docloadtest/v1.0/companies({id})/salesOrdersDI
/// Body: { "customerNumber": "C00010", "salesOrderLinesDI": [ { "lineType": "Item", "itemNumber": "1000", "quantity": 1 } ] }
/// </summary>
page 50114 "SO Deep Insert API"
{
    PageType = API;
    APIPublisher = 'defaultpublisher';
    APIGroup = 'docloadtest';
    APIVersion = 'v1.0';
    EntityName = 'salesOrderDI';
    EntitySetName = 'salesOrdersDI';
    SourceTable = "Sales Header";
    SourceTableView = where("Document Type" = const(Order));
    DelayedInsert = true;
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
                field(number; Rec."No.")
                {
                    Caption = 'number';
                    Editable = false;
                }
                field(customerNumber; Rec."Sell-to Customer No.")
                {
                    Caption = 'customerNumber';
                }
                field(customerName; Rec."Sell-to Customer Name")
                {
                    Caption = 'customerName';
                    Editable = false;
                }
                field(orderDate; Rec."Order Date")
                {
                    Caption = 'orderDate';
                }
                field(postingDate; Rec."Posting Date")
                {
                    Caption = 'postingDate';
                }
                field(externalDocumentNumber; Rec."External Document No.")
                {
                    Caption = 'externalDocumentNumber';
                }
                field(status; Rec.Status)
                {
                    Caption = 'status';
                    Editable = false;
                }
                field(lastModifiedDateTime; Rec.SystemModifiedAt)
                {
                    Caption = 'lastModifiedDateTime';
                    Editable = false;
                }
            }
            part(salesOrderLinesDI; "SO Lines Deep Insert API")
            {
                EntityName = 'salesOrderLineDI';
                EntitySetName = 'salesOrderLinesDI';
                SubPageLink = "Document Type" = const(Order), "Document No." = field("No.");
            }
        }
    }

    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    begin
        Rec.Validate("Document Type", Rec."Document Type"::Order);
    end;
}
