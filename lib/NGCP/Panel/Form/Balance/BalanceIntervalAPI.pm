package NGCP::Panel::Form::Balance::BalanceIntervalAPI;
use HTML::FormHandler::Moose;
use HTML::FormHandler::Widget::Block::Bootstrap;
use Moose::Util::TypeConstraints;
extends 'HTML::FormHandler';

has_field 'id' => (
    type => 'Hidden',
);

has_field 'start' => (
    type => '+NGCP::Panel::Field::DateTime',
    required => 0,
    element_attr => {
        rel => ['tooltip'],
        title => ['The datetime (YYYY-MM-DD HH:mm:ss) pointing the first second belonging to the balance interval.']
    },
);

has_field 'stop' => (
    type => '+NGCP::Panel::Field::DateTime',
    required => 0,
    element_attr => {
        rel => ['tooltip'],
        title => ['The datetime (YYYY-MM-DD HH:mm:ss) pointing the last second belonging to the balance interval.']
    },
);

has_field 'billing_profile_id' => (
    type => 'PosInteger',
    #required => 1,
    element_attr => {
        rel => ['tooltip'],
        title => ['The id of the billing profile at the first second of the balance interval.']
    },
);

has_field 'invoice_id' => (
    type => 'PosInteger',
    #required => 1,
    element_attr => {
        rel => ['tooltip'],
        title => ['The id of the invoice containing this invoice.']
    },
);

has_field 'cash_balance' => (
    type => 'Money',
    #label => 'Cash Balance',
    #required => 1,
    #inflate_method => sub { return $_[1] * 100 },
    #deflate_method => sub { return $_[1] / 100 },
    element_attr => {
        rel => ['tooltip'],
        title => ['The interval\'s cash balance of the contract in EUR/USD/etc.']
    },
);

has_field 'cash_debit' => (
    type => 'Money',
    #label => 'Cash Balance',
    #required => 1,
    #inflate_method => sub { return $_[1] * 100 },
    #deflate_method => sub { return $_[1] / 100 },
    element_attr => {
        rel => ['tooltip'],
        title => ['The amount spent during this interval in EUR/USD/etc.']
    },
);

has_field 'free_time_balance' => (
    type => 'Integer',
    #label => 'Free-Time Balance',
    #required => 1,
    element_attr => {
        rel => ['tooltip'],
        title => ['The interval\'s free-time balance of the contract in seconds.']
    },
);

has_field 'free_time_spent' => (
    type => 'Integer',
    #label => 'Free-Time Balance',
    #required => 1,
    element_attr => {
        rel => ['tooltip'],
        title => ['The free-time spent during this interval in EUR/USD/etc.']
    },
);

1;

# vim: set tabstop=4 expandtab: