package NGCP::Panel::Role::API::PbxDeviceFirmwares;
use NGCP::Panel::Utils::Generic qw(:all);

use Sipwise::Base;

use parent 'NGCP::Panel::Role::API';


use boolean qw(true);
use Data::HAL qw();
use Data::HAL::Link qw();
use HTTP::Status qw(:constants);

sub _item_rs {
    my ($self, $c) = @_;

    my $item_rs = $c->model('DB')->resultset('autoprov_firmwares');
    if($c->user->roles eq "admin") {
    } elsif($c->user->roles eq "reseller") {
        $item_rs = $item_rs->search({
            'device.reseller_id' => $c->user->reseller_id
        },{
            join => 'device',
        });
    }
    return $item_rs;
}

sub get_form {
    my ($self, $c) = @_;
    return NGCP::Panel::Form::get("NGCP::Panel::Form::Device::FirmwareAPI", $c);
}

sub hal_from_item {
    my ($self, $c, $item, $form) = @_;

    $form //= $self->get_form($c);
    my $resource = $self->resource_from_item($c, $item, $form);

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
            Data::HAL::Link->new(relation => 'ngcp:pbxdevicemodels', href => sprintf("/api/pbxdevicemodels/%d", $item->device_id)),
            Data::HAL::Link->new(relation => 'ngcp:pbxdevicefirmwarebinaries', href => sprintf("/api/pbxdevicefirmwarebinaries/%d", $item->id)),
        ],
        relation => 'ngcp:'.$self->resource_name,
    );


    $self->validate_form(
        c => $c,
        resource => $resource,
        form => $form,
        run => 0,
    );

    $resource->{id} = int($item->id);

    $self->expand_fields($c, $resource);
    $hal->resource($resource);
    return $hal;
}

sub resource_from_item {
    my ($self, $c, $item, $form) = @_;

    my $resource = { $item->get_inflated_columns };

    return $resource;
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

    my $model_rs = $c->model('DB')->resultset('autoprov_devices')->search({ 
        id => $resource->{device_id} 
    });
    if($c->user->roles eq "admin") {
    } elsif($c->user->roles eq "reseller") {
        $model_rs = $model_rs->search({
            reseller_id => $c->user->reseller_id,
        });
    }
    my $model = $model_rs->first;
    unless($model) {
        $c->log->error("invalid device_id '$$resource{device_id}'");
        $self->error($c, HTTP_UNPROCESSABLE_ENTITY, "Pbx device model does not exist");
        return;
    }

    $item->update($resource);

    return $item;
}

1;
# vim: set tabstop=4 expandtab:
