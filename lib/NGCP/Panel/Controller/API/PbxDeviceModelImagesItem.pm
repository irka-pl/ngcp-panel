package NGCP::Panel::Controller::API::PbxDeviceModelImagesItem;
use NGCP::Panel::Utils::Generic qw(:all);

use Sipwise::Base;

use HTTP::Headers qw();
use HTTP::Status qw(:constants);

use NGCP::Panel::Utils::ValidateJSON qw();
require Catalyst::ActionRole::ACL;
require NGCP::Panel::Role::HTTPMethods;
require Catalyst::ActionRole::RequireSSL;

sub allowed_methods{
    return [qw/GET OPTIONS HEAD/];
}

use parent qw/Catalyst::Controller NGCP::Panel::Role::API::PbxDeviceModelImages NGCP::Panel::Role::API::PbxDeviceModels/;

sub resource_name{
    return 'pbxdevicemodelimages';
}
sub dispatch_path{
    return '/api/pbxdevicemodelimages/';
}
sub relation{
    return 'http://purl.org/sipwise/ngcp-api/#rel-pbxdevicemodelimages';
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
);

sub gather_default_action_roles {
    my ($self, %args) = @_; my @roles = ();
    push @roles, 'NGCP::Panel::Role::HTTPMethods' if $args{attributes}->{Method};
    return @roles;
}

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
        last unless $self->resource_exists($c, pbxdevicemodelimages => $item);
        my $type = $c->req->param('type') // 'front';
        my $data;
        my $ctype;
        if($type eq 'mac') {
            $data = $item->mac_image;
            $ctype = $item->mac_image_type;
        } else {
            $data = $item->front_image;
            $ctype = $item->front_image_type;
        }
        unless(defined $data) {
            $self->error($c, HTTP_NOT_FOUND, "Image type '$type' is not uploaded");
            last;
        }

        my $fext = $ctype; $fext =~ s/^.*?([a-zA-Z0-9]+)$/$1/;
        my $fname = $item->vendor . ' ' . $item->model . ".$fext";
        $c->response->header ('Content-Disposition' => 'attachment; filename="' . $fname . '"');
        $c->response->content_type($ctype);
        $c->response->body($data);
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

1;

# vim: set tabstop=4 expandtab:
