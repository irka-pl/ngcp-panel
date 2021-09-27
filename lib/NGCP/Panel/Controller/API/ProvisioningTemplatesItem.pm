package NGCP::Panel::Controller::API::ProvisioningTemplatesItem;
use NGCP::Panel::Utils::Generic qw(:all);

use Sipwise::Base;

use HTTP::Headers qw();
use HTTP::Status qw(:constants);

use NGCP::Panel::Utils::ValidateJSON qw();
require Catalyst::ActionRole::ACL;
require NGCP::Panel::Role::HTTPMethods;
require Catalyst::ActionRole::RequireSSL;
use Scalar::Util qw/blessed/;

sub allowed_methods{
    return [qw/GET OPTIONS HEAD PATCH PUT DELETE/];
}

use parent qw/NGCP::Panel::Role::EntitiesItem NGCP::Panel::Role::API::ProvisioningTemplates/;

sub resource_name{
    return 'provisioningtemplates';
}

sub dispatch_path{
    return '/api/provisioningtemplates/';
}

sub relation{
    return 'http://purl.org/sipwise/ngcp-api/#rel-provisioningtemplates';
}

sub journal_query_params {
    my($self,$query_params) = @_;
    return $self->get_journal_query_params($query_params);
}

sub get_journal_methods{
    return [qw/handle_item_base_journal handle_journals_get handle_journalsitem_get handle_journals_options handle_journalsitem_options handle_journals_head handle_journalsitem_head/];
}

__PACKAGE__->set_config({
    action_add  => {
        item_base => {
            Chained => '/',
            PathPart => 'api/' . __PACKAGE__->resource_name,
            CaptureArgs => 1,
        },
        item_get => {
            Chained => 'item_base',
            PathPart => '',
            Args => 0,
            Method => 'GET',
            ACLDetachTo => '/api/root/invalid_user',
            AllowedRole => [qw/admin reseller ccareadmin ccare/],
            Does => [qw(ACL RequireSSL)]
        },
        item_options => {
            Chained => 'item_base',
            PathPart => '',
            Args => 0,
            Method => 'OPTIONS',
            ACLDetachTo => '/api/root/invalid_user',
            AllowedRole => [qw/admin reseller ccareadmin ccare/],
            Does => [qw(ACL RequireSSL)]
        },
        item_head => {
            Chained => 'item_base',
            PathPart => '',
            Args => 0,
            Method => 'HEAD',
            ACLDetachTo => '/api/root/invalid_user',
            AllowedRole => [qw/admin reseller ccareadmin ccare/],
            Does => [qw(ACL RequireSSL)]
        },
        item_put => {
            Chained => 'item_base',
            PathPart => '',
            Args => 0,
            Method => 'PUT',
            ACLDetachTo => '/api/root/invalid_user',
            AllowedRole => [qw/admin reseller ccareadmin ccare/],
            Does => [qw(ACL RequireSSL)]
        },
        item_patch => {
            Chained => 'item_base',
            PathPart => '',
            Args => 0,
            Method => 'PATCH',
            ACLDetachTo => '/api/root/invalid_user',
            AllowedRole => [qw/admin reseller ccareadmin ccare/],
            Does => [qw(ACL RequireSSL)]
        },
        item_delete => {
            Chained => 'item_base',
            PathPart => '',
            Args => 0,
            Method => 'DELETE',
            ACLDetachTo => '/api/root/invalid_user',
            AllowedRole => [qw/admin reseller ccareadmin ccare/],
            Does => [qw(ACL RequireSSL)]
        },

        item_get_reseller => {
            Chained => 'item_base',
            PathPart => '',
            Args => 1,
            Method => 'GET',
            ACLDetachTo => '/api/root/invalid_user',
            AllowedRole => [qw/admin reseller ccareadmin ccare/],
            Does => [qw(ACL RequireSSL)]
        },
        item_options_reseller => {
            Chained => 'item_base',
            PathPart => '',
            Args => 1,
            Method => 'OPTIONS',
            ACLDetachTo => '/api/root/invalid_user',
            AllowedRole => [qw/admin reseller ccareadmin ccare/],
            Does => [qw(ACL RequireSSL)]
        },
        item_head_reseller => {
            Chained => 'item_base',
            PathPart => '',
            Args => 1,
            Method => 'HEAD',
            ACLDetachTo => '/api/root/invalid_user',
            AllowedRole => [qw/admin reseller ccareadmin ccare/],
            Does => [qw(ACL RequireSSL)]
        },
        item_put_reseller => {
            Chained => 'item_base',
            PathPart => '',
            Args => 1,
            Method => 'PUT',
            ACLDetachTo => '/api/root/invalid_user',
            AllowedRole => [qw/admin reseller ccareadmin ccare/],
            Does => [qw(ACL RequireSSL)]
        },
        item_patch_reseller => {
            Chained => 'item_base',
            PathPart => '',
            Args => 1,
            Method => 'PATCH',
            ACLDetachTo => '/api/root/invalid_user',
            AllowedRole => [qw/admin reseller ccareadmin ccare/],
            Does => [qw(ACL RequireSSL)]
        },
        item_delete_reseller => {
            Chained => 'item_base',
            PathPart => '',
            Args => 1,
            Method => 'DELETE',
            ACLDetachTo => '/api/root/invalid_user',
            AllowedRole => [qw/admin reseller ccareadmin ccare/],
            Does => [qw(ACL RequireSSL)]
        },
    }
});

sub item_base {
    my ($self,$c,$reseller) = @_;
    $c->stash->{id} = $reseller;
    #$c->log->debug((caller(0))[3] . ": " . $c->stash->{id});
    return;
}


sub item_get {
    my ($self,$c) = @_;
    #$c->log->debug((caller(0))[3] . ": " . $c->stash->{id});
    return $self->get($c,$c->stash->{id});
}

sub item_get_reseller {
    my ($self,$c,$name) = @_;
    $c->stash->{id} = $self->get_id($c->stash->{id},$name);
    #$c->log->debug((caller(0))[3] . ": " . $c->stash->{id});
    return $self->get($c,$c->stash->{id});
}


sub item_options {
    my ($self,$c) = @_;
    #$c->log->debug((caller(0))[3] . ": " . $c->stash->{id});
    return $self->options($c,$c->stash->{id});
}

sub item_options_reseller {
    my ($self,$c,$name) = @_;
    $c->stash->{id} = $self->get_id($c->stash->{id},$name);
    #$c->log->debug((caller(0))[3] . ": " . $c->stash->{id});
    return $self->options($c,$c->stash->{id});
}


sub item_head {
    my ($self,$c) = @_;
    $c->forward('item_get');
    $c->response->body(q());
    return;
}

sub item_head_reseller {
    my ($self,$c,$name) = @_;
    $c->forward('item_get_reseller');
    $c->response->body(q());
    return;
}


sub item_put {
    my ($self,$c) = @_;
    #$c->log->debug((caller(0))[3] . ": " . $c->stash->{id});
    return $self->put($c,$c->stash->{id});
}

sub item_put_reseller {
    my ($self,$c,$name) = @_;
    $c->stash->{id} = $self->get_id($c->stash->{id},$name);
    #$c->log->debug((caller(0))[3] . ": " . $c->stash->{id});
    return $self->put($c,$c->stash->{id});
}


sub item_patch {
    my ($self,$c) = @_;
    #$c->log->debug((caller(0))[3] . ": " . $c->stash->{id});
    return $self->patch($c,$c->stash->{id});
}

sub item_patch_reseller {
    my ($self,$c,$name) = @_;
    $c->stash->{id} = $self->get_id($c->stash->{id},$name);
    #$c->log->debug((caller(0))[3] . ": " . $c->stash->{id});
    return $self->patch($c,$c->stash->{id});
}


sub item_delete {
    my ($self,$c) = @_;
    #$c->log->debug((caller(0))[3] . ": " . $c->stash->{id});
    return $self->delete($c,$c->stash->{id});
}

sub item_delete_reseller {
    my ($self,$c,$name) = @_;
    $c->stash->{id} = $self->get_id($c->stash->{id},$name);
    #$c->log->debug((caller(0))[3] . ": " . $c->stash->{id});
    return $self->delete($c,$c->stash->{id});
}


sub update_item_model {

    my($self, $c, $item, $old_resource, $resource, $form, $process_extras) = @_;

    $resource->{yaml} = NGCP::Panel::Utils::ProvisioningTemplates::dump_template($c,
        $resource->{id},
        $resource->{name},
        delete $resource->{template},
    );

    $resource->{id} = $item->id;
    $resource->{modify_timestamp} = NGCP::Panel::Utils::DateTime::current_local;

    $item->update($resource);

    return $item;

}

sub delete_item {

    my($self, $c, $item) = @_;

    if ($item
        and not blessed($item)) {
        $self->error($c, HTTP_UNPROCESSABLE_ENTITY, "Provisioning template cannot be deleted");
        return;
    }

    $item->delete();
    return 1;

}

1;

