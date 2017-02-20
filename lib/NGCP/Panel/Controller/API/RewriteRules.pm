package NGCP::Panel::Controller::API::RewriteRules;
use NGCP::Panel::Utils::Generic qw(:all);

use Sipwise::Base;

use boolean qw(true);
use NGCP::Panel::Utils::DataHal qw();
use NGCP::Panel::Utils::DataHalLink qw();
use HTTP::Headers qw();
use HTTP::Status qw(:constants);

use NGCP::Panel::Utils::DateTime;
use NGCP::Panel::Utils::Rewrite;
require Catalyst::ActionRole::ACL;
require Catalyst::ActionRole::CheckTrailingSlash;
require NGCP::Panel::Role::HTTPMethods;
require Catalyst::ActionRole::RequireSSL;

sub allowed_methods{
    return [qw/GET POST OPTIONS HEAD/];
}

sub api_description {
    return 'Defines a set of Rewrite Rules which are grouped in <a href="#rewriterulesets">Rewrite Rule Sets</a>. They can be used to alter incoming and outgoing numbers.';
};

sub query_params {
    return [
        {
            param => 'description',
            description => 'Filter rules for a certain description (wildcards possible).',
            query => {
                first => sub {
                    my $q = shift;
                    return { description => { like => $q } };
                },
                second => sub {},
            },
        },
        {
            param => 'set_id',
            description => 'Filter for rules belonging to a specific rewriteruleset.',
            query => {
                first => sub {
                    my $q = shift;
                    return { set_id => $q };
                },
                second => sub {},
            },
        },
        {
            param => 'reseller_id',
            description => 'Filter for rules belonging to a specific reseller.',
            query => {
                first => sub {
                    my $q = shift;
                    return { set_id => $q };
                },
                second => sub {},
            },
        },
    ];
}


use parent qw/Catalyst::Controller NGCP::Panel::Role::API::RewriteRules/;

sub resource_name{
    return 'rewriterules';
}
sub dispatch_path{
    return '/api/rewriterules/';
}
sub relation{
    return 'http://purl.org/sipwise/ngcp-api/#rel-rewriterules';
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
        } } @{ __PACKAGE__->allowed_methods },
    },
    action_roles => [qw(+NGCP::Panel::Role::HTTPMethods)],
);

sub auto :Private {
    my ($self, $c) = @_;

    $self->set_body($c);
    $self->log_request($c);
    return 1;
}

sub GET :Allow {
    my ($self, $c) = @_;
    my $page = $c->request->params->{page} // 1;
    my $rows = $c->request->params->{rows} // 10;
    {
        my $rules = $self->item_rs($c, "rules");

        (my $total_count, $rules) = $self->paginate_order_collection($c, $rules);
        my (@embedded, @links);
        for my $rule ($rules->all) {
            push @embedded, $self->hal_from_item($c, $rule, "rewriterules");
            push @links, NGCP::Panel::Utils::DataHalLink->new(
                relation => 'ngcp:'.$self->resource_name,
                href     => sprintf('%s%d', $self->dispatch_path, $rule->id),
            );
        }
        push @links,
            NGCP::Panel::Utils::DataHalLink->new(
                relation => 'curies',
                href => 'http://purl.org/sipwise/ngcp-api/#rel-{rel}',
                name => 'ngcp',
                templated => true,
            ),
            NGCP::Panel::Utils::DataHalLink->new(relation => 'profile', href => 'http://purl.org/sipwise/ngcp-api/'),
            NGCP::Panel::Utils::DataHalLink->new(relation => 'self', href => sprintf('%s?page=%s&rows=%s', $self->dispatch_path, $page, $rows));
        if(($total_count / $rows) > $page ) {
            push @links, NGCP::Panel::Utils::DataHalLink->new(relation => 'next', href => sprintf('%s?page=%d&rows=%d', $self->dispatch_path, $page + 1, $rows));
        }
        if($page > 1) {
            push @links, NGCP::Panel::Utils::DataHalLink->new(relation => 'prev', href => sprintf('%s?page=%d&rows=%d', $self->dispatch_path, $page - 1, $rows));
        }

        my $hal = NGCP::Panel::Utils::DataHal->new(
            embedded => [@embedded],
            links => [@links],
        );
        $hal->resource({
            total_count => $total_count,
        });
        my $response = HTTP::Response->new(HTTP_OK, undef,
            HTTP::Headers->new($hal->http_headers(skip_links => 1)), $hal->as_json);
        $c->response->headers($response->headers);
        $c->response->body($response->content);
        return;
    }
    return;
}

sub HEAD :Allow {
    my ($self, $c) = @_;
    $c->forward(qw(GET));
    $c->response->body(q());
    return;
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
        my $schema = $c->model('DB');
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
            exceptions => [qw/set_id/],
        );

        $resource->{match_pattern} = $form->values->{match_pattern};
        $resource->{replace_pattern} = $form->values->{replace_pattern};

        my $rule;

        unless(defined $resource->{set_id}) {
            $self->error($c, HTTP_UNPROCESSABLE_ENTITY, "Required: 'set_id'");
            last;
        }

        my $reseller_id;
        if($c->user->roles eq "reseller") {
            $reseller_id = $c->user->reseller_id;
        }

        my $ruleset = $schema->resultset('voip_rewrite_rule_sets')->find({
                id => $resource->{set_id},
                ($reseller_id ? (reseller_id => $reseller_id) : ()),
            });
        unless($ruleset) {
            $self->error($c, HTTP_UNPROCESSABLE_ENTITY, "Invalid 'set_id'.");
            last;
        }
        try {
            $rule = $schema->resultset('voip_rewrite_rules')->create($resource);
        } catch($e) {
            $c->log->error("failed to create rewriterule: $e"); # TODO: user, message, trace, ...
            $self->error($c, HTTP_INTERNAL_SERVER_ERROR, "Failed to create rewriterule.");
            last;
        }

        $guard->commit;
        NGCP::Panel::Utils::Rewrite::sip_dialplan_reload($c);

        $c->response->status(HTTP_CREATED);
        $c->response->header(Location => sprintf('/%s%d', $c->request->path, $rule->id));
        $c->response->body(q());
    }
    return;
}

sub end : Private {
    my ($self, $c) = @_;

    $self->log_response($c);
    return 1;
}

1;

# vim: set tabstop=4 expandtab:
