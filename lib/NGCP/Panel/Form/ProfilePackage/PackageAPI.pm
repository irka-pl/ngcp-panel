package NGCP::Panel::Form::ProfilePackage::PackageAPI;
use HTML::FormHandler::Moose;
use HTML::FormHandler::Widget::Block::Bootstrap;
use Moose::Util::TypeConstraints;
extends 'HTML::FormHandler';

has_field 'id' => (
    type => 'Hidden',
);

has_field 'reseller_id' => (
    type => 'PosInteger',
    #required => 1,
    element_attr => {
        rel => ['tooltip'],
        title => ['The reseller id this profile package belongs to.']
    },
);

has_field 'name' => (
    type => 'Text',
    required => 1,
    maxlength => 255,
    element_attr => {
        rel => ['tooltip'],
        title => ['The unique name of the profile package.']
    },
);

has_field 'description' => (
    type => 'Text',
    required => 1,
    maxlength => 255,
    element_attr => {
        rel => ['tooltip'],
        title => ['Arbitrary text.'],
    },
);

has_field 'status' => (
    type => 'Hidden',
    options => [
        { value => 'active', label => 'active' },
        { value => 'terminated', label => 'terminated' },
    ],
    element_attr => {
        rel => ['tooltip'],
        title => ['The status of this package. Only active profile packages can be assigned to customers/profile packages.']
    },
);


has_field 'initial_balance' => (
    type => 'Money',
    element_attr => {
        rel => ['tooltip'],
        title => ['The initial balance (in cents) that will be set for the very first balance interval.']
    },
);

has_field 'initial_profiles' => (
    type => 'Repeatable',
    element_attr => {
        rel => ['tooltip'],
        title => ['An array of objects with keys "profile_id" and "network_id" to create profile mappings from when applying this profile package to a customer.']
    },
);

has_field 'initial_profiles.profile_id' => (
    type => 'PosInteger',
    required => 1,
    label => 'Billing profile id',
);

has_field 'initial_profiles.network_id' => (
    type => 'PosInteger',
    required => 0,
    label => 'Optional billing network id',
);

has_field 'balance_interval_unit' => (
    type => 'Select',
    options => [
        { value => 'day', label => 'day' },
        { value => 'week', label => 'week' },
        { value => 'month', label => 'month' },
    ],
    element_attr => {
        rel => ['tooltip'],
        title => ['The temporal unit for the balance interval.']
    },
);

has_field 'balance_interval_value' => (
    type => 'PosInteger',
    element_attr => {
        rel => ['tooltip'],
        title => ['The balance interval in temporal units.']
    },
);

has_field 'balance_interval_start_mode' => (
    type => 'Select',
    options => [
        { value => 'create', label => 'upon customer creation' },
        { value => '1st', label => '1st day of month' },
        { value => 'topup_interval', label => 'start interval upon top-up' },
        { value => 'topup', label => 'new interval for each top-up' },     
    ],
    element_attr => {
        rel => ['tooltip'],
        title => ['This mode determines when balance intervals start.']
    },
);


has_field 'carry_over_mode' => (
    type => 'Select',
    options => [
        { value => 'carry_over', label => 'carry over' },
        { value => 'carry_over_timely', label => 'carry over only if topped-up timely' },
        { value => 'discard', label => 'discard' },
    ],
    element_attr => {
        rel => ['tooltip'],
        title => ['Options to carry over the customer\'s balance to the next balance interval.']
    },
);

has_field 'timely_duration_unit' => (
    type => 'Select',
    options => [
        { value => 'day', label => 'day' },
        { value => 'week', label => 'week' },
        { value => 'month', label => 'month' },
    ],
    element_attr => {
        rel => ['tooltip'],
        title => ['The temporal unit for the "timely" interval.']
    },
);

has_field 'timely_duration_value' => (
    type => 'PosInteger',
    element_attr => {
        rel => ['tooltip'],
        title => ['The "timely" interval in temporal units.']
    },
);

has_field 'notopup_discard_intervals' => (
    type => 'PosInteger',
    element_attr => {
        rel => ['tooltip'],
        title => ['The balance will be discarded if no top-up happened for the the given number of balance intervals.']
    },
);


has_field 'underrun_lock_threshold' => (
    type => 'Money',
    element_attr => {
        rel => ['tooltip'],
        title => ['The balance threshold (in cents) for the underrun lock level to come into effect.']
    },
);

has_field 'underrun_lock_level' => (
    type => '+NGCP::Panel::Field::SubscriberLockSelect',
    element_attr => {
        rel => ['tooltip'],
        title => ['The lock level to set the customer\'s subscribers to in case the balance underruns "underrun_lock_threshold".']
    },
);

has_field 'underrun_profile_threshold' => (
    type => 'Money',
    element_attr => {
        rel => ['tooltip'],
        title => ['The balance threshold (in cents) for underrun profiles to come into effect.']
    },
);

has_field 'underrun_profiles' => (
    type => 'Repeatable',
    element_attr => {
        rel => ['tooltip'],
        title => ['An array of objects with keys "profile_id" and "network_id" to create profile mappings from when the balance underruns the "underrun_profile_threshold" value.']
    },
);


has_field 'underrun_profiles.profile_id' => (
    type => 'PosInteger',
    required => 1,
    label => 'Billing profile id',
);

has_field 'underrun_profiles.network_id' => (
    type => 'PosInteger',
    required => 0,
    label => 'Optional billing network id',
);


has_field 'topup_lock_level' => (
    type => '+NGCP::Panel::Field::SubscriberLockSelect',
    element_attr => {
        rel => ['tooltip'],
        title => ['The lock level to reset the customer\'s subscribers to after a successful top-up (usually null).']
    },
);

has_field 'service_charge' => (
    type => 'Money',
    element_attr => {
        rel => ['tooltip'],
        title => ['The service charge amount (in cents) will be subtracted from the voucher amount.']
    },
);


has_field 'topup_profiles' => (
    type => 'Repeatable',
    element_attr => {
        rel => ['tooltip'],
        title => ['An array of objects with keys "profile_id" and "network_id" to create profile mappings from when a customer top-ups with a voucher associated with this profile package.']
    },
);

has_field 'topup_profiles.profile_id' => (
    type => 'PosInteger',
    required => 1,
    label => 'Billing profile id',
);

has_field 'topup_profiles.network_id' => (
    type => 'PosInteger',
    required => 0,
    label => 'Optional billing network id',
);

1;