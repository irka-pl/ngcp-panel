package NGCP::Panel::Controller::API::Root;
use NGCP::Panel::Utils::Generic qw(:all);

use Sipwise::Base;

use Encode qw(encode);
use Clone qw/clone/;
use HTTP::Headers qw();
use HTTP::Response qw();
use HTTP::Status qw(:constants);
use File::Find::Rule;
use JSON qw(to_json);
use Safe::Isa qw($_isa);
use NGCP::Panel::Utils::API;
use parent qw/Catalyst::Controller NGCP::Panel::Role::API/;
require Catalyst::ActionRole::ACL;
require Catalyst::ActionRole::CheckTrailingSlash;
require NGCP::Panel::Role::HTTPMethods;
require Catalyst::ActionRole::RequireSSL;

use NGCP::Panel::Utils::Journal qw();

#with 'NGCP::Panel::Role::API';

sub dispatch_path{return '/api/';}

sub allowed_methods{
    return [qw/GET OPTIONS HEAD/];
}

__PACKAGE__->config(
    action => {
        map { $_ => {
            ACLDetachTo => 'invalid_user',
            AllowedRole => [qw/admin reseller subscriberadmin subscriber/],
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

sub GET : Allow {
    my ($self, $c) = @_;

    my $blacklist = {
        "DomainPreferenceDefs" => 1,
        "SubscriberPreferenceDefs" => 1,
        "CustomerPreferenceDefs" => 1,
        "ProfilePreferenceDefs" => 1,
        "PeeringServerPreferenceDefs" => 1,
        "PbxDevicePreferenceDefs" => 1,
        "PbxDeviceProfilePreferenceDefs" => 1,
        "MetaConfigDefs" => 1,
    };

    my $colls = NGCP::Panel::Utils::API::get_collections_files;
    my %user_roles = map {$_ => 1} $c->user->roles;
    foreach my $coll(@$colls) {
        my $mod = $coll;
        $mod =~ s/^.+\/([a-zA-Z0-9_]+)\.pm$/$1/;
        next if(exists $blacklist->{$mod});
        my $rel = lc $mod;
        my $full_mod = 'NGCP::Panel::Controller::API::'.$mod;
        my $full_item_mod = 'NGCP::Panel::Controller::API::'.$mod.'Item';

        my $role = $full_mod->config->{action}->{OPTIONS}->{AllowedRole};
        if(ref $role eq "ARRAY") {
            next unless grep { $user_roles{$_}; } @{ $role };
        } else {
            next unless $user_roles{$role};
        }

        my $query_params = [];
        if($full_mod->can('query_params')) {
            $query_params = $full_mod->query_params;
        }
        my $actions = [];
        if($c->user->read_only) {
            foreach my $m(sort keys %{ $full_mod->config->{action} }) {
                next unless $m =~ /^(GET|HEAD|OPTIONS)$/;
                push @{ $actions }, $m;
            }
        } else {
            $actions = [ sort keys %{ $full_mod->config->{action} } ];
        }
        my $uri = "/api/$rel/";
        my $item_actions = [];
        my $journal_resource_config = {};
        if($full_item_mod->can('config')) {
            if($c->user->read_only) {
                foreach my $m(sort keys %{ $full_item_mod->config->{action} }) {
                    next unless $m =~ /^(GET|HEAD|OPTIONS)$/;
                    push @{ $item_actions }, $m;
                }
            } else {
                foreach my $m(sort keys %{ $full_item_mod->config->{action} }) {
                    next unless $m =~ /^(GET|HEAD|OPTIONS|PUT|PATCH|DELETE)$/;
                    push @{ $item_actions }, $m;
                }
            }
            if($full_item_mod->can('resource_name')) {
                my @operations = ();
                my $op_config = {};
                my $resource_name = $full_item_mod->resource_name;
                $journal_resource_config = NGCP::Panel::Utils::Journal::get_journal_resource_config($c->config,$resource_name);
                if (exists $full_mod->config->{action}->{POST}) {
                    $op_config = NGCP::Panel::Utils::Journal::get_api_journal_op_config($c->config,$resource_name,NGCP::Panel::Utils::Journal::CREATE_JOURNAL_OP);
                    if ($op_config->{operation_enabled}) {
                        push(@operations,"create (<span>POST $uri</span>)");
                    }
                }
                my $item_action_config = $full_item_mod->config->{action};
                if (exists $item_action_config->{PUT} || exists $item_action_config->{PATCH}) {
                    $op_config = NGCP::Panel::Utils::Journal::get_api_journal_op_config($c->config,$resource_name,NGCP::Panel::Utils::Journal::UPDATE_JOURNAL_OP);
                    if ($op_config->{operation_enabled}) {
                        if (exists $item_action_config->{PUT} && exists $item_action_config->{PATCH}) {
                            push(@operations,"update (<span>PUT/PATCH $uri"."id</span>)");
                        } elsif (exists $item_action_config->{PUT}) {
                            push(@operations,"update (<span>PUT $uri"."id</span>)");
                        } elsif (exists $item_action_config->{PATCH}) {
                            push(@operations,"update (<span>PATCH $uri"."id</span>)");
                        }
                    }
                }
                if (exists $item_action_config->{DELETE}) {
                    $op_config = NGCP::Panel::Utils::Journal::get_api_journal_op_config($c->config,$resource_name,NGCP::Panel::Utils::Journal::CREATE_JOURNAL_OP);
                    if ($op_config->{operation_enabled}) {
                        push(@operations,"delete (<span>DELETE $uri"."id</span>)");
                    }
                }
                $journal_resource_config->{operations} = \@operations;
                $journal_resource_config->{format} = $op_config->{format};
                $journal_resource_config->{uri} = 'api/' . $resource_name . '/id/' . NGCP::Panel::Utils::Journal::API_JOURNAL_RESOURCE_NAME . '/';
                $journal_resource_config->{query_params} = ($full_item_mod->can('journal_query_params') ? $full_item_mod->journal_query_params : []);
                $journal_resource_config->{sorting_cols} = NGCP::Panel::Utils::Journal::JOURNAL_FIELDS;
                $journal_resource_config->{item_uri} = $journal_resource_config->{uri} . 'journalitemid';
                if (length(NGCP::Panel::Utils::Journal::API_JOURNALITEMTOP_RESOURCE_NAME) > 0) {
                    $journal_resource_config->{recent_uri} = $journal_resource_config->{uri} . NGCP::Panel::Utils::Journal::API_JOURNALITEMTOP_RESOURCE_NAME;
                }
            }
        }

        my ($form) = $full_mod->get_form($c);

        my $sorting_cols = [];
        if (my $order_by_cols = eval { $full_mod->order_by_cols(); }) {
            $sorting_cols = [ sort keys %$order_by_cols ];
        } else {
            my $item_rs;
            try {
                $item_rs = $full_mod->item_rs($c, "");
            }
            if ($item_rs) {
                if(ref $item_rs eq "ARRAY") {
                    $sorting_cols = [map { $_->{name} } @{ $item_rs }];
                } else {
                    $sorting_cols = [$item_rs->result_source->columns];
                }
            }
        }
        my ($form_fields,$form_fields_upload) = $form ? $self->get_collection_properties($form) : ([],[]);

        my $documentation_sample = {} ;
        my $documentation_sample_process = sub{
            my $s = shift;
            $s = to_json($s, {pretty => 1}) =~ s/(^\s*{\s*)|(\s*}\s*$)//rg =~ s/\n   /\n/rg;
            return $s;
        };
        if($full_mod->can('documentation_sample')){
            $documentation_sample->{sample_orig}->{default} = $full_mod->documentation_sample;
            $documentation_sample->{sample}->{default} = $documentation_sample_process->($documentation_sample->{sample_orig}->{default});
        }
        foreach my $action (qw/create update/){
            my $method = 'documentation_sample_'.$action;
            if($full_mod->can($method)){
                $documentation_sample->{sample_orig}->{$action} = $full_mod->$method;
                $documentation_sample->{sample}->{$action} = $documentation_sample_process->($documentation_sample->{sample_orig}->{$action});
            }
        }

        $c->stash->{collections}->{$rel} = {
            name => $mod,
            entity_name => $mod =~ s/s$//r,
            description => $full_mod->api_description,
            fields => $form_fields,
            uploads => $form_fields_upload,
            config => $full_mod->config ,
            query_params => $query_params,
            actions => $actions,
            item_actions => $item_actions,
            sorting_cols => $sorting_cols,
            uri => $uri,
            properties => ( $full_mod->can('properties') ?  $full_mod->properties : {} ),#
            %$documentation_sample,
            journal_resource_config => $journal_resource_config,
        };

    }

    if ($user_roles{subscriber} || $user_roles{subscriberadmin}) {
        $c->stash(is_subscriber_api => 1);
    } else {
        $c->stash(is_admin_api => 1);
    }

    if($c->req->header('Accept') && $c->req->header('Accept') eq 'application/json') {
        my $body = {};
        foreach my $rel(sort keys %{ $c->stash->{collections} }) {
            my $r = $c->stash->{collections}->{$rel};
            foreach my $k(qw/
                    actions item_actions fields sorting_cols
            /) {
                $body->{$rel}->{$k} = $r->{$k};
            }
            $body->{$rel}->{query_params} = [
                map { $_->{param} } @{ $r->{query_params} }
            ];
        }
        $c->response->body(JSON::to_json($body, { pretty => 1 }));
        $c->response->headers(HTTP::Headers->new(
            Content_Language => 'en',
            Content_Type => 'application/json',
        ));
    } elsif ($c->req->params->{swagger}) {
        $c->detach('swagger');
    } else {
        $c->stash(template => 'api/root.tt');
        $c->forward($c->view);
        $c->response->headers(HTTP::Headers->new(
            Content_Language => 'en',
            Content_Type => 'application/xhtml+xml',
            #$self->collections_link_headers,
        ));
    }

    return;
}

sub swagger :Private {
    my ($self, $c) = @_;

    my $collections = $c->stash->{collections};
    my $user_role = $c->user->roles;

    my $result = NGCP::Panel::Utils::API::generate_swagger_datastructure(
        $collections,
        $user_role,
    );

    use JSON qw/encode_json/;

    $c->response->headers(HTTP::Headers->new(
        Content_Language => 'en',
        Content_Type => 'application/json',
    ));
    $c->response->body(encode_json($result));
    $c->response->code(200);
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
        Allow => join(', ', @{ $allowed_methods }),
        $self->collections_link_headers,
    ));
    $c->response->content_type('application/json');
    $c->response->body(JSON::to_json({ methods => $allowed_methods })."\n");
    return;
}

sub collections_link_headers : Private {
    my ($self) = @_;

    my $colls = NGCP::Panel::Utils::API::get_collections_files;

    # create Link header for each of the collections
    my @links = ();
    foreach my $mod(@$colls) {
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
    my ($self, $field) = @_;

    if ($field->$_isa('HTML::FormHandler::Field::Select')) {
        return $self->field_to_select_options($field);
    } # elsif { ... }


    SWITCH: for ($field->type) {
        /Float|Integer|Money|PosInteger|Minute|Hour|MonthDay|Year/ &&
            return "Number";
        /Boolean/ &&
            return "Boolean";
        /Repeatable/ &&
            return "Array";
        /\+NGCP::Panel::Field::Select/ &&
             return $self->field_to_select_options($field);
        /\+NGCP::Panel::Field::Regex/ &&
             return "String";
        /\+NGCP::Panel::Field::DateTime/ &&
             return "String";
        /\+NGCP::Panel::Field::Country/ &&
             return "String";
        /\+NGCP::Panel::Field::EmailList/ &&
             return "String";
        /\+NGCP::Panel::Field::Identifier/ &&
            return "String";
        /\+NGCP::Panel::Field::URI/ &&
            return "String";
        /\+NGCP::Panel::Field::IPAddress/ &&
            return "String";
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
        /\+NGCP::Panel::Field::Interval/ &&
            return "Object";
        /\+NGCP::Panel::Field::DatePicker/ &&
            return "String";
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
        if($field->type =~ /E164$/) {
            $name = 'primary_number';
        } elsif($field->type =~ /AliasNumber/) {
            $name = 'alias_numbers';
        } elsif($field->type =~ /PbxGroupAPI/) {
            $name = 'pbx_group_ids';
        } elsif($field->type =~ /Country$/) {
            $name = 'country';
        } elsif($field->type =~ /LnpCarrier$/) {
            $name = 'carrier_id';
        } elsif($field->type !~ /Regex|EmailList|Identifier|PosInteger|Interval|Select|DateTime|URI|IPAddress|DatePicker|ProfileNetwork/) { # ...?
            $name .= '_id';
        }
    }
    my $enum;
    push(@types, $self->field_to_json($field));
    if ($field->$_isa('HTML::FormHandler::Field::Select')) {
        $enum = $field->options;
    }
    my $desc = undef;
    if($field->element_attr) {
        $desc = $field->element_attr->{title}->[0];
    }
    unless (defined $desc && length($desc) > 0) {
        $desc = $field->label;
    }
    unless (defined $desc && length($desc) > 0) {
        $desc = 'to be described ...';
    }
    return { name => $name, description => $desc, types => \@types, type_original => $field->type,
        readonly => $field->readonly, ($enum ? (enum => $enum) : ()) };
}

sub get_collection_properties {
    my ($self, $form) = @_;

    my $renderlist = $form->form->blocks->{fields}->{render_list};
    my %renderlist = defined $renderlist ? map { $_ => 1 } @{$renderlist} : ();

    my @props = ();
    my @uploads = ();
    foreach my $f($form->fields) {
        my $name = $f->name;
        next if (defined $renderlist && !exists $renderlist{$name});
        my $field_spec = $self->get_field_poperties($f);
        next if !$field_spec;
        push @props, $field_spec;
        push @uploads, $field_spec if $f->type =~/Upload/;
        if(my $spec = $f->element_attr->{implicit_parameter}){
            my $f_implicit = clone($f);
            foreach my $field_attribute (keys %{$spec}){
                $f_implicit->$field_attribute($spec->{$field_attribute});
            }
            push @props, $self->get_field_poperties($f_implicit);
        }
    }
    @props = sort{$a->{name} cmp $b->{name}} @props;
    return (\@props,\@uploads);
}

sub end : Private {
    my ($self, $c) = @_;

    #$self->log_response($c);
    return 1;
}


# vim: set tabstop=4 expandtab:
