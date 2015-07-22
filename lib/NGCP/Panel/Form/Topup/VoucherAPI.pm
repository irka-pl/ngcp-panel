package NGCP::Panel::Form::Topup::VoucherAPI;

use HTML::FormHandler::Moose;
extends 'HTML::FormHandler';
use Moose::Util::TypeConstraints;

use HTML::FormHandler::Widget::Block::Bootstrap;

has '+widget_wrapper' => ( default => 'Bootstrap' );
has_field 'submitid' => ( type => 'Hidden' );
sub build_render_list {[qw/submitid fields actions/]}
sub build_form_element_class { [qw/form-horizontal/] }

has_field 'id' => (
    type => 'Hidden'
);

has_field 'subscriber_id' => (
    type => 'PosInteger',
    required => 1,
    element_attr => {
        rel => ['tooltip'],
        title => ['The subscriber for which to topup the balance.']
    },
);

has_field 'amount' => (
    type => 'Text',
    required => 1,
    maxlength => 128,
    element_attr => {
        rel => ['tooltip'],
        title => ['The voucher code for the topup.']
    },
);

1;
# vim: set tabstop=4 expandtab:
