namespace DefaultPublisher.docloadtest;

using Microsoft.Purchases.Document;

/// <summary>
/// Deep-insert API page for Purchase Orders.
/// Supports creating header + lines in a single POST request.
///
/// POST /api/defaultpublisher/docloadtest/v1.0/companies({id})/purchaseOrdersDI
/// Body: { "vendorNumber": "V00010", "purchaseOrderLinesDI": [ { "lineType": "Item", "itemNumber": "1000", "quantity": 1 } ] }
/// </summary>
page 50116 "PO Deep Insert API"
{
    PageType = API;
    APIPublisher = 'defaultpublisher';
    APIGroup = 'docloadtest';
    APIVersion = 'v1.0';
    EntityName = 'purchaseOrderDI';
    EntitySetName = 'purchaseOrdersDI';
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
            part(purchaseOrderLinesDI; "PO Lines Deep Insert API")
            {
                EntityName = 'purchaseOrderLineDI';
                EntitySetName = 'purchaseOrderLinesDI';
                SubPageLink = "Document Type" = const(Order), "Document No." = field("No.");
            }
        }
    }

    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    begin
        Rec.Validate("Document Type", Rec."Document Type"::Order);
    end;
}
