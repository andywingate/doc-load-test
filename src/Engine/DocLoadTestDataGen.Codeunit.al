namespace DefaultPublisher.docloadtest;

using Microsoft.Sales.Customer;
using Microsoft.Purchases.Vendor;
using Microsoft.Inventory.Item;
using Microsoft.Foundation.NoSeries;
using Microsoft.Finance.GeneralLedger.Setup;
using Microsoft.Finance.VAT.Setup;
using Microsoft.Inventory.Setup;

codeunit 50101 "Doc Load Test Data Gen"
{
    procedure EnsureTestCustomer(var Setup: Record "Doc Load Test Setup"): Code[20]
    var
        Customer: Record Customer;
    begin
        if Setup."Customer No." <> '' then begin
            Customer.Get(Setup."Customer No.");
            exit(Customer."No.");
        end;

        if not Setup."Auto-Generate Test Data" then
            Error('Customer No. is required when Auto-Generate Test Data is off.');

        Customer.SetRange(Name, 'LOAD-TEST-CUSTOMER');
        if Customer.FindFirst() then
            exit(Customer."No.");

        Customer.Init();
        Customer.Insert(true);
        Customer.Validate(Name, 'LOAD-TEST-CUSTOMER');
        Customer.Validate("Gen. Bus. Posting Group", GetFirstGenBusPostingGroup());
        Customer.Validate("Customer Posting Group", GetFirstCustPostingGroup());
        Customer.Validate("VAT Bus. Posting Group", GetFirstVATBusPostingGroup());
        Customer.Modify(true);
        exit(Customer."No.");
    end;

    procedure EnsureTestVendor(var Setup: Record "Doc Load Test Setup"): Code[20]
    var
        Vendor: Record Vendor;
    begin
        if Setup."Vendor No." <> '' then begin
            Vendor.Get(Setup."Vendor No.");
            exit(Vendor."No.");
        end;

        if not Setup."Auto-Generate Test Data" then
            Error('Vendor No. is required when Auto-Generate Test Data is off.');

        Vendor.SetRange(Name, 'LOAD-TEST-VENDOR');
        if Vendor.FindFirst() then
            exit(Vendor."No.");

        Vendor.Init();
        Vendor.Insert(true);
        Vendor.Validate(Name, 'LOAD-TEST-VENDOR');
        Vendor.Validate("Gen. Bus. Posting Group", GetFirstGenBusPostingGroup());
        Vendor.Validate("Vendor Posting Group", GetFirstVendPostingGroup());
        Vendor.Validate("VAT Bus. Posting Group", GetFirstVATBusPostingGroup());
        Vendor.Modify(true);
        exit(Vendor."No.");
    end;

    procedure EnsureTestItem(var Setup: Record "Doc Load Test Setup"): Code[20]
    var
        Item: Record Item;
    begin
        if Setup."Item No." <> '' then begin
            Item.Get(Setup."Item No.");
            exit(Item."No.");
        end;

        if not Setup."Auto-Generate Test Data" then
            Error('Item No. is required when Auto-Generate Test Data is off.');

        Item.SetRange(Description, 'LOAD-TEST-ITEM');
        if Item.FindFirst() then
            exit(Item."No.");

        Item.Init();
        Item.Insert(true);
        Item.Validate(Description, 'LOAD-TEST-ITEM');
        Item.Validate(Type, Item.Type::Inventory);
        Item.Validate("Gen. Prod. Posting Group", GetFirstGenProdPostingGroup());
        Item.Validate("VAT Prod. Posting Group", GetFirstVATProdPostingGroup());
        Item.Validate("Inventory Posting Group", GetFirstInvPostingGroup());
        Item.Validate("Unit Price", 10.00);
        Item.Validate("Unit Cost", 5.00);
        Item.Modify(true);
        exit(Item."No.");
    end;

    local procedure GetFirstGenBusPostingGroup(): Code[20]
    var
        GenBusPostGrp: Record "Gen. Business Posting Group";
    begin
        GenBusPostGrp.FindFirst();
        exit(GenBusPostGrp.Code);
    end;

    local procedure GetFirstGenProdPostingGroup(): Code[20]
    var
        GenProdPostGrp: Record "Gen. Product Posting Group";
    begin
        GenProdPostGrp.FindFirst();
        exit(GenProdPostGrp.Code);
    end;

    local procedure GetFirstCustPostingGroup(): Code[20]
    var
        CustPostGrp: Record "Customer Posting Group";
    begin
        CustPostGrp.FindFirst();
        exit(CustPostGrp.Code);
    end;

    local procedure GetFirstVendPostingGroup(): Code[20]
    var
        VendPostGrp: Record "Vendor Posting Group";
    begin
        VendPostGrp.FindFirst();
        exit(VendPostGrp.Code);
    end;

    local procedure GetFirstVATBusPostingGroup(): Code[20]
    var
        VATBusPostGrp: Record "VAT Business Posting Group";
    begin
        VATBusPostGrp.FindFirst();
        exit(VATBusPostGrp.Code);
    end;

    local procedure GetFirstVATProdPostingGroup(): Code[20]
    var
        VATProdPostGrp: Record "VAT Product Posting Group";
    begin
        VATProdPostGrp.FindFirst();
        exit(VATProdPostGrp.Code);
    end;

    local procedure GetFirstInvPostingGroup(): Code[20]
    var
        InvPostGrp: Record "Inventory Posting Group";
    begin
        InvPostGrp.FindFirst();
        exit(InvPostGrp.Code);
    end;
}
