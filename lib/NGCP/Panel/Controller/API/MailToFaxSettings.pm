package NGCP::Panel::Controller::API::MailToFaxSettings;
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
    return [qw/GET OPTIONS HEAD/];
}

sub api_description {
    return 'Specifies mail to fax settings for a specific subscriber.';
}

sub query_params {
    return [
        {
            param => 'active',
            description => 'Filter for items (subscribers) with active mail to fax settings',
            query => {
                first => sub {
                    my $q = shift;
                    if ($q) {
                        { 'voip_mail_to_fax_preference.active' => 1 };
                    } else {
                        {};
                    }
                },
                second => sub {
                    { prefetch => { 'provisioning_voip_subscriber' => 'voip_mail_to_fax_preference' } };
                },
            },
        },
        {
            param => 'secret_key_renew',
            description => 'Filter for items (subscribers) where secret_key_renew field matches given pattern',
            query => {
                first => sub {
                    my $q = shift;
                    if ($q) {
                        { 'voip_mail_to_fax_preference.secret_key_renew' => $q };
                    } else {
                        {};
                    }
                },
                second => sub {
                    return { prefetch => { 'provisioning_voip_subscriber' => 'voip_mail_to_fax_preference' } };
                },
            },
        },
    ];
}

use parent qw/Catalyst::Controller NGCP::Panel::Role::API::MailToFaxSettings/;

sub resource_name{
    return 'mailtofaxsettings';
}
sub dispatch_path{
    return '/api/mailtofaxsettings/';
}
sub relation{
    return 'http://purl.org/sipwise/ngcp-api/#rel-mailtofaxsettings';
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
    return 1;
}

sub GET :Allow {
    my ($self, $c) = @_;
    my $page = $c->request->params->{page} // 1;
    my $rows = $c->request->params->{rows} // 10;
    {
        my $cfs = $self->item_rs($c);
        (my $total_count, $cfs) = $self->paginate_order_collection($c, $cfs);
        my (@embedded, @links);
        for my $cf ($cfs->all) {
            try {
                push @embedded, $self->hal_from_item($c, $cf);
                push @links, Data::HAL::Link->new(
                    relation => 'ngcp:'.$self->resource_name,
                    href     => sprintf('%s%s', $self->dispatch_path, $cf->id),
                );
            }
        }
        push @links,
            Data::HAL::Link->new(
                relation => 'curies',
                href => 'http://purl.org/sipwise/ngcp-api/#rel-{rel}',
                name => 'ngcp',
                templated => true,
            ),
            Data::HAL::Link->new(relation => 'profile', href => 'http://purl.org/sipwise/ngcp-api/'),
            $self->collection_nav_links($c, $page, $rows, $total_count, $c->request->path, $c->request->query_params);

        my $hal = Data::HAL->new(
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

sub end : Private {
    my ($self, $c) = @_;

    $self->log_response($c);
    return 1;
}

1;

# vim: set tabstop=4 expandtab:
