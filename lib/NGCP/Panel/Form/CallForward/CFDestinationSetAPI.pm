package NGCP::Panel::Form::CallForward::CFDestinationSetAPI;
use HTML::FormHandler::Moose;
extends 'NGCP::Panel::Form::CallForward::CFDestinationSetSubAPI';

has_field 'subscriber_id' => (
    type => 'PosInteger',
    required => 1,
    element_attr => {
        rel => ['tooltip'],
        title => ['The subscriber id this destination set belongs to.']
    },
);

1;

# vim: set tabstop=4 expandtab:
