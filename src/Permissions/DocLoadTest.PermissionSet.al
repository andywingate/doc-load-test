namespace DefaultPublisher.docloadtest;

using System.Security.AccessControl;

permissionset 50100 "Doc Load Test"
{
    Assignable = true;
    Caption = 'Document Load Test';

    Permissions =
        table "Doc Load Test Setup" = X,
        tabledata "Doc Load Test Setup" = RMID,
        table "Doc Load Test Result" = X,
        tabledata "Doc Load Test Result" = RMID,
        codeunit "Doc Load Test Engine" = X,
        codeunit "Doc Load Test Data Gen" = X,
        page "Doc Load Test Setup" = X,
        page "Doc Load Test Results" = X,
        page "Sales Order Load Test API" = X,
        page "SO Lines Load Test API" = X,
        page "Purchase Order Load Test API" = X,
        page "PO Lines Load Test API" = X,
        page "SO Deep Insert API" = X,
        page "SO Lines Deep Insert API" = X,
        page "PO Deep Insert API" = X,
        page "PO Lines Deep Insert API" = X;
}
