package NGCP::Panel::Role::API::SubscriberProfileSets;
use NGCP::Panel::Utils::Generic qw(:all);

use Sipwise::Base;

use parent 'NGCP::Panel::Role::API';


use boolean qw(true);
use Data::HAL qw();
use Data::HAL::Link qw();
use HTTP::Status qw(:constants);

sub _item_rs {
    my ($self, $c) = @_;

    my $item_rs = $c->model('DB')->resultset('voip_subscriber_profile_sets');
    if ($c->user->roles eq "admin" || $c->user->roles eq "ccareadmin") {
    } elsif ($c->user->roles eq "reseller" || $c->user->roles eq "ccare") {
        $item_rs = $item_rs->search({ reseller_id => $c->user->reseller_id });
    }
    return $item_rs;
}

sub get_form {
    my ($self, $c) = @_;
    if ($c->user->roles eq "admin" || $c->user->roles eq "ccareadmin") {
        return NGCP::Panel::Form::get("NGCP::Panel::Form::SubscriberProfile::SetAdmin", $c);
    } elsif ($c->user->roles eq "reseller" || $c->user->roles eq "ccare") {
        return NGCP::Panel::Form::get("NGCP::Panel::Form::SubscriberProfile::SetReseller", $c);
    }
}

sub hal_from_item {
    my ($self, $c, $item, $form) = @_;
    my %resource = $item->get_inflated_columns;

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
            Data::HAL::Link->new(relation => 'ngcp:resellers', href => sprintf("/api/resellers/%d", $item->reseller_id)),
            $self->get_journal_relation_link($c, $item->id),
        ],
        relation => 'ngcp:'.$self->resource_name,
    );

    $form //= $self->get_form($c);

    $self->validate_form(
        c => $c,
        resource => \%resource,
        form => $form,
        run => 0,
    );

    $resource{id} = int($item->id);

    $self->expand_fields($c, \%resource);
    $hal->resource({%resource});
    return $hal;
}

sub item_by_id {
    my ($self, $c, $id) = @_;
    my $item_rs = $self->item_rs($c);
    return $item_rs->find($id);
}

sub update_item {
    my ($self, $c, $item, $old_resource, $resource, $form) = @_;

    $form //= $self->get_form($c);
    return unless $self->validate_form(
        c => $c,
        form => $form,
        resource => $resource,
    );
    if ($c->user->roles eq "admin") {
    } elsif($c->user->roles eq "reseller") {
        $resource->{reseller_id} = $c->user->reseller_id;
    } elsif ($c->user->roles eq "ccareadmin" || $c->user->roles eq "ccare") {
        $self->error($c, HTTP_FORBIDDEN, "Read-only resource for authenticated role");
        return;
    }

    my $dup_item = $c->model('DB')->resultset('voip_subscriber_profile_sets')->find({
        reseller_id => $resource->{reseller_id},
        name => $resource->{name},
    });
    if($dup_item && $dup_item->id != $item->id) {
        $c->log->error("subscriber profile set with name '$$resource{name}' already exists for reseller_id '$$resource{reseller_id}'"); # TODO: user, message, trace, ...
        $self->error($c, HTTP_UNPROCESSABLE_ENTITY, "Subscriber profile set with this name already exists for this reseller");
        return;
    }

    $item->update($resource);

    return $item;
}

1;
# vim: set tabstop=4 expandtab:
