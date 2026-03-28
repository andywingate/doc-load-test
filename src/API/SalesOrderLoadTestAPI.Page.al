namespace DefaultPublisher.docloadtest;

using Microsoft.Sales.Document;

/// <summary>
/// Custom API page mirroring the standard salesOrders API but exposing
/// External Document No. as a batch ID field for load test filtering.
///
/// POST /api/defaultpublisher/docloadtest/v1.0/companies({id})/salesOrdersLT
/// </summary>
page 50110 "Sales Order Load Test API"
{
    PageType = API;
    APIPublisher = 'defaultpublisher';
    APIGroup = 'docloadtest';
    APIVersion = 'v1.0';
    EntityName = 'salesOrderLT';
    EntitySetName = 'salesOrdersLT';
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
            part(salesOrderLines; "SO Lines Load Test API")
            {
                EntityName = 'salesOrderLineLT';
                EntitySetName = 'salesOrderLinesLT';
                SubPageLink = "Document Type" = const(Order), "Document No." = field("No.");
            }
        }
    }

    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    begin
        Rec.Validate("Document Type", Rec."Document Type"::Order);
    end;
}
