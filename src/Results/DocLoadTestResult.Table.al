namespace DefaultPublisher.docloadtest;

table 50101 "Doc Load Test Result"
{
    Caption = 'Document Load Test Result';
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            AutoIncrement = true;
        }
        field(10; "Test Type"; Enum "Doc Load Test Type")
        {
            Caption = 'Test Type';
        }
        field(20; "Start Date-Time"; DateTime)
        {
            Caption = 'Start Date-Time';
        }
        field(21; "End Date-Time"; DateTime)
        {
            Caption = 'End Date-Time';
        }
        field(22; "Duration (ms)"; BigInteger)
        {
            Caption = 'Duration (ms)';
        }
        field(30; "Documents Requested"; Integer)
        {
            Caption = 'Documents Requested';
        }
        field(31; "Documents Created"; Integer)
        {
            Caption = 'Documents Created';
        }
        field(32; "Lines Per Document"; Integer)
        {
            Caption = 'Lines Per Document';
        }
        field(33; "Total Lines Created"; Integer)
        {
            Caption = 'Total Lines Created';
        }
        field(40; "Documents Read"; Integer)
        {
            Caption = 'Documents Read';
        }
        field(50; "Errors"; Integer)
        {
            Caption = 'Errors';
        }
        field(51; "Last Error Message"; Text[2048])
        {
            Caption = 'Last Error Message';
        }
        field(60; "Docs Per Second"; Decimal)
        {
            Caption = 'Documents Per Second';
            DecimalPlaces = 2 : 2;
        }
        field(61; "Lines Per Second"; Decimal)
        {
            Caption = 'Lines Per Second';
            DecimalPlaces = 2 : 2;
        }
        field(70; "Batch Size Used"; Integer)
        {
            Caption = 'Batch Size Used';
        }
        field(80; "Success"; Boolean)
        {
            Caption = 'Success';
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(TestType; "Test Type", "Start Date-Time")
        {
        }
    }
}
