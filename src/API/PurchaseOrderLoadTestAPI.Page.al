namespace DefaultPublisher.docloadtest;

using Microsoft.Purchases.Document;

/// <summary>
/// Custom API page mirroring the standard purchaseOrders API but exposing
/// Vendor Shipment No. as a batch ID field for load test filtering.
///
/// POST /api/defaultpublisher/docloadtest/v1.0/companies({id})/purchaseOrdersLT
/// </summary>
page 50111 "Purchase Order Load Test API"
{
    PageType = API;
    APIPublisher = 'defaultpublisher';
    APIGroup = 'docloadtest';
    APIVersion = 'v1.0';
    EntityName = 'purchaseOrderLT';
    EntitySetName = 'purchaseOrdersLT';
    SourceTable = "Purchase Header";
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
                field(vendorNumber; Rec."Buy-from Vendor No.")
                {
                    Caption = 'vendorNumber';
                }
                field(vendorName; Rec."Buy-from Vendor Name")
                {
                    Caption = 'vendorName';
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
                field(vendorShipmentNo; Rec."Vendor Shipment No.")
                {
                    Caption = 'vendorShipmentNo';
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
            part(purchaseOrderLines; "PO Lines Load Test API")
            {
                EntityName = 'purchaseOrderLineLT';
                EntitySetName = 'purchaseOrderLinesLT';
                SubPageLink = "Document Type" = const(Order), "Document No." = field("No.");
            }
        }
    }

    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    begin
        Rec.Validate("Document Type", Rec."Document Type"::Order);
    end;
}
