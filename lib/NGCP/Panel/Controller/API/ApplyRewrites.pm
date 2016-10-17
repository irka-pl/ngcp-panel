package NGCP::Panel::Controller::API::ApplyRewrites;
use NGCP::Panel::Utils::Generic qw(:all);

use Sipwise::Base;

use boolean qw(true);
use Data::HAL qw();
use Data::HAL::Link qw();
use HTTP::Headers qw();
use HTTP::Status qw(:constants);

require Catalyst::ActionRole::ACL;
require Catalyst::ActionRole::CheckTrailingSlash;
require NGCP::Panel::Role::HTTPMethods;
require Catalyst::ActionRole::RequireSSL;

sub allowed_methods{
    return [qw/POST OPTIONS/];
}

use parent qw/NGCP::Panel::Role::Entities NGCP::Panel::Role::API::ApplyRewrites/;

sub api_description {
    return 'Applies rewrite rules to a given number according to the given direction. It can for example be used to normalize user input to E164 using callee_in direction, or to denormalize E164 to user output using caller_out.';
};

sub query_params {
    return [
    ];
}

sub resource_name{
    return 'applyrewrites';
}
sub dispatch_path{
    return '/api/applyrewrites/';
}
sub relation{
    return 'http://purl.org/sipwise/ngcp-api/#rel-applyrewrites';
}

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
    my $guard = $c->model('DB')->txn_scope_guard;
    {
        my $resource = $self->get_valid_post_data(
            c => $c, 
            media_type => 'application/json',
        );
        last unless $resource;

        my $form = $self->get_form($c);
        last unless $self->validate_form(
            c => $c,
            resource => $resource,
            form => $form,
        );

        my $subscriber_rs = $c->model('DB')->resultset('voip_subscribers')->search({
            'me.id' => $resource->{subscriber_id},
            'me.status' => { '!=' => 'terminated' },
        });
        if($c->user->roles eq "admin") {
        } elsif($c->user->roles eq "reseller") {
            $subscriber_rs = $subscriber_rs->search({
                'contact.reseller_id' => $c->user->reseller_id,
            },{
                join => { contract => 'contact' },
            });
        }
        my $subscriber = $subscriber_rs->first;
        unless($subscriber) {
            $c->log->error("invalid subscriber id $$resource{subscriber_id} for outbound call");
            $self->error($c, HTTP_NOT_FOUND, "Calling subscriber not found.");
            last;
        }

        my $normalized;
        try {

            $normalized = NGCP::Panel::Utils::Subscriber::apply_rewrite(
                c => $c, subscriber => $subscriber, 
                number => $resource->{number}, direction => $resource->{direction},
            );
        } catch($e) {
            $c->log->error("failed to rewrite number: $e");
            $self->error($c, HTTP_INTERNAL_SERVER_ERROR, "Failed to rewrite number.");
            last;
        }

        $guard->commit;

        my $res = '{ "result": "'.$normalized.'" }'."\n";

        $c->response->status(HTTP_OK);
        $c->response->body($res);
    }
    return;
}


sub end : Private {
    my ($self, $c) = @_;

    $self->log_response($c);
}

1;

# vim: set tabstop=4 expandtab:
