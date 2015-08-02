package NGCP::Panel::Controller::API::Root;
use Sipwise::Base;
use namespace::sweep;
use Encode qw(encode);
use Clone qw/clone/;
use HTTP::Headers qw();
use HTTP::Response qw();
use HTTP::Status qw(:constants);
use MooseX::ClassAttribute qw(class_has);
use File::Find::Rule;
use JSON qw(to_json);
use Safe::Isa qw($_isa);
BEGIN { extends 'Catalyst::Controller'; }
require Catalyst::ActionRole::ACL;
require Catalyst::ActionRole::CheckTrailingSlash;
require Catalyst::ActionRole::HTTPMethods;
require Catalyst::ActionRole::RequireSSL;

with 'NGCP::Panel::Role::API';

class_has('dispatch_path', is => 'ro', default => '/api/');

__PACKAGE__->config(
    action => {
        map { $_ => {
            ACLDetachTo => 'invalid_user',
            AllowedRole => [qw/admin reseller/],
            Args => 0,
            Does => [qw(ACL CheckTrailingSlash RequireSSL)],
            Method => $_,
            Path => __PACKAGE__->dispatch_path,
        } } @{ __PACKAGE__->allowed_methods },
    },
    action_roles => [qw(HTTPMethods)],
);

sub auto :Private {
    my ($self, $c) = @_;

    $self->set_body($c);
    $self->log_request($c);
    return 1;
}

sub GET : Allow {
    my ($self, $c) = @_;

    my $blacklist = {
        "DomainPreferenceDefs" => 1,
        "SubscriberPreferenceDefs" => 1,
        "CustomerPreferenceDefs" => 1,
        "ProfilePreferenceDefs" => 1,
    };

    my @colls = $self->get_collections;
    foreach my $coll(@colls) {
        my $mod = $coll;
        $mod =~ s/^.+\/([a-zA-Z0-9_]+)\.pm$/$1/;
        next if(exists $blacklist->{$mod});
        my $rel = lc $mod;
        my $full_mod = 'NGCP::Panel::Controller::API::'.$mod;
        my $full_item_mod = 'NGCP::Panel::Controller::API::'.$mod.'Item';

        my $role = $full_mod->config->{action}->{OPTIONS}->{AllowedRole};
        if(ref $role eq "ARRAY") {
            next unless grep @{ $role }, $c->user->roles;
        } else {
            next unless $role && $role eq $c->user->roles;
        }

        my $query_params = [];
        if($full_mod->can('query_params')) {
            $query_params = $full_mod->query_params;
        }
        my $actions = [];
        if($c->user->read_only) {
            foreach my $m(keys %{ $full_mod->config->{action} }) {
                next unless $m =~ /^(GET|HEAD|OPTIONS)$/;
                push @{ $actions }, $m;
            }
        } else {
            $actions = [ keys %{ $full_mod->config->{action} } ];
        }
        my $item_actions = [];
        if($full_item_mod->can('config')) {
            if($c->user->read_only) {
                foreach my $m(keys %{ $full_item_mod->config->{action} }) {
                    next unless $m =~ /^(GET|HEAD|OPTIONS)$/;
                    push @{ $item_actions }, $m;
                }
            } else {
                $item_actions = [ keys %{ $full_item_mod->config->{action} } ];
            }
        }

        my $form = $full_mod->get_form($c);

        my $sorting_cols = [];
        my $item_rs;
        try {
            $item_rs = $full_mod->item_rs($c, "");
        }
        if ($item_rs) {
            $sorting_cols = [$item_rs->result_source->columns];
        }

        $c->stash->{collections}->{$rel} = {
            name => $mod, 
            description => $full_mod->api_description,
            fields => $form ? $self->get_collection_properties($form) : [],
            query_params => $query_params,
            actions => $actions,
            item_actions => $item_actions,
            sorting_cols => $sorting_cols,
            uri => "/api/$rel/",
            sample => $full_mod->can('documentation_sample') # generate pretty json, but without outer brackets (this is tricky though)
                ? to_json($full_mod->documentation_sample, {pretty => 1}) =~ s/(^\s*{\s*)|(\s*}\s*$)//rg =~ s/\n   /\n/rg
                : undef,
        };

    }

    $c->stash(template => 'api/root.tt');
    $c->forward($c->view);
    $c->response->headers(HTTP::Headers->new(
        Content_Language => 'en',
        Content_Type => 'application/xhtml+xml',
        #$self->collections_link_headers,
    ));
    return;
}

sub HEAD : Allow {
    my ($self, $c) = @_;
    $c->forward(qw(GET));
    $c->response->body(q());
    return;
}

sub OPTIONS : Allow {
    my ($self, $c) = @_;
    my $allowed_methods = $self->allowed_methods_filtered($c);
    $c->response->headers(HTTP::Headers->new(
        Allow => $allowed_methods->join(', '),
        $self->collections_link_headers,
    ));
    $c->response->content_type('application/json');
    $c->response->body(JSON::to_json({ methods => $allowed_methods })."\n");
    return;
}

sub get_collections {
    my ($self) = @_;

    # figure out base path of our api modules
    my $libpath = $INC{"NGCP/Panel/Controller/API/Root.pm"};
    $libpath =~ s/Root\.pm$//;

    # find all modules not called Root.pm and *Item.pm
    # (which should then be just collections)
    my $rootrule = File::Find::Rule->new->name('Root.pm');
    my $itemrule = File::Find::Rule->new->name('*Item.pm');
    my $rule = File::Find::Rule->new
        ->mindepth(1)
        ->maxdepth(1)
        ->name('*.pm')
        ->not($rootrule)
        ->not($itemrule);
    my @colls = $rule->in($libpath);

    return @colls;
}

sub collections_link_headers : Private {
    my ($self) = @_;

    my @colls = $self->get_collections;

    # create Link header for each of the collections
    my @links = ();
    foreach my $mod(@colls) {
        # extract file base from path (e.g. Foo from lib/something/Foo.pm)
        $mod =~ s/^.+\/([a-zA-Z0-9_]+)\.pm$/$1/;
        my $rel = lc $mod;
        $mod = 'NGCP::Panel::Controller::API::'.$mod;
        my $dp = $mod->dispatch_path;
        push @links, Link => '<'.$dp.'>; rel="collection http://purl.org/sipwise/ngcp-api/#rel-'.$rel.'"';
    }
    return @links;
}

sub invalid_user : Private {
    my ($self, $c, $ssl_client_m_serial) = @_;
    #$self->error($c, HTTP_FORBIDDEN, "Invalid certificate serial number '$ssl_client_m_serial'.");
    $self->error($c, HTTP_FORBIDDEN, "Invalid user");
    return;
}

sub field_to_json : Private {
    my ($self, $name) = @_;

    SWITCH: for ($name) {
        /Float|Integer|Money|PosInteger|Minute|Hour|MonthDay|Year/ &&
            return "Number";
        /Boolean/ &&
            return "Boolean";
        /Repeatable/ &&
            return "Array";
        /\+NGCP::Panel::Field::Regex/ &&
             return "String";
        /\+NGCP::Panel::Field::Country/ &&
             return "String";
        /\+NGCP::Panel::Field::EmailList/ &&
             return "String";
        /\+NGCP::Panel::Field::Identifier/ &&
            return "String";
        /\+NGCP::Panel::Field::SubscriberStatusSelect/ &&
            return "String";
        /\+NGCP::Panel::Field::SubscriberLockSelect/ &&
            return "Number";
        /\+NGCP::Panel::Field::E164/ &&
            return "Object";
        /Compound/ &&
            return "Object";
        /\+NGCP::Panel::Field::AliasNumber/ &&
            return "Array";
        /\+NGCP::Panel::Field::PbxGroupAPI/ &&
            return "Array";
        /\+NGCP::Panel::Field::PbxGroupMemberAPI/ &&
            return "Array";
        # usually {xxx}{id}
        /\+NGCP::Panel::Field::/ &&
            return "Number";
        # default
        return "String";
    } # SWITCH
}

sub field_to_select_options : Private {
    my ($self, $field) = @_;
    return join('|',map {
        my $value = $_->{value};
        my $label = $_->{label};
        my $s = defined $value ? "'".$value."'" : 'null';
        if (defined $label && length($label)) {
            if (!defined $value || (lc($value) ne lc($label))) {
                $s.=' ('.$label.')';
            }
        }
        $s;
    } @{$field->options});
    
}
sub get_field_poperties :Private{
    my ($self, $field) = @_;
    my $name = $field->name;
    return () if (
        $field->type eq "Hidden" ||
        $field->type eq "Button" ||
        $field->type eq "Submit" ||
        0);
    my @types = ();
    push @types, 'null' unless ($field->required || $field->validate_when_empty);
    my $type;
    if($field->type =~ /^\+NGCP::Panel::Field::/) {
        if($field->type =~ /E164/) {
            $name = 'primary_number';
        } elsif($field->type =~ /AliasNumber/) {
            $name = 'alias_numbers';
        } elsif($field->type =~ /PbxGroupAPI/) {
            $name = 'pbx_group_ids';
        } elsif($field->type =~ /Country$/) {
            $name = 'country';
        #} elsif($field->type !~ /Regex|EmailList|SubscriberStatusSelect|SubscriberLockSelect|Identifier|PosInteger/) {
        #    $name .= '_id';
        #}
        } elsif($field->type =~ /Select$/) {
            $type = $self->field_to_select_options($field);
        } elsif($field->type !~ /Regex|EmailList|Identifier|PosInteger|DateTime/) { #Interval, IPAddress, ...?
            $name .= '_id';
        }
    } elsif ($field->$_isa('HTML::FormHandler::Field::Select')) {
        $type = $self->field_to_select_options($field);
    } 
    push(@types, defined $type ? $type : $self->field_to_json($field->type));
    my $desc;
    if($field->element_attr) {
        $desc = $field->element_attr->{title}->[0];
    } else {
        $desc = $name;
    }
    return { name => $name, description => $desc, types => \@types };
}
sub get_collection_properties {
    my ($self, $form) = @_;

    my $renderlist = $form->form->blocks->{fields}->{render_list};
    my %renderlist = defined $renderlist ? map { $_ => 1 } @{$renderlist} : ();
    
    my @props = ();
    foreach my $f($form->fields) {
        my $name = $f->name;
        next if (defined $renderlist && !exists $renderlist{$name});
        push @props, $self->get_field_poperties($f);
        if(my $spec = $f->element_attr->{implicit_parameter}){
            my $f_implicit = clone($f);
            foreach my $field_attribute (keys %{$spec}){
                $f_implicit->$field_attribute($spec->{$field_attribute});
            }
            push @props, $self->get_field_poperties($f_implicit);
        }
    }
    @props = sort{$a->{name} cmp $b->{name}} @props;
    return \@props;
}

sub end : Private {
    my ($self, $c) = @_;
    
    #$self->log_response($c);
    return 1;
}

# vim: set tabstop=4 expandtab:
