namespace DefaultPublisher.docloadtest;

table 50102 "Doc Staging Line"
{
    Caption = 'Doc Staging Line';
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            AutoIncrement = true;
        }
        field(10; "Batch ID"; Code[35])
        {
            Caption = 'Batch ID';
        }
        field(11; "Document Group ID"; Code[35])
        {
            Caption = 'Document Group ID';
        }
        field(12; "Document Type"; Option)
        {
            Caption = 'Document Type';
            OptionCaption = 'Sales Order,Purchase Order';
            OptionMembers = "Sales Order","Purchase Order";
        }
        field(20; "Customer No."; Code[20])
        {
            Caption = 'Customer No.';
        }
        field(21; "Vendor No."; Code[20])
        {
            Caption = 'Vendor No.';
        }
        field(22; "Order Date"; Date)
        {
            Caption = 'Order Date';
        }
        field(23; "Posting Date"; Date)
        {
            Caption = 'Posting Date';
        }
        field(24; "External Document No."; Code[35])
        {
            Caption = 'External Document No.';
        }
        field(30; "Line Type"; Option)
        {
            Caption = 'Line Type';
            OptionCaption = ' ,G/L Account,Item,Resource,Fixed Asset,Charge (Item)';
            OptionMembers = " ","G/L Account",Item,Resource,"Fixed Asset","Charge (Item)";
        }
        field(31; "Item No."; Code[20])
        {
            Caption = 'Item No.';
        }
        field(32; "Description"; Text[100])
        {
            Caption = 'Description';
        }
        field(33; "Quantity"; Decimal)
        {
            Caption = 'Quantity';
            DecimalPlaces = 0 : 5;
        }
        field(34; "Unit Price"; Decimal)
        {
            Caption = 'Unit Price';
            DecimalPlaces = 2 : 5;
        }
        field(35; "Direct Unit Cost"; Decimal)
        {
            Caption = 'Direct Unit Cost';
            DecimalPlaces = 2 : 5;
        }
        field(40; "Location Code"; Code[10])
        {
            Caption = 'Location Code';
        }
        field(50; "Status"; Option)
        {
            Caption = 'Status';
            OptionCaption = 'Pending,Processing,Completed,Error';
            OptionMembers = Pending,Processing,Completed,Error;
            InitValue = Pending;
        }
        field(51; "Error Message"; Text[2048])
        {
            Caption = 'Error Message';
        }
        field(52; "Retry Count"; Integer)
        {
            Caption = 'Retry Count';
            InitValue = 0;
        }
        field(53; "Max Retries"; Integer)
        {
            Caption = 'Max Retries';
            InitValue = 3;
        }
        field(60; "Created Doc No."; Code[20])
        {
            Caption = 'Created Doc No.';
        }
        field(70; "Received At"; DateTime)
        {
            Caption = 'Received At';
        }
        field(71; "Processed At"; DateTime)
        {
            Caption = 'Processed At';
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(BatchGroup; "Batch ID", "Document Group ID", "Status")
        {
        }
        key(StatusRetry; "Status", "Retry Count")
        {
        }
    }

    trigger OnInsert()
    begin
        Rec."Received At" := CurrentDateTime();
    end;
}
