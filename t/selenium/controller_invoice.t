use warnings;
use strict;

use lib 't/lib';
use Test::More import => [qw(done_testing is ok diag todo_skip)];
use Selenium::Remote::Driver::FirefoxExtensions;
use Selenium::Collection::Common;
use Selenium::Collection::Functions;

sub ctr_invoice {
    my ($port) = @_;
    my $d = Selenium::Collection::Functions::create_driver($port);
    my $c = Selenium::Collection::Common->new(
        driver => $d
    );

    my $resellername = ("reseller" . int(rand(100000)) . "test");
    my $contractid = ("contract" . int(rand(100000)) . "test");
    my $templatename = ("invoice" . int(rand(100000)) . "tem");
    my $contactmail = ("contact" . int(rand(100000)) . '@test.org');
    my $billingname = ("billing" . int(rand(100000)) . "test");
    my $customerid = ("id" . int(rand(100000)) . "ok");

    
    $c->login_ok();
    $c->create_reseller_contract($contractid);
    $c->create_reseller($resellername, $contractid);
    $c->create_contact($contactmail, $resellername);
    $c->create_billing_profile($billingname, $resellername);
    $c->create_customer($customerid, $contactmail, $billingname);
    
    diag("Search for Customer");
    $d->fill_element('#Customer_table_filter input', 'css', 'thisshouldnotexist');
    ok($d->find_element_by_css('#Customer_table tr > td.dataTables_empty', 'css'), 'Garbage test not found');
    $d->fill_element('#Customer_table_filter input', 'css', $customerid);
    ok($d->wait_for_text('//*[@id="Customer_table"]/tbody/tr[1]/td[2]', $customerid), 'Customer found');
    my $customernumber = $d->find_element('//*[@id="Customer_table"]/tbody/tr/td[1]')->get_text();

    diag('Go to Invoice Templates page');
    $d->find_element('//*[@id="main-nav"]//*[contains(text(),"Settings")]')->click();
    $d->find_element("Invoice Templates", 'link_text')->click();

    diag("Trying to create a new Invoice Template");
    $d->find_element("Create Invoice Template", 'link_text')->click();
    $d->fill_element('//*[@id="reselleridtable_filter"]/label/input', 'xpath', 'thisshouldnotexist');
    ok($d->find_element_by_css('#reselleridtable tr > td.dataTables_empty', 'css'), 'Garbage text was not found');
    $d->fill_element('//*[@id="reselleridtable_filter"]/label/input', 'xpath', $resellername);
    ok($d->wait_for_text('//*[@id="reselleridtable"]/tbody/tr[1]/td[2]', $resellername), "Reseller found");
    $d->select_if_unselected('//*[@id="reselleridtable"]/tbody/tr[1]/td[5]/input', 'xpath');
    $d->fill_element('//*[@id="name"]', 'xpath', $templatename);
    $d->find_element('//*[@id="save"]')->click();

    diag("Search for Template");
    $d->fill_element('//*[@id="InvoiceTemplate_table_filter"]/label/input', 'xpath', 'thisshouldnotexist');
    ok($d->find_element_by_css('#InvoiceTemplate_table tr > td.dataTables_empty', 'css'), 'Garbage text was not found');
    $d->fill_element('//*[@id="InvoiceTemplate_table_filter"]/label/input', 'xpath', $templatename);

    diag("Check details");
    ok($d->wait_for_text('//*[@id="InvoiceTemplate_table"]/tbody/tr/td[2]', $resellername), 'Reseller is correct');
    ok($d->wait_for_text('//*[@id="InvoiceTemplate_table"]/tbody/tr/td[3]', $templatename), 'Name is correct');
    ok($d->wait_for_text('//*[@id="InvoiceTemplate_table"]/tbody/tr/td[4]', 'svg'), 'Type is correct');

    diag('Go to Invoices page');
    $d->find_element('//*[@id="main-nav"]//*[contains(text(),"Settings")]')->click();
    $d->find_element("Invoices", 'link_text')->click();

    diag("Trying to create a new Invoice");
    $d->find_element("Create Invoice", 'link_text')->click();
    $d->fill_element('//*[@id="templateidtable_filter"]/label/input', 'xpath', 'thisshouldnotexist');
    ok($d->find_element_by_css('#templateidtable tr > td.dataTables_empty', 'css'), 'Garbage text was not found');
    $d->fill_element('//*[@id="templateidtable_filter"]/label/input', 'xpath', $templatename);
    ok($d->wait_for_text('//*[@id="templateidtable"]/tbody/tr[1]/td[3]', $templatename), 'Template was found');
    $d->select_if_unselected('//*[@id="templateidtable"]/tbody/tr[1]/td[4]/input');
    $d->scroll_to_element($d->find_element('//*[@id="contractidtable_filter"]/label/input'));
    $d->fill_element('#contractidtable_filter input', 'css', 'thisshouldnotexist');
    ok($d->find_element_by_css('#contractidtable tr > td.dataTables_empty', 'css'), 'Garbage test not found');
    $d->fill_element('#contractidtable_filter input', 'css', $customerid);
    ok($d->wait_for_text('//*[@id="contractidtable"]/tbody/tr[1]/td[4]', $customerid), 'Customer found');
    $d->select_if_unselected('//*[@id="contractidtable"]/tbody/tr[1]/td[6]/input');
    $d->find_element('//*[@id="period_datepicker"]')->click();
    $d->find_element('//*[@id="ui-datepicker-div"]//button[contains(text(), "Today")]')->click();
    $d->find_element('//*[@id="save"]')->click();

    diag("Search for Invoice");
    $d->fill_element('//*[@id="Invoice_table_filter"]/label/input', 'xpath', 'thisshouldnotexist');
    ok($d->find_element_by_css('#Invoice_table tr > td.dataTables_empty', 'css'), 'Garbage text was not found');
    $d->fill_element('//*[@id="Invoice_table_filter"]/label/input', 'xpath', $contactmail);

    diag("Check details");
    ok($d->wait_for_text('//*[@id="Invoice_table"]/tbody/tr/td[2]', $customernumber), 'Customer# is correct');
    ok($d->wait_for_text('//*[@id="Invoice_table"]/tbody/tr/td[3]', $contactmail), 'Customer Email is correct');

    diag("Trying to delete Invoice");
    $d->move_and_click('//*[@id="Invoice_table"]//tr[1]//td//a[contains(text(), "Delete")]', 'xpath', '//*[@id="Invoice_table_filter"]/label/input');
    $d->find_element('//*[@id="dataConfirmOK"]')->click();

    diag("Check if Invoice has been deleted");
    $d->fill_element('//*[@id="Invoice_table_filter"]/label/input', 'xpath', $contactmail);
    ok($d->find_element_by_css('#Invoice_table tr > td.dataTables_empty', 'css'), 'Invoice was deleted');

    diag("Go to Invoice Templates page");
    $d->find_element('//*[@id="main-nav"]//*[contains(text(),"Settings")]')->click();
    $d->find_element("Invoice Templates", 'link_text')->click();

    diag("Trying to delete Invoice Template");
    $d->fill_element('//*[@id="InvoiceTemplate_table_filter"]/label/input', 'xpath', 'thisshouldnotexist');
    ok($d->find_element_by_css('#InvoiceTemplate_table tr > td.dataTables_empty', 'css'), 'Garbage text was not found');
    $d->fill_element('//*[@id="InvoiceTemplate_table_filter"]/label/input', 'xpath', $templatename);
    $d->move_and_click('//*[@id="InvoiceTemplate_table"]//tr[1]//td//a[contains(text(), "Delete")]', 'xpath', '//*[@id="InvoiceTemplate_table_filter"]/label/input');
    $d->find_element('//*[@id="dataConfirmOK"]')->click();

    diag("Check if Invoice Template was deleted");
    $d->fill_element('//*[@id="InvoiceTemplate_table_filter"]/label/input', 'xpath', $templatename);
    ok($d->find_element_by_css('#InvoiceTemplate_table tr > td.dataTables_empty', 'css'), 'Invoice Template was deleted');

    $c->delete_customer($customerid);
    $c->delete_reseller_contract($contractid);
    $c->delete_reseller($resellername);
    $c->delete_contact($contactmail);
    $c->delete_billing_profile($billingname);
}

if(! caller) {
    ctr_invoice();
    done_testing;
}

1;