package NGCP::Panel::Controller::API::ContractsItem;
use NGCP::Panel::Utils::Generic qw(:all);
no Moose;
use boolean qw(true);
use Data::HAL qw();
use Data::HAL::Link qw();
use HTTP::Headers qw();
use HTTP::Status qw(:constants);
#use MooseX::ClassAttribute qw(class_has);
use NGCP::Panel::Utils::ValidateJSON qw();
use NGCP::Panel::Utils::DateTime;
use NGCP::Panel::Utils::Contract qw();
use Path::Tiny qw(path);
use Safe::Isa qw($_isa);
BEGIN { extends 'Catalyst::Controller::ActionRole'; }
require Catalyst::ActionRole::ACL;
require Catalyst::ActionRole::HTTPMethods;
require Catalyst::ActionRole::RequireSSL;

with 'NGCP::Panel::Role::API::Contracts';

class_has('resource_name', is => 'ro', default => 'contracts');
class_has('dispatch_path', is => 'ro', default => '/api/contracts/');
class_has('relation', is => 'ro', default => 'http://purl.org/sipwise/ngcp-api/#rel-contracts');

class_has(@{ __PACKAGE__->get_journal_query_params() });

__PACKAGE__->config(
    action => {
        (map { $_ => {
            ACLDetachTo => '/api/root/invalid_user',
            AllowedRole => 'admin',
            Args => 1,
            Does => [qw(ACL RequireSSL)],
            Method => $_,
            Path => __PACKAGE__->dispatch_path,
        } } @{ __PACKAGE__->allowed_methods }),
        @{ __PACKAGE__->get_journal_action_config(__PACKAGE__->resource_name,{
            ACLDetachTo => '/api/root/invalid_user',
            AllowedRole => 'admin',
            Does => [qw(ACL RequireSSL)],
        }) } 
    },
    action_roles => [qw(HTTPMethods)],
);

sub auto :Private {
    my ($self, $c) = @_;

    $self->set_body($c);
    $self->log_request($c);
    #$self->apply_fake_time($c);    
    return 1;
}

