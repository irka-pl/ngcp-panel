package NGCP::Panel::Controller::API::PbxDeviceConfigFilesItem;
use NGCP::Panel::Utils::Generic qw(:all);
no Moose;
use HTTP::Headers qw();
use HTTP::Status qw(:constants);

use TryCatch;
use NGCP::Panel::Utils::DateTime;
use NGCP::Panel::Utils::ValidateJSON qw();
use Path::Tiny qw(path);
use Safe::Isa qw($_isa);
require Catalyst::ActionRole::ACL;
require NGCP::Panel::Role::HTTPMethods;
require Catalyst::ActionRole::RequireSSL;

sub allowed_methods{
    return [qw/GET OPTIONS HEAD/];
}

use parent qw/Catalyst::Controller NGCP::Panel::Role::API::PbxDeviceConfigs/;

sub resource_name{
    return 'pbxdeviceconfigfiles';
}
sub dispatch_path{
    return '/api/pbxdeviceconfigfiles/';
}
sub relation{
    return 'http://purl.org/sipwise/ngcp-api/#rel-pbxdeviceconfigfiles';
}

__PACKAGE__->config(
    action => {
        map { $_ => {
            ACLDetachTo => '/api/root/invalid_user',
            AllowedRole => [qw/admin reseller/],
            Args => 1,
            Does => [qw(ACL RequireSSL)],
            Method => $_,
            Path => __PACKAGE__->dispatch_path,
        } } @{ __PACKAGE__->allowed_methods }
    },
    action_roles => [qw(+NGCP::Panel::Role::HTTPMethods)],
);

sub auto :Private {
    my ($self, $c) = @_;

    $self->set_body($c);
    $self->log_request($c);
}

sub GET :Allow {
    my ($self, $c, $id) = @_;
    {
        last unless $self->valid_id($c, $id);
        my $item = $self->item_by_id($c, $id);
        last unless $self->resource_exists($c, pbxdevicefirmwarebinary => $item);
        my $resource = $self->resource_from_item($c, $item);

        $resource->{data} = $item->data;
        $c->response->header ('Content-Disposition' => 'attachment; filename="pbxdeviceconfig_' . $item->device_id . '_' . $item->id . '"');
        $c->response->content_type($item->content_type);
        $c->response->body($resource->{data});
        return;
    }
    return;
}

sub HEAD :Allow {
    my ($self, $c, $id) = @_;
    $c->forward(qw(GET));
    $c->response->body(q());
    return;
}

sub OPTIONS :Allow {
    my ($self, $c, $id) = @_;
    my $allowed_methods = $self->allowed_methods_filtered($c);
    $c->response->headers(HTTP::Headers->new(
        Allow => join(', ', @{ $allowed_methods }),
        Accept_Patch => 'application/json-patch+json',
    ));
    $c->response->content_type('application/json');
    $c->response->body(JSON::to_json({ methods => $allowed_methods })."\n");
    return;
}

sub end : Private {
    my ($self, $c) = @_;

    #$self->log_response($c);
}

no Moose;
1;

# vim: set tabstop=4 expandtab:
