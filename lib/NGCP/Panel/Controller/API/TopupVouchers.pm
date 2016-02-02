package NGCP::Panel::Controller::API::TopupVouchers;
use NGCP::Panel::Utils::Generic qw(:all);
no Moose;
use boolean qw(true);
use Data::HAL qw();
use Data::HAL::Link qw();
use HTTP::Headers qw();
use HTTP::Status qw(:constants);
#use MooseX::ClassAttribute qw(class_has);
use Moo;
use MooX::ClassAttribute qw(class_has);
use TryCatch;
use NGCP::Panel::Utils::Voucher;
use NGCP::Panel::Utils::DateTime;
use NGCP::Panel::Utils::ProfilePackages;
use Path::Tiny qw(path);
use Safe::Isa qw($_isa);
require Catalyst::ActionRole::ACL;
require Catalyst::ActionRole::CheckTrailingSlash;
require Catalyst::ActionRole::HTTPMethods;
require Catalyst::ActionRole::RequireSSL;

sub allowed_methods{
    return [qw/GET POST OPTIONS HEAD/];
}

use NGCP::Panel::Form::Topup::VoucherAPI;

use base qw/Catalyst::Controller NGCP::Panel::Role::API/;

sub api_description {
    return 'Defines topup via voucher codes.';
};

class_has 'query_params' => (
    is => 'ro',

    default => sub {[
    ]},
);

class_has('resource_name', is => 'ro', default => 'topupvouchers');
class_has('dispatch_path', is => 'ro', default => '/api/topupvouchers/');
class_has('relation', is => 'ro', default => 'http://purl.org/sipwise/ngcp-api/#rel-topupvouchers');

__PACKAGE__->config(
    action => {
        map { $_ => {
            ACLDetachTo => '/api/root/invalid_user',
            AllowedRole => [qw/admin reseller/],
            Args => 0,
            Does => [qw(ACL CheckTrailingSlash RequireSSL)],
            Method => $_,
            Path => __PACKAGE__->dispatch_path,
        } } @{ __PACKAGE__->allowed_methods }
    },
    action_roles => [qw(HTTPMethods)],
);

sub auto :Private {
    my ($self, $c) = @_;

    $self->set_body($c);
    $self->log_request($c);
}

sub OPTIONS :Allow {
    my ($self, $c) = @_;
    my $allowed_methods = $self->allowed_methods_filtered($c);
    $c->response->headers(HTTP::Headers->new(
        Allow => join(', ', @{ $allowed_methods }),
        Accept_Post => 'application/hal+json; profile=http://purl.org/sipwise/ngcp-api/#rel-'.$self->resource_name,
    ));
    $c->response->content_type('application/json');
    $c->response->body(JSON::to_json({ methods => $allowed_methods })."\n");
    return;
}

sub POST :Allow {
    my ($self, $c) = @_;

    my $success = 0;
    my $entities = {};
    my $log_vals = {};
    my $resource = undef;
    my $now = NGCP::Panel::Utils::DateTime::current_local;
    $c->model('DB')->set_transaction_isolation('READ COMMITTED');
    my $guard = $c->model('DB')->txn_scope_guard;
    {
        unless($c->user->billing_data) {
            $c->log->error("user does not have billing data rights");
            $self->error($c, HTTP_FORBIDDEN, "Unsufficient rights to create voucher");
            last;
        }
    
        $resource = $self->get_valid_post_data(
            c => $c, 
            media_type => 'application/json',
        );
        last unless $resource;

        my $form = $self->get_form($c);
        last unless $self->validate_form(
            c => $c,
            resource => $resource,
            form => $form,
            exceptions => [qw/subscriber_id/],
        );

        last unless NGCP::Panel::Utils::Voucher::check_topup(c => $c,
                    now => $now,
                    subscriber_id => $resource->{subscriber_id},
                    plain_code => $resource->{code},
                    resource => $resource,
                    entities => $entities,
                    err_code => sub {
                        my ($err) = @_;
                        #$c->log->error($err);
                        $self->error($c, HTTP_UNPROCESSABLE_ENTITY, $err);
                        },
                    );
       
        try {
            my $balance = NGCP::Panel::Utils::ProfilePackages::topup_contract_balance(c => $c,
                contract => $entities->{contract},
                voucher => $entities->{voucher},
                log_vals => $log_vals,
                now => $now,
                request_token => $resource->{request_token},
                subscriber => $entities->{subscriber},
            );

            $entities->{voucher}->update({
                used_by_subscriber_id => $resource->{subscriber_id},
                used_at => $now,
            });
        } catch($e) {
            $c->log->error("failed to create voucher topup: $e"); # TODO: user, message, trace, ...
            $self->error($c, HTTP_INTERNAL_SERVER_ERROR, "Failed to create voucher topup.");
            last;
        }

        $guard->commit;
        $success = 1;

        $c->response->status(HTTP_NO_CONTENT);
        $c->response->body(q());
    }
    undef $guard;
    $guard = $c->model('DB')->txn_scope_guard;
    {
        try {
            my $topup_log = NGCP::Panel::Utils::ProfilePackages::create_topup_log_record(
                c => $c,
                is_cash => 0,
                now => $now,
                entities => $entities,
                log_vals => $log_vals,
                resource => $resource,
                is_success => $success
            );
        } catch($e) {
            $c->log->error("failed to create topup log record: $e");
            last;
        }
        $guard->commit;
    }
    return;
}

sub end : Private {
    my ($self, $c) = @_;

    $self->log_response($c);
}

sub get_form {
    my ($self, $c) = @_;
    return NGCP::Panel::Form::Topup::VoucherAPI->new(ctx => $c);
}

no Moose;
1;

# vim: set tabstop=4 expandtab:
