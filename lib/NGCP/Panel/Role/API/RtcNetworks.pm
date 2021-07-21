package NGCP::Panel::Role::API::RtcNetworks;
use NGCP::Panel::Utils::Generic qw(:all);

use Sipwise::Base;

use parent 'NGCP::Panel::Role::API';
use boolean qw(true);
use Data::HAL qw();
use Data::HAL::Link qw();
use HTTP::Status qw(:constants);
use JSON::Types;

use NGCP::Panel::Utils::Subscriber;
use NGCP::Panel::Utils::Rtc;

sub get_form {
    my ($self, $c) = @_;

    return NGCP::Panel::Form::get("NGCP::Panel::Form::Rtc::NetworksAdmin", $c);
}

sub hal_from_item {
    my ($self, $c, $item, $include_id) = @_;

    my $resource = { reseller_id => $item->id };
    if ($item->rtc_user) {
        my $rtc_user_id = $item->rtc_user->rtc_user_id;
        $resource->{rtc_user_id} = $rtc_user_id if $include_id;
        $resource->{networks} = NGCP::Panel::Utils::Rtc::get_rtc_networks(
            rtc_user_id => $rtc_user_id,
            config => $c->config,
            include_id => $include_id,
            err_code => sub {
                my ($msg, $debug) = @_;
                $c->log->debug($debug) if $debug;
                $c->log->warn($msg);
                return;
            });
    } else {
    }
    #for get=>put compatibility
    if ('ARRAY' ne ref $resource->{networks}) {
        $resource->{networks} = [];
    }

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
            Data::HAL::Link->new(relation => 'ngcp:resellers', href => sprintf("/api/resellers/%d", $item->id)),
            $self->get_journal_relation_link($c, $item->id),
        ],
        relation => 'ngcp:'.$self->resource_name,
    );

    my $form = $self->get_form($c);
    unless ($include_id) {
        return unless $self->validate_form(
            c => $c,
            form => $form,
            resource => $resource,
            run => 0,
        );
    }

    $self->expand_fields($c, $resource);
    $hal->resource($resource);
    return $hal;
}

sub _item_rs {
    my ($self, $c) = @_;

    my $item_rs;
    $item_rs = $c->model('DB')->resultset('resellers')
        ->search_rs(undef, {
                prefetch => 'rtc_user',
            });
    if($c->user->roles eq "admin") {
    } elsif($c->user->roles eq "reseller") {
        $item_rs = $item_rs->search({
            id => $c->user->reseller_id,
        });
    }

    return $item_rs;
}

sub item_by_id {
    my ($self, $c, $id) = @_;

    my $item_rs = $self->item_rs($c);
    return $item_rs->find($id);
}

sub update_item {
    my ($self, $c, $item, $old_resource, $resource, $form) = @_;

    my $reseller = $item;

    if (ref $resource->{networks} ne "ARRAY") {
        $self->error($c, HTTP_UNPROCESSABLE_ENTITY, "Invalid field 'networks'. Must be an array.");
        return;
    }

    $form //= $self->get_form($c);
    return unless $self->validate_form(
        c => $c,
        form => $form,
        resource => $resource,
    );

    try {
        NGCP::Panel::Utils::Rtc::modify_rtc_networks(
            old_resource => $old_resource,
            resource => $resource,
            config => $c->config,
            reseller_item => $reseller,
            err_code => sub {
                my ($msg, $debug) = @_;
                $c->log->debug($debug) if $debug;
                $c->log->warn($msg);
                return;
            });
    } catch($e) {
        $c->log->error("failed to update rtcnetworks: $e");
        $self->error($c, HTTP_INTERNAL_SERVER_ERROR, "Failed to update rtcnetworks.");
        return;
    };

    return $reseller;
}

1;
# vim: set tabstop=4 expandtab:
