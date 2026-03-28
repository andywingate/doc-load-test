namespace DefaultPublisher.docloadtest;

enum 50100 "Doc Load Test Type"
{
    Caption = 'Document Load Test Type';
    Extensible = false;

    value(0; "Create Sales Orders")
    {
        Caption = 'Create Sales Orders';
    }
    value(1; "Create Purchase Orders")
    {
        Caption = 'Create Purchase Orders';
    }
    value(2; "Read Sales Orders")
    {
        Caption = 'Read Sales Orders';
    }
    value(3; "Read Purchase Orders")
    {
        Caption = 'Read Purchase Orders';
    }
}
