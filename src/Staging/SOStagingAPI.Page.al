namespace DefaultPublisher.docloadtest;

page 50118 "SO Staging API"
{
    PageType = API;
    APIPublisher = 'defaultpublisher';
    APIGroup = 'docloadtest';
    APIVersion = 'v1.0';
    EntityName = 'soStagingLineLT';
    EntitySetName = 'soStagingLinesLT';
    SourceTable = "SO Staging Line";
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
                field(customerNumber; Rec."Customer No.")
                {
                    Caption = 'customerNumber';
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
                field(createdSONumber; Rec."Created SO No.")
                {
                    Caption = 'createdSONumber';
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