sub GET :Allow {
    my ($self, $c, $id) = @_;
    $c->model('DB')->set_transaction_isolation('READ COMMITTED');
    my $guard = $c->model('DB')->txn_scope_guard;
    {
        last unless $self->valid_id($c, $id);
        my $contract = $self->contract_by_id($c, $id);
        last unless $self->resource_exists($c, contract => $contract);

        my $hal = $self->hal_from_contract($c, $contract, undef, NGCP::Panel::Utils::DateTime::current_local);
        $guard->commit; #potential db write ops in hal_from

        my $response = HTTP::Response->new(HTTP_OK, undef, HTTP::Headers->new(
            (map { # XXX Data::HAL must be able to generate links with multiple relations
                s|rel="(http://purl.org/sipwise/ngcp-api/#rel-resellers)"|rel="item $1"|r =~
                s/rel=self/rel="item self"/r;
            } $hal->http_headers),
        ), $hal->as_json);
        $c->response->headers($response->headers);
        $c->response->body($response->content);
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

sub PATCH :Allow {
    my ($self, $c, $id) = @_;
    $c->model('DB')->set_transaction_isolation('READ COMMITTED');
    my $guard = $c->model('DB')->txn_scope_guard;
    {
        my $preference = $self->require_preference($c);
        last unless $preference;

        my $json = $self->get_valid_patch_data(
            c => $c, 
            id => $id,
            media_type => 'application/json-patch+json',
        );
        last unless $json;

        my $now = NGCP::Panel::Utils::DateTime::current_local;
        my $contract = $self->contract_by_id($c, $id, $now);
        last unless $self->resource_exists($c, contract => $contract);
        
        my $old_resource = { $contract->get_inflated_columns };
        my $billing_mapping = $contract->billing_mappings->find($contract->get_column('bmid'));
        $old_resource->{billing_profile_id} = $billing_mapping->billing_profile_id;
        $old_resource->{billing_profile_definition} = undef;
        delete $old_resource->{profile_package_id};

        my $resource = $self->apply_patch($c, $old_resource, $json, sub {
            my ($missing_field,$entity) = @_;
            if ($missing_field eq 'billing_profiles') {
                $entity->{billing_profiles} = NGCP::Panel::Utils::Contract::resource_from_future_mappings($contract);
                $entity->{billing_profile_definition} //= 'profiles';
            }
        });
        last unless $resource;

        my $form = $self->get_form($c);
        $contract = $self->update_contract($c, $contract, $old_resource, $resource, $form, $now);
        last unless $contract;

        my $hal = $self->hal_from_contract($c, $contract, $form, $now);
        last unless $self->add_update_journal_item_hal($c,$hal);
        
        $guard->commit;

        if ('minimal' eq $preference) {
            $c->response->status(HTTP_NO_CONTENT);
            $c->response->header(Preference_Applied => 'return=minimal');
            $c->response->body(q());
        } else {
            #my $hal = $self->hal_from_contract($c, $contract, $form);
            my $response = HTTP::Response->new(HTTP_OK, undef, HTTP::Headers->new(
                $hal->http_headers,
            ), $hal->as_json);
            $c->response->headers($response->headers);
            $c->response->header(Preference_Applied => 'return=representation');
            $c->response->body($response->content);
        }
    }
    return;
}

sub PUT :Allow {
    my ($self, $c, $id) = @_;
    $c->model('DB')->set_transaction_isolation('READ COMMITTED');
    my $guard = $c->model('DB')->txn_scope_guard;
    {
        my $preference = $self->require_preference($c);
        last unless $preference;

        my $now = NGCP::Panel::Utils::DateTime::current_local;
        my $contract = $self->contract_by_id($c, $id, $now);
        last unless $self->resource_exists($c, contract => $contract);
        my $resource = $self->get_valid_put_data(
            c => $c,
            id => $id,
            media_type => 'application/json',
        );
        last unless $resource;
        my $old_resource = { $contract->get_inflated_columns };
        my $billing_mapping = $contract->billing_mappings->find($contract->get_column('bmid'));
        $old_resource->{type} = $billing_mapping->product->class;

        my $form = $self->get_form($c);
        $contract = $self->update_contract($c, $contract, $old_resource, $resource, $form, $now);
        last unless $contract;
        
        my $hal = $self->hal_from_contract($c, $contract, $form, $now);
        last unless $self->add_update_journal_item_hal($c,$hal);

        $guard->commit;

        if ('minimal' eq $preference) {
            $c->response->status(HTTP_NO_CONTENT);
            $c->response->header(Preference_Applied => 'return=minimal');
            $c->response->body(q());
        } else {
            #my $hal = $self->hal_from_contract($c, $contract, $form);
            my $response = HTTP::Response->new(HTTP_OK, undef, HTTP::Headers->new(
                $hal->http_headers,
            ), $hal->as_json);
            $c->response->headers($response->headers);
            $c->response->header(Preference_Applied => 'return=representation');
            $c->response->body($response->content);
        }
    }
    return;
}

=pod

# we don't allow to delete contracts
sub DELETE :Allow {
    my ($self, $c, $id) = @_;
    my $guard = $c->model('DB')->txn_scope_guard;
    {
        my $contract = $self->contract_by_id($c, $id);
        last unless $self->resource_exists($c, contract => $contract);

        # TODO: do we want to prevent deleting used contracts?
        #my $contract_count = $c->model('DB')->resultset('contracts')->search({
        #    contact_id => $id
        #});
        #if($contract_count > 0) {
        #    $self->error($c, HTTP_LOCKED, "Contact is still in use.");
        #    last;
        #} else {
            $contract->delete;
        #}
        $guard->commit;

        $c->response->status(HTTP_NO_CONTENT);
        $c->response->body(q());
    }
    return;
}

=cut

sub item_base_journal :Journal {
    my $self = shift @_;
    return $self->handle_item_base_journal(@_);
}
    
sub journals_get :Journal {
    my $self = shift @_;
    return $self->handle_journals_get(@_);
}

sub journalsitem_get :Journal {
    my $self = shift @_;
    return $self->handle_journalsitem_get(@_);
}

sub journals_options :Journal {
    my $self = shift @_;
    return $self->handle_journals_options(@_);
}

sub journalsitem_options :Journal {
    my $self = shift @_;
    return $self->handle_journalsitem_options(@_);
}

sub journals_head :Journal {
    my $self = shift @_;
    return $self->handle_journals_head(@_);
}

sub journalsitem_head :Journal {
    my $self = shift @_;
    return $self->handle_journalsitem_head(@_);
}

sub end : Private {
    my ($self, $c) = @_;

    #$self->reset_fake_time($c);
    $self->log_response($c);
    return;
}

no Moose;
1;

# vim: set tabstop=4 expandtab:
