package NGCP::Panel::Role::API::Events;
use NGCP::Panel::Utils::Generic qw(:all);

use Sipwise::Base;

use parent 'NGCP::Panel::Role::API';


use boolean qw(true);
use Data::HAL qw();
use Data::HAL::Link qw();
use HTTP::Status qw(:constants);
use NGCP::Panel::Form::Event::Reseller;
use NGCP::Panel::Form::Event::Admin;
use NGCP::Panel::Utils::Events qw();
#use Data::Dumper;

sub _item_rs {
    my ($self, $c) = @_;

    my $item_rs = $c->model('DB')->resultset('events');
    if($c->user->roles eq "admin") {
    } elsif($c->user->roles eq "reseller") {
        $item_rs = $item_rs->search({
            'reseller_id' => $c->user->reseller_id,
        },undef);
    }
    return $item_rs;
}

sub get_form {
    my ($self, $c) = @_;
    if($c->user->roles eq "admin") {
        return NGCP::Panel::Form::Event::Admin->new;
    } elsif($c->user->roles eq "reseller") {
        return NGCP::Panel::Form::Event::Reseller->new;
    }
}

sub hal_from_item {
    my ($self, $c, $item, $form) = @_;
    my %resource = $item->get_inflated_columns;

    my $datetime_fmt = DateTime::Format::Strptime->new(
        pattern => '%F %T',
    );
    $resource{timestamp} = $datetime_fmt->format_datetime($resource{timestamp}) if defined $resource{timestamp};

    $resource{primary_number_id} = NGCP::Panel::Utils::Events::get_relation_value(c => $c, event => $item, type => 'primary_number_id');
    $resource{primary_number_ac} = NGCP::Panel::Utils::Events::get_tag_value(c => $c, event => $item, type => 'primary_number_ac');
    $resource{primary_number_cc} = NGCP::Panel::Utils::Events::get_tag_value(c => $c, event => $item, type => 'primary_number_cc');
    $resource{primary_number_sn} = NGCP::Panel::Utils::Events::get_tag_value(c => $c, event => $item, type => 'primary_number_sn');
    $resource{subscriber_profile_id} = NGCP::Panel::Utils::Events::get_relation_value(c => $c, event => $item, type => 'subscriber_profile_id');
    $resource{subscriber_profile_name} = NGCP::Panel::Utils::Events::get_tag_value(c => $c, event => $item, type => 'subscriber_profile_name');
    $resource{subscriber_profile_set_id} = NGCP::Panel::Utils::Events::get_relation_value(c => $c, event => $item, type => 'subscriber_profile_set_id');
    $resource{subscriber_profile_set_name} = NGCP::Panel::Utils::Events::get_tag_value(c => $c, event => $item, type => 'subscriber_profile_set_name');

    $resource{pilot_subscriber_id} = NGCP::Panel::Utils::Events::get_relation_value(c => $c, event => $item, type => 'pilot_subscriber_id');

    $resource{pilot_primary_number_id} = NGCP::Panel::Utils::Events::get_relation_value(c => $c, event => $item, type => 'pilot_primary_number_id');
    $resource{pilot_primary_number_ac} = NGCP::Panel::Utils::Events::get_tag_value(c => $c, event => $item, type => 'pilot_primary_number_ac');
    $resource{pilot_primary_number_cc} = NGCP::Panel::Utils::Events::get_tag_value(c => $c, event => $item, type => 'pilot_primary_number_cc');
    $resource{pilot_primary_number_sn} = NGCP::Panel::Utils::Events::get_tag_value(c => $c, event => $item, type => 'pilot_primary_number_sn');
    $resource{pilot_subscriber_profile_id} = NGCP::Panel::Utils::Events::get_relation_value(c => $c, event => $item, type => 'pilot_subscriber_profile_id');
    $resource{pilot_subscriber_profile_name} = NGCP::Panel::Utils::Events::get_tag_value(c => $c, event => $item, type => 'pilot_subscriber_profile_name');
    $resource{pilot_subscriber_profile_set_id} = NGCP::Panel::Utils::Events::get_relation_value(c => $c, event => $item, type => 'pilot_subscriber_profile_set_id');
    $resource{pilot_subscriber_profile_set_name} = NGCP::Panel::Utils::Events::get_tag_value(c => $c, event => $item, type => 'pilot_subscriber_profile_set_name');

    $resource{first_non_primary_alias_username_before} = NGCP::Panel::Utils::Events::get_tag_value(c => $c, event => $item, type => 'first_non_primary_alias_username_before');
    $resource{first_non_primary_alias_username_after} = NGCP::Panel::Utils::Events::get_tag_value(c => $c, event => $item, type => 'first_non_primary_alias_username_after');
    $resource{pilot_first_non_primary_alias_username_before} = NGCP::Panel::Utils::Events::get_tag_value(c => $c, event => $item, type => 'pilot_first_non_primary_alias_username_before');
    $resource{pilot_first_non_primary_alias_username_after} = NGCP::Panel::Utils::Events::get_tag_value(c => $c, event => $item, type => 'pilot_first_non_primary_alias_username_after');

    $resource{non_primary_alias_username} = NGCP::Panel::Utils::Events::get_tag_value(c => $c, event => $item, type => 'non_primary_alias_username');

    my $hal = Data::HAL->new(
        links => [
            Data::HAL::Link->new(
                relation => 'curies',
                href => 'http://purl.org/sipwise/ngcp-api/#rel-{rel}',
                name => 'ngcp',
                templated => true,
            ),
            Data::HAL::Link->new(relation => 'collection', href => sprintf("/api/%s/", $self->resource_name)),
            Data::HAL::Link->new(relation => 'profile', href => 'http://purl.org/sipwise/ngcp-api/'),
            Data::HAL::Link->new(relation => 'self', href => sprintf("%s%d", $self->dispatch_path, $item->id)),
            (defined $item->subscriber_id ? Data::HAL::Link->new(relation => 'ngcp:subscribers', href => sprintf("/api/subscribers/%d", $item->subscriber_id)) : ()),
            (defined $item->reseller_id ? Data::HAL::Link->new(relation => 'ngcp:resellers', href => sprintf("/api/resellers/%d", $item->reseller_id)) : ()),
            #(defined $resource{pilot_subscriber_id} ? Data::HAL::Link->new(relation => 'ngcp:subscribers', href => sprintf("/api/subscribers/%d", $resource{pilot_subscriber_id})) : ()),
            #(defined $resource{subscriber_profile_set_id} ? Data::HAL::Link->new(relation => 'ngcp:subscriberprofilesets', href => sprintf("/api/subscriberprofilesets/%d", $resource{subscriber_profile_set_id})) : ()),
            #(defined $resource{subscriber_profile_id} ? Data::HAL::Link->new(relation => 'ngcp:subscriberprofiles', href => sprintf("/api/subscriberprofiles/%d", $resource{subscriber_profile_id})) : ()),
        ],
        relation => 'ngcp:'.$self->resource_name,
    );

    $form //= $self->get_form($c);

    $self->validate_form(
        c => $c,
        resource => \%resource,
        form => $form,
        run => 0,
        exceptions => [qw/id subscriber_id reseller_id
                          primary_number_id subscriber_profile_id subscriber_profile_set_id
                          pilot_subscriber_id
                          pilot_primary_number_id pilot_subscriber_profile_id pilot_subscriber_profile_set_id/],
    );

    $resource{id} = int($item->id);
    $hal->resource({%resource});
    return $hal;
}

sub item_by_id {
    my ($self, $c, $id) = @_;
    my $item_rs = $self->item_rs($c);
    return $item_rs->find($id);
}

1;
