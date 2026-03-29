namespace DefaultPublisher.docloadtest;

using Microsoft.Sales.Document;
using Microsoft.Sales.Customer;

codeunit 50102 "Skip Credit Limit Check"
{
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Cust-Check Cr. Limit", 'OnBeforeSalesHeaderCheck', '', false, false)]
    local procedure SkipSalesDocCreditLimit(SalesHeader: Record "Sales Header"; var IsHandled: Boolean)
    begin
        IsHandled := true;
    end;
}
