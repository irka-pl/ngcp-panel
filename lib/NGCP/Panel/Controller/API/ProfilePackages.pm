package NGCP::Panel::Controller::API::ProfilePackages;
use NGCP::Panel::Utils::Generic qw(:all);

use Sipwise::Base;

use boolean qw(true);
use Data::HAL qw();
use Data::HAL::Link qw();
use HTTP::Headers qw();
use HTTP::Status qw(:constants);

use NGCP::Panel::Utils::Reseller qw();
use NGCP::Panel::Utils::ProfilePackages qw();

sub allowed_methods{
    return [qw/GET POST OPTIONS HEAD/];
}

sub api_description {
    return 'Containers of settings for <a href="#customerbalances">Customer Balances</a> and <a href="#billingprofiles">Billing Profiles</a> to be applied to <a href="#customers">Customers</a>.';
};

sub query_params {
    return [
        {
            param => 'reseller_id',
            description => 'Filter for profile packages belonging to a specific reseller',
            query => {
                first => sub {
                    my $q = shift;
                    { reseller_id => $q };
                },
                second => sub {},
            },
        },
        {
            param => 'name',
            description => 'Filter for profile packages with a specific name',
            query => {
                first => sub {
                    my $q = shift;
                    { name => { like => $q } };
                },
                second => sub {},
            },
        },
        {
            param => 'profile_name',
            description => 'Filter for profile packages containing a billing profile with specific name',
            query => {
                first => sub {
                    my $q = shift;
                    { 'billing_profile.name' => { like => $q } };
                },
                second => sub {
                    return { join => { profiles => 'billing_profile' },
                             group_by => 'me.id', }                    
                },
            },
        },
        {
            param => 'network_name',
            description => 'Filter for profile packages containing a billing network with specific name',
            query => {
                first => sub {
                    my $q = shift;
                    { 'billing_network.name' => { like => $q } };
                },
                second => sub {
                    return { join => { profiles => 'billing_network' },
                             group_by => 'me.id', }                    
                },
            },
        },    ];
}

use parent qw/NGCP::Panel::Role::Entities NGCP::Panel::Role::API::ProfilePackages/;

sub resource_name{
    return 'profilepackages';
}

sub dispatch_path{
    return '/api/profilepackages/';
}

sub relation{
    return 'http://purl.org/sipwise/ngcp-api/#rel-profilepackages';
}

__PACKAGE__->set_config({
    allowed_roles => [qw/admin reseller ccareadmin ccare/],
});

sub GET :Allow {
    my ($self, $c) = @_;
    my $page = $c->request->params->{page} // 1;
    my $rows = $c->request->params->{rows} // 10;
    {
        my $packages = $self->item_rs($c);
        (my $total_count, $packages, my $packages_rows) = $self->paginate_order_collection($c, $packages);
        my (@embedded, @links);
        my $form = $self->get_form($c);
        for my $package (@$packages_rows) {
            push @embedded, $self->hal_from_item($c, $package, "profilepackages", $form);
            push @links, Data::HAL::Link->new(
                relation => 'ngcp:'.$self->resource_name,
                href     => sprintf('/%s%d', $c->request->path, $package->id),
            );
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

sub POST :Allow {
    my ($self, $c) = @_;

    my $guard = $c->model('DB')->txn_scope_guard;
    {
        if ($c->user->roles eq "ccareadmin" || $c->user->roles eq "ccare") {
            $self->error($c, HTTP_FORBIDDEN, "Read-only resource for authenticated role");
            last;
        }

        my $schema = $c->model('DB');
        my $resource = $self->get_valid_post_data(
            c => $c, 
            media_type => 'application/json',
        );
        last unless $resource;

        if($c->user->roles eq "admin") {
        } elsif($c->user->roles eq "reseller") {
            $resource->{reseller_id} = $c->user->reseller_id;
        }

        my $form = $self->get_form($c);
        $resource->{reseller_id} //= undef;
        last unless $self->validate_form(
            c => $c,
            resource => $resource,
            form => $form,
        );
        
        last unless NGCP::Panel::Utils::Reseller::check_reseller_create_item($c,$resource->{reseller_id},sub {
            my ($err) = @_;
            $self->error($c, HTTP_UNPROCESSABLE_ENTITY, $err);
        });            

        my $mappings_to_create = [];
        last unless NGCP::Panel::Utils::ProfilePackages::prepare_profile_package(
            c => $c,
            resource => $resource,
            mappings_to_create => $mappings_to_create,
            err_code => sub {
                my ($err) = @_;
                #$c->log->error($err);
                $self->error($c, HTTP_UNPROCESSABLE_ENTITY, $err);
            });
             
        my $profile_package;
        try {
            $profile_package = $schema->resultset('profile_packages')->create($resource);
            foreach my $mapping (@$mappings_to_create) {
                $profile_package->profiles->create($mapping); 
            }
        } catch($e) {
            $c->log->error("failed to create profile package: $e"); # TODO: user, message, trace, ...
            $self->error($c, HTTP_INTERNAL_SERVER_ERROR, "Failed to create profile package.");
            last;
        }
        
        last unless $self->add_create_journal_item_hal($c,sub {
            my $self = shift;
            my ($c) = @_;
            my $_profile_package = $self->item_by_id($c, $profile_package->id);
            return $self->hal_from_item($c, $profile_package,"profilepackages"); });

        $guard->commit;

        $c->response->status(HTTP_CREATED);
        $c->response->header(Location => sprintf('%s%d', $self->dispatch_path, $profile_package->id));
        $c->response->body(q());
    }
    return;
}

1;

# vim: set tabstop=4 expandtab:
