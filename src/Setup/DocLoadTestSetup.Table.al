namespace DefaultPublisher.docloadtest;

using Microsoft.Sales.Customer;
using Microsoft.Purchases.Vendor;
using Microsoft.Inventory.Item;

table 50100 "Doc Load Test Setup"
{
    Caption = 'Document Load Test Setup';
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
        }
        field(10; "No. of Sales Orders"; Integer)
        {
            Caption = 'No. of Sales Orders';
            MinValue = 0;
            MaxValue = 100000;
            InitValue = 100;
        }
        field(11; "SO Lines Per Document"; Integer)
        {
            Caption = 'Lines Per Sales Order';
            MinValue = 1;
            MaxValue = 1000;
            InitValue = 5;
        }
        field(20; "No. of Purchase Orders"; Integer)
        {
            Caption = 'No. of Purchase Orders';
            MinValue = 0;
            MaxValue = 100000;
            InitValue = 100;
        }
        field(21; "PO Lines Per Document"; Integer)
        {
            Caption = 'Lines Per Purchase Order';
            MinValue = 1;
            MaxValue = 1000;
            InitValue = 5;
        }
        field(30; "Customer No."; Code[20])
        {
            Caption = 'Customer No.';
            TableRelation = Customer;
        }
        field(31; "Vendor No."; Code[20])
        {
            Caption = 'Vendor No.';
            TableRelation = Vendor;
        }
        field(32; "Item No."; Code[20])
        {
            Caption = 'Item No.';
            TableRelation = Item;
        }
        field(40; "Batch Size"; Integer)
        {
            Caption = 'Batch Size (Commit Interval)';
            MinValue = 1;
            MaxValue = 10000;
            InitValue = 50;
        }
        field(50; "Auto-Generate Test Data"; Boolean)
        {
            Caption = 'Auto-Generate Test Data';
            InitValue = true;
        }
        field(60; "Last Run Date-Time"; DateTime)
        {
            Caption = 'Last Run Date-Time';
            Editable = false;
        }
        field(70; "API Page Size"; Integer)
        {
            Caption = 'API Read Page Size';
            MinValue = 10;
            MaxValue = 10000;
            InitValue = 100;
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }

    procedure GetSetup()
    begin
        if not Get() then begin
            Init();
            Insert();
        end;
    end;
}
