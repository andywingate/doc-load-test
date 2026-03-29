namespace DefaultPublisher.docloadtest;

page 50118 "Doc Staging API"
{
    PageType = API;
    APIPublisher = 'defaultpublisher';
    APIGroup = 'docloadtest';
    APIVersion = 'v1.0';
    EntityName = 'docStagingLineLT';
    EntitySetName = 'docStagingLinesLT';
    SourceTable = "Doc Staging Line";
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
                field(entryNo; Rec."Entry No.")
                {
                    Caption = 'entryNo';
                    Editable = false;
                }
                field(batchId; Rec."Batch ID")
                {
                    Caption = 'batchId';
                }
                field(documentGroupId; Rec."Document Group ID")
                {
                    Caption = 'documentGroupId';
                }
                field(documentType; Rec."Document Type")
                {
                    Caption = 'documentType';
                }
                field(customerNumber; Rec."Customer No.")
                {
                    Caption = 'customerNumber';
                }
                field(vendorNumber; Rec."Vendor No.")
                {
                    Caption = 'vendorNumber';
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
                field(lineType; Rec."Line Type")
                {
                    Caption = 'lineType';
                }
                field(itemNumber; Rec."Item No.")
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
                field(directUnitCost; Rec."Direct Unit Cost")
                {
                    Caption = 'directUnitCost';
                }
                field(locationCode; Rec."Location Code")
                {
                    Caption = 'locationCode';
                }
                field(status; Rec.Status)
                {
                    Caption = 'status';
                    Editable = false;
                }
                field(errorMessage; Rec."Error Message")
                {
                    Caption = 'errorMessage';
                    Editable = false;
                }
                field(retryCount; Rec."Retry Count")
                {
                    Caption = 'retryCount';
                    Editable = false;
                }
                field(createdDocNumber; Rec."Created Doc No.")
                {
                    Caption = 'createdDocNumber';
                    Editable = false;
                }
                field(receivedAt; Rec."Received At")
                {
                    Caption = 'receivedAt';
                    Editable = false;
                }
                field(processedAt; Rec."Processed At")
                {
                    Caption = 'processedAt';
                    Editable = false;
                }
            }
        }
    }
}
