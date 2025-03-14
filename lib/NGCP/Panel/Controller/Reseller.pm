package NGCP::Panel::Controller::Reseller;
use NGCP::Panel::Utils::Generic qw(:all);
use Sipwise::Base;
use parent 'Catalyst::Controller';

use NGCP::Panel::Form;
use DateTime qw();
use HTTP::Status qw(HTTP_SEE_OTHER);
use File::Type;
use NGCP::Panel::Utils::Contract;
use NGCP::Panel::Utils::DateTime;
use NGCP::Panel::Utils::Message;
use NGCP::Panel::Utils::Navigation;
use NGCP::Panel::Utils::Reseller;
use NGCP::Panel::Utils::BillingNetworks qw();
use NGCP::Panel::Utils::ProfilePackages qw();
use NGCP::Panel::Utils::BillingMappings qw();
use NGCP::Panel::Utils::Billing qw();
use NGCP::Panel::Utils::Auth;
use NGCP::Panel::Utils::Phonebook;
use NGCP::Panel::Utils::TimeSet;
use NGCP::Panel::Utils::Preferences qw();

sub auto :Private {
    my ($self, $c) = @_;
    $c->log->debug(__PACKAGE__ . '::auto');
    NGCP::Panel::Utils::Navigation::check_redirect_chain(c => $c);
    return 1;
}

sub list_reseller :Chained('/') :PathPart('reseller') :CaptureArgs(0) {
    my ($self, $c) = @_;

    $c->stash(
        resellers => $c->model('DB')
            ->resultset('resellers')->search({
                status => { '!=' => 'terminated' }
            }),
        template => 'reseller/list.tt'
    );

    $c->stash->{reseller_dt_columns} = NGCP::Panel::Utils::Datatables::set_columns($c, [
        { name => "id", search => 1, title => $c->loc("#") },
        { name => "contract_id", search => 1, title => $c->loc("Contract #") },
        { name => "name", search => 1, title => $c->loc("Name") },
        { name => "status", search => 1, title => $c->loc("Status") },
    ]);

    # we need this in ajax_contracts also
    $c->stash->{contract_dt_columns} = NGCP::Panel::Utils::Datatables::set_columns($c, [
        { name => "id", search => 1, title => $c->loc("#") },
        { name => "external_id", search => 1, title => $c->loc("External #") },
        { name => "contact.email", search => 1, title => $c->loc("Contact Email") },
        { name => 'billing_profile_name', accessor => "billing_profile_name", search => 0, title => $c->loc('Billing Profile'),
          literal_sql => NGCP::Panel::Utils::BillingMappings::get_actual_billing_mapping_stmt(c => $c, projection => 'billing_profile.name' ) },
        { name => "status", search => 1, title => $c->loc("Status") },
    ]);
}

sub root :Chained('list_reseller') :PathPart('') :Args(0) :Does(ACL) :ACLDetachTo('/denied_page') :AllowedRole(admin) {
    my ($self, $c) = @_;
}

sub ajax :Chained('list_reseller') :PathPart('ajax') :Args(0) :Does(ACL) :ACLDetachTo('/denied_page') :AllowedRole(admin) :AllowedRole(ccareadmin) :AllowedRole(lintercept){
    my ($self, $c) = @_;
    my $resellers = $c->stash->{resellers};
    NGCP::Panel::Utils::Datatables::process($c, $resellers, $c->stash->{reseller_dt_columns});
    $c->detach($c->view('JSON'));
    return;
}

sub create :Chained('list_reseller') :PathPart('create') :Args(0) :Does(ACL) :ACLDetachTo('/denied_page') :AllowedRole(admin) {
    my ($self, $c) = @_;

    $c->detach('/denied_page')
        if($c->user->read_only);

    my $params = {};
    $params = merge($params, $c->session->{created_objects});

    my $posted = $c->request->method eq 'POST';
    my $form = NGCP::Panel::Form::get("NGCP::Panel::Form::Reseller", $c);
    $form->process(
        posted => $posted,
        params => $c->request->params,
        item => $params,
    );
    NGCP::Panel::Utils::Navigation::check_form_buttons(
        c => $c,
        form => $form,
        fields => {'contract.create' => $c->uri_for('/contract/reseller/create') },
        back_uri => $c->req->uri,
    );

    if($form->validated) {
        try {
            my $terminated_reseller = $c->model('DB')->resultset('resellers')->search({
                name => $form->values->{name},
                status => 'terminated'
            })->first;
            if ($terminated_reseller){
                $terminated_reseller->update({
                    name => "old_" . $terminated_reseller->id . "_" . $terminated_reseller->name
                });
            }
            my $reseller = $c->model('DB')->resultset('resellers')->create({
                    contract_id => $form->values->{contract}{id},
                    name => $form->values->{name},
                    status => $form->values->{status},
                });
            NGCP::Panel::Utils::Reseller::create_email_templates( c => $c, reseller => $reseller );

            delete $c->session->{created_objects}->{contract};
            $c->session->{created_objects}->{reseller} = { id => $reseller->id };

            NGCP::Panel::Utils::Message::info(
                c    => $c,
                desc => $c->loc('Reseller successfully created.'),
            );
        } catch($e) {
            NGCP::Panel::Utils::Message::error(
                c => $c,
                error => $e,
                desc  => $c->loc('Failed to create reseller'),
            );
        }
        NGCP::Panel::Utils::Navigation::back_or($c, $c->uri_for('/reseller'));
    }

    $c->stash(create_flag => 1);
    $c->stash(close_target => $c->uri_for());
    $c->stash(form => $form);
}

sub base :Chained('list_reseller') :PathPart('') :CaptureArgs(1) {
    my ($self, $c, $reseller_id) = @_;

    unless($reseller_id && is_int($reseller_id)) {
        NGCP::Panel::Utils::Message::error(
            c     => $c,
            log   => 'Invalid reseller id detected',
            desc  => $c->loc('Invalid reseller id detected'),
        );
        $c->response->redirect($c->uri_for());
        return;
    }
    $c->detach('/denied_page')
        if($c->user->roles eq "reseller" && $c->user->reseller_id != $reseller_id);

    my $reseller = $c->stash->{resellers}->search_rs({ id => $reseller_id });
    unless($reseller->first) {
        NGCP::Panel::Utils::Message::error(
            c     => $c,
            log   => 'Reseller not found',
            desc  => $c->loc('Reseller not found'),
        );
        NGCP::Panel::Utils::Navigation::back_or($c, $c->uri_for('/reseller'));
    }
    $c->stash(reseller => $reseller);

    $c->stash->{contact_dt_columns} = NGCP::Panel::Utils::Datatables::set_columns($c, [
        { name => "id", search => 1, title => $c->loc('#') },
        { name => "firstname", search => 1, title => $c->loc('First Name') },
        { name => "lastname", search => 1, title => $c->loc('Last Name') },
        { name => "company", search => 1, title => $c->loc('Company') },
        { name => "email", search => 1, title => $c->loc('Email') },
    ]);
    $c->stash->{reseller_dt_columns} = NGCP::Panel::Utils::Datatables::set_columns($c, [
        { name => "id", search => 1, title => $c->loc('#') },
        { name => "name", search => 1, title => $c->loc('Name') },
        { name => "status", search => 1, title => $c->loc('Status') },
    ]);
    $c->stash->{admin_dt_columns} = NGCP::Panel::Utils::Datatables::set_columns($c, [
        { name => "id", search => 1, title => $c->loc('#') },
        { name => "login", search => 1, title => $c->loc('Name') },
        { name => "is_master", title => $c->loc('Master') },
        { name => "is_active", title => $c->loc('Active') },
        { name => "read_only", title => $c->loc('Read-Only') },
        { name => "show_passwords", title => $c->loc('Show Passwords') },
        { name => "call_data", title => $c->loc('Show CDRs') },
        { name => "billing_data", title => $c->loc('Show Billing Info') },
    ]);
    $c->stash->{customer_dt_columns} = NGCP::Panel::Utils::Datatables::set_columns($c, [
        { name => "id", search => 1, title => $c->loc('#') },
        { name => "external_id", search => 1, title => $c->loc('External #') },
        { name => "billing_mappings_actual.billing_mappings.product.name", search => 1, title => $c->loc('Product') },
        { name => "contact.email", search => 1, title => $c->loc('Contact Email') },
        { name => "status", search => 1, title => $c->loc('Status') },
    ]);
    $c->stash->{domain_dt_columns} = NGCP::Panel::Utils::Datatables::set_columns($c, [
        { name => "id", search => 1, title => $c->loc('#') },
        { name => "domain", search => 1, title => $c->loc('Domain') },
        { name => "domain.reseller.name", search => 1, title => $c->loc('Reseller') },
    ]);
    $c->stash->{tmpl_dt_columns} = NGCP::Panel::Utils::Datatables::set_columns($c, [
        { name => 'id', search => 1, title => $c->loc('#') },
        { name => 'name', search => 1, title => $c->loc('Name') },
        { name => 'type', search => 1, title => $c->loc('Type') },
    ]);

    $c->stash->{profile_dt_columns} = NGCP::Panel::Utils::Datatables::set_columns($c, [
        { name => "id", "search" => 1, "title" => $c->loc("#") },
        { name => "name", "search" => 1, "title" => $c->loc("Name") },
        #{ name => "reseller.name", "search" => 1, "title" => $c->loc("Reseller") },
        #{ name => "v_count_used", "search" => 0, "title" => $c->loc("Used") },
        NGCP::Panel::Utils::Billing::get_datatable_cols($c),
    ]);

    $c->stash->{network_dt_columns} = NGCP::Panel::Utils::Datatables::set_columns($c, [
        { name => 'id', search => 1, title => $c->loc('#') },
        #{ name => 'reseller.name', search => 1, title => $c->loc('Reseller') },
        { name => 'name', search => 1, title => $c->loc('Name') },
        NGCP::Panel::Utils::BillingNetworks::get_datatable_cols($c),
    ]);

    $c->stash->{package_dt_columns} = NGCP::Panel::Utils::Datatables::set_columns($c, [
        { name => 'id', search => 1, title => $c->loc('#') },
        #{ name => 'reseller.name', search => 1, title => $c->loc('Reseller') },
        { name => 'name', search => 1, title => $c->loc('Name') },
        NGCP::Panel::Utils::ProfilePackages::get_datatable_cols($c),
    ]);

    $c->stash->{phonebook_dt_columns} = NGCP::Panel::Utils::Datatables::set_columns($c, [
        { name => "id", search => 1, title => $c->loc("#") },
        { name => "name", search => 1, title => $c->loc("Name") },
        { name => "number", search => 1, title => $c->loc("Number") },
    ]);

    $c->stash->{timeset_dt_columns} = NGCP::Panel::Utils::Datatables::set_columns($c, [
        { name => "id", search => 1, title => $c->loc("#") },
        { name => "name", search => 1, title => $c->loc("Name") },
    ]);
    $c->stash->{timesets_rs} = $reseller->first->time_sets;
    $c->stash->{branding} = $reseller->first->branding;
    $c->stash->{phonebook} = $reseller->first->phonebook;
}

sub reseller_contacts :Chained('base') :PathPart('contacts/ajax') :Args(0) :Does(ACL) :ACLDetachTo('/denied_page') :AllowedRole(admin) {
    my ($self, $c) = @_;
    my $rs = $c->stash->{reseller}->first->contract->search_related_rs('contact');
    NGCP::Panel::Utils::Datatables::process($c, $rs, $c->stash->{contact_dt_columns});
    $c->detach($c->view('JSON'));
    return;
}

sub reseller_single :Chained('base') :PathPart('single/ajax') :Args(0) :Does(ACL) :ACLDetachTo('/denied_page') :AllowedRole(admin) {
    my ($self, $c) = @_;

    NGCP::Panel::Utils::Datatables::process($c, $c->stash->{reseller}, $c->stash->{reseller_dt_columns});
    $c->detach($c->view('JSON'));
    return;
}

sub reseller_admin :Chained('base') :PathPart('admins/ajax') :Args(0) :Does(ACL) :ACLDetachTo('/denied_page') :AllowedRole(admin) {
    my ($self, $c) = @_;
    my $rs = $c->stash->{reseller}->first->search_related_rs('admins');
    NGCP::Panel::Utils::Datatables::process($c, $rs, $c->stash->{admin_dt_columns});
    $c->detach($c->view('JSON'));
    return;
}

sub edit :Chained('base') :PathPart('edit') :Args(0) :Does(ACL) :ACLDetachTo('/denied_page') :AllowedRole(admin) {
    my ($self, $c) = @_;

    $c->detach('/denied_page')
        if($c->user->read_only);

    my $reseller = $c->stash->{reseller}->first;

    my $posted = $c->request->method eq 'POST';
    my $form = NGCP::Panel::Form::get("NGCP::Panel::Form::Reseller", $c);

    # we need this in the ajax call to not filter it as used contract
    $c->session->{edit_contract_id} = $reseller->contract_id;

    my $params = { $reseller->get_inflated_columns };
    $params->{contract}{id} = delete $params->{contract_id};
    $params = merge($params, $c->session->{created_objects});
    $form->process(
        posted => $posted,
        params => $c->request->params,
        item => $params,
    );
    NGCP::Panel::Utils::Navigation::check_form_buttons(
        c => $c,
        form => $form,
        fields => {'contract.create' => $c->uri_for('/contract/reseller/create') },
        back_uri => $c->req->uri,
    );

    if($posted && $form->validated) {
        try {
            $c->model('DB')->txn_do(sub {
                $form->params->{contract_id} = delete $form->params->{contract}{id};
                delete $form->params->{contract};
                my $old_status = $reseller->status;
                $reseller->update({
                        contract_id => $form->values->{contract}{id},
                        name => $form->values->{name},
                        status => $form->values->{status},
                    });

                if($reseller->status ne $old_status) {
                    NGCP::Panel::Utils::Reseller::_handle_reseller_status_change($c, $reseller);
                }
            });

            delete $c->session->{created_objects}->{contract};
            delete $c->session->{edit_contract_id};

            NGCP::Panel::Utils::Message::info(
                c    => $c,
                desc => $c->loc('Reseller successfully updated'),
            );
        } catch($e) {
            NGCP::Panel::Utils::Message::error(
                c => $c,
                error => $e,
                desc  => $c->loc('Failed to update reseller'),
            );
        }
        NGCP::Panel::Utils::Navigation::back_or($c, $c->uri_for('/reseller'));
    }

    $c->stash(close_target => $c->uri_for());
    $c->stash(form => $form);
    $c->stash(edit_flag => 1);

    return;
}

sub terminate :Chained('base') :PathPart('terminate') :Args(0) :Does(ACL) :ACLDetachTo('/denied_page') :AllowedRole(admin) {
    my ($self, $c) = @_;

    my $reseller = $c->stash->{reseller}->first;

    if ($reseller->id == 1) {
        NGCP::Panel::Utils::Message::error(
            c     => $c,
            log   => 'Cannot terminate reseller with the id 1',
            desc  => $c->loc('Cannot terminate reseller with the id 1'),
        );
        NGCP::Panel::Utils::Navigation::back_or($c, $c->uri_for('/reseller'));
    }

    try {
        $c->model('DB')->txn_do(sub {
            my $old_status = $reseller->status;
            $reseller->update({ status => 'terminated' });

            if($reseller->status ne $old_status) {
                NGCP::Panel::Utils::Reseller::_handle_reseller_status_change($c,$reseller);
            }
        });
        NGCP::Panel::Utils::Message::info(
            c    => $c,
            data => { $reseller->get_inflated_columns },
            desc => $c->loc('Successfully terminated reseller'),
        );
    } catch($e) {
        NGCP::Panel::Utils::Message::error(
            c => $c,
            error => $e,
            desc  => $c->loc('Failed to terminate reseller'),
        );
    }
    NGCP::Panel::Utils::Navigation::back_or($c, $c->uri_for('/reseller'));
}

sub base_details :Chained('base') :PathPart('details') :CaptureArgs(0) :Does(ACL) :ACLDetachTo('/denied_page') :AllowedRole(admin) {
    my ($self, $c) = @_;

    $c->stash(template => 'reseller/details.tt');
    return;
}

sub details :Chained('base_details') :PathPart('') :Args(0) :Does(ACL) :ACLDetachTo('/denied_page') :AllowedRole(admin) {
    my ($self, $c) = @_;

    $c->stash(template => 'reseller/details.tt');
    return;
}

sub ajax_contract :Chained('list_reseller') :PathPart('ajax_contract') :Args(0) :Does(ACL) :ACLDetachTo('/denied_page') :AllowedRole(admin) {
    my ($self, $c) = @_;

    my $edit_contract_id = $c->session->{edit_contract_id};
    my @used_contracts = map {
        unless($edit_contract_id && $edit_contract_id == $_->get_column('contract_id')) {
            $_->get_column('contract_id')
        } else {}
    } $c->stash->{resellers}->all;
    my @product_ids = map { $_->id; } $c->model('DB')->resultset('products')->search_rs({ 'class' => ['reseller'] })->all;
    my $free_contracts = NGCP::Panel::Utils::Contract::get_contract_rs(schema => $c->model('DB'))->search_rs({
        'me.status' => { '!=' => 'terminated' },
        'me.id' => { 'not in' => \@used_contracts },
        'product_id' => { -in => [ @product_ids ] },
    });
    NGCP::Panel::Utils::Datatables::process($c, $free_contracts, $c->stash->{contract_dt_columns});
    $c->detach( $c->view("JSON") );
}

sub create_defaults :Path('create_defaults') :Args(0) :Does(ACL) :ACLDetachTo('/denied_page') :AllowedRole(admin) {
    my ($self, $c) = @_;
    $c->detach('/denied_page') unless $c->request->method eq 'POST';
    $c->detach('/denied_page')
        if($c->user->read_only);

	my $default_pass = 'defaultresellerpassword';
	my $saltedpass = NGCP::Panel::Utils::Auth::generate_salted_hash($default_pass);

    my $billing = $c->model('DB');
    my $now = NGCP::Panel::Utils::DateTime::current_local;
    my %defaults = (
        contacts => {
            firstname => 'Default',
            lastname => 'Contact',
            email => 'default_contact@example.invalid', # RFC 2606
            create_timestamp => $now,
        },
        contracts => {
            status => 'active',
            create_timestamp => $now,
            activate_timestamp => $now,
            product_id => $billing->resultset('products')->search_rs({ class => 'reseller' })->first->id,
        },
        resellers => {
            name => 'Default reseller' . sprintf('%04d', rand 10000),
            status => 'active',
        },
        admins => {
            saltedpass => $saltedpass,
            is_active => 1,
            show_passwords => 1,
            call_data => 1,
        },
    );
    $defaults{admins}->{login} = $defaults{resellers}->{name} =~ tr/A-Za-z0-9//cdr;

    my %r;
    try {
        $billing->txn_do(sub {
            $r{contacts} = $billing->resultset('contacts')->create({ %{ $defaults{contacts} } });
            $r{contracts} = $billing->resultset('contracts')->create({
                %{ $defaults{contracts} },  ## no critic (ProhibitCommaSeparatedStatements)
                contact_id => $r{contacts}->id,
            });

            my $terminated_reseller = $billing->resultset('resellers')->search({
                name => $defaults{resellers}->{name},
                status => 'terminated'
            })->first;
            if ($terminated_reseller){
                $terminated_reseller->update({
                    name => "old_" . $terminated_reseller->id . "_" . $terminated_reseller->name
                });
            }
            $r{resellers} = $billing->resultset('resellers')->create({
                %{ $defaults{resellers} },  ## no critic (ProhibitCommaSeparatedStatements)
                contract_id => $r{contracts}->id,
            });
            NGCP::Panel::Utils::Reseller::create_email_templates( c => $c, reseller => $r{resellers} );
            my $mappings_to_create = [];
            my $resource = { $r{contracts}->get_inflated_columns };
            $resource->{billing_profile_id} = 1;
            $resource->{type} = 'reseller';

            NGCP::Panel::Utils::BillingMappings::prepare_billing_mappings(
                c => $c,
                resource => $resource,
                old_resource => undef,
                mappings_to_create => $mappings_to_create,
                err_code => sub {
                    my ($err) = @_;
                    die( [$err, "showdetails"] );
            });
            NGCP::Panel::Utils::BillingMappings::append_billing_mappings(c => $c,
                contract => $r{contracts},
                mappings_to_create => $mappings_to_create,
            );
            $r{contracts} = NGCP::Panel::Utils::Contract::get_contract_rs(schema => $c->model('DB'))->find($r{contracts}->id);
            $r{billing_mappings} = $r{contracts}->billing_mappings;

            $r{admins} = $billing->resultset('admins')->create({
                %{ $defaults{admins} },  ## no critic (ProhibitCommaSeparatedStatements)
                reseller_id => $r{resellers}->id,
                role_id     => NGCP::Panel::Utils::UserRole::find_row_by_name($c, 'reseller')->id
            });
            NGCP::Panel::Utils::ProfilePackages::create_initial_contract_balances(c => $c,
                contract => $r{contracts},
            );
        });
    } catch($e) {
        NGCP::Panel::Utils::Message::error(
            c => $c,
            error => $e,
            desc  => $c->loc('Failed to create reseller'),
        );
        NGCP::Panel::Utils::Navigation::back_or($c, $c->uri_for('/reseller'));
    };
    NGCP::Panel::Utils::Message::info(
        c    => $c,
        desc => $c->loc('Reseller successfully created with login <b>[_1]</b> and password <b>[_2]</b>, please review your settings below', $defaults{admins}->{login}, $default_pass),
    );
    $c->res->redirect($c->uri_for_action('/reseller/details', [$r{resellers}->id]));
    $c->detach;
    return;
}

sub css :Chained('base') :PathPart('css') :Args(0) :Does(ACL) :ACLDetachTo('/denied_page') :AllowedRole(admin) :AllowedRole(reseller) {
    my ($self, $c) = @_;
    $c->stash(template => 'reseller/branding.tt');
    return;
}

sub edit_branding_css :Chained('base') :PathPart('css/edit') :Args(0) :Does(ACL) :ACLDetachTo('/denied_page') :AllowedRole(admin) :AllowedRole(reseller) {
    my ($self, $c) = @_;

    $c->detach('/denied_page')
        if($c->user->read_only);
    my $back;
    if($c->user->roles eq "admin") {
        $c->stash(template => 'reseller/details.tt');
        $back = $c->uri_for_action('/reseller/details', $c->req->captures);
    } else {
        $c->stash(template => 'reseller/branding.tt');
        $back = $c->uri_for_action('/reseller/css', $c->req->captures);
    }

    my $reseller = $c->stash->{reseller}->first;
    my $branding = $reseller->branding;

    my $posted = $c->request->method eq 'POST';
    my $form = NGCP::Panel::Form::get("NGCP::Panel::Form::Reseller::Branding", $c);

    if($posted) {
        $c->req->params->{logo} = $c->req->upload('logo');
    }

    my $params = $branding ? { $branding->get_inflated_columns } : {};
    $form->process(
        posted => $posted,
        params => $c->request->params,
        item => $params,
    );
    NGCP::Panel::Utils::Navigation::check_form_buttons(
        c => $c,
        form => $form,
        fields => {},
        back_uri => $back,
    );

    if($posted && $form->validated) {
        try {
            $c->model('DB')->txn_do(sub {
                if($c->user->roles eq "admin") {
                    $form->params->{reseller_id} = $reseller->id;
                } elsif($c->user->roles eq "reseller") {
                    $form->params->{reseller_id} = $c->user->reseller_id;
                }
                delete $form->params->{reseller};
                delete $form->params->{back};

                my $ft = File::Type->new();
                if($form->params->{logo}) {
                    my $logo = delete $form->params->{logo};
                    $form->params->{logo} = $logo->slurp;
                    $form->params->{logo_image_type} = $ft->mime_type($form->params->{logo});
                } else {
                    delete $form->params->{logo};
                }

                unless(defined $branding) {
                    $c->model('DB')->resultset('reseller_brandings')->create($form->params);
                } else {
                    $branding->update($form->params);
                }
            });
            NGCP::Panel::Utils::Message::info(
                c    => $c,
                desc => $c->loc('Reseller branding successfully updated'),
            );
        } catch($e) {
            NGCP::Panel::Utils::Message::error(
                c => $c,
                error => $e,
                desc  => $c->loc('Failed to update reseller branding'),
            );
        }
        NGCP::Panel::Utils::Navigation::back_or($c, $back);
    }

    $c->stash(close_target => $c->uri_for());
    $c->stash(branding_form => $form);
    $c->stash(branding_edit_flag => 1);
    $c->stash(close_target => $back);

    return;
}

sub get_branding_logo :Chained('base') :PathPart('css/logo/download') :Args(0) {
    my ($self, $c) = @_;


    my $reseller = $c->stash->{reseller}->first;
    my $branding = $reseller->branding;

    unless($branding || $branding->logo) {
        $c->response->body($c->loc('404 - No branding logo available for this reseller'));
        $c->response->status(404);
        return;
    }
    $c->response->content_type($branding->logo_image_type);
    $c->response->body($branding->logo);
}

sub delete_branding_logo :Chained('base') :PathPart('css/logo/delete') :Args(0) :Does(ACL) :ACLDetachTo('/denied_page') :AllowedRole(admin) :AllowedRole(reseller) {
    my ($self, $c) = @_;

    my $back;
    if($c->user->roles eq "admin") {
        $back = $c->uri_for_action('/reseller/details', $c->req->captures);
    } else {
        $back = $c->uri_for_action('/reseller/css', $c->req->captures);
    }

    my $reseller = $c->stash->{reseller}->first;
    my $branding = $reseller->branding;

    if($branding) {
        $branding->update({ logo => undef, logo_image_type => undef });
    }

    $c->response->redirect($back);
}

sub get_branding_css :Chained('base') :PathPart('css/download') :Args(0) {
    my ($self, $c) = @_;


    my $reseller = $c->stash->{reseller}->first;
    my $branding = $reseller->branding;

    unless($branding || $branding->css) {
        $c->response->body($c->loc('404 - No branding css available for this reseller'));
        $c->response->status(404);
        return;
    }
    $c->response->content_type('text/css');
    $c->response->body($branding->css);
}

sub resellers_preferences_list :Chained('base') :PathPart('preferences') :CaptureArgs(0) {
    my ($self, $c) = @_;

    $c->stash->{reseller} = $c->stash->{reseller}->first;
    my $x_pref_values = $c->model('DB')
        ->resultset('voip_preferences')
        ->search({
                'reseller.id' => $c->stash->{reseller}->id,
            },{
                prefetch => {'reseller_preferences' => 'reseller'},
            });

    my %pref_values;
    foreach my $value($x_pref_values->all) {

        $pref_values{$value->attribute} =
            [ map {$_->value} $value->reseller_preferences->all ];
    }

    my $rewrite_rule_sets_rs = $c->model('DB')
        ->resultset('voip_rewrite_rule_sets')->search_rs({
        reseller_id => $c->stash->{reseller}->id,
    },undef);
    $c->stash(rwr_sets_rs => $rewrite_rule_sets_rs,
              rwr_sets    => [$rewrite_rule_sets_rs->all],);

    NGCP::Panel::Utils::Preferences::load_preference_list( c => $c,
        pref_values => \%pref_values,
        reseller_pref => 1,
    );

    $c->stash(template => 'reseller/preferences.tt');
    return;
}

sub resellers_preferences_root :Chained('resellers_preferences_list') :PathPart('') :Args(0) {
    return;
}

sub resellers_preferences_base :Chained('resellers_preferences_list') :PathPart('') :CaptureArgs(1) {
    my ($self, $c, $pref_id) = @_;

    $c->stash->{preference_meta} = $c->model('DB')
        ->resultset('voip_preferences')
        ->search({
            -or => ['voip_preferences_enums.reseller_pref' => 1,
                'voip_preferences_enums.reseller_pref' => undef],
        },{
            prefetch => 'voip_preferences_enums',
        })
        ->find({id => $pref_id});

    $c->stash->{preference} = $c->model('DB')
        ->resultset('reseller_preferences')
        ->search({
            attribute_id => $pref_id,
            'reseller.id' => $c->stash->{reseller}->id,
        },{
            prefetch => 'reseller',
        });
    return;
}

sub resellers_preferences_edit :Chained('resellers_preferences_base') :PathPart('edit') :Args(0) {
    my ($self, $c) = @_;

    $c->stash(edit_preference => 1);

    my @enums = $c->stash->{preference_meta}
        ->voip_preferences_enums
        ->all;

    my $pref_rs = $c->stash->{reseller}->reseller_preferences;

    NGCP::Panel::Utils::Preferences::create_preference_form( c => $c,
        pref_rs => $pref_rs,
        enums   => \@enums,
        base_uri => $c->uri_for_action('/reseller/resellers_preferences_root', [@{ $c->req->captures }[0]]),
        edit_uri => $c->uri_for_action('/reseller/resellers_preferences_edit', $c->req->captures),
    );
    return;
}

sub phonebook_ajax :Chained('base') :PathPart('phonebook/ajax') :Args(0) :Does(ACL) :ACLDetachTo('/denied_page') :AllowedRole(admin) :AllowedRole(reseller) {
    my ($self, $c) = @_;
    NGCP::Panel::Utils::Datatables::process($c,
        @{$c->stash}{qw(phonebook phonebook_dt_columns)});
    $c->detach( $c->view("JSON") );
}

sub phonebook_root :Chained('base_details') :PathPart('phonebook') :Args(0) {
    my ($self, $c) = @_;
}

sub phonebook_create :Chained('base_details') :PathPart('phonebook/create') :Args(0) :Does(ACL) :ACLDetachTo('/denied_page') :AllowedRole(admin) :AllowedRole(reseller) {
    my ($self, $c) = @_;

    my $reseller = $c->stash->{reseller}->first;
    my $posted = ($c->request->method eq 'POST');
    my $form = NGCP::Panel::Form::get("NGCP::Panel::Form::Phonebook::Reseller", $c);
    my $params = {};
    $params = merge($params, $c->session->{created_objects});
    $form->process(
        posted => $posted,
        params => $c->request->params,
        item => $params,
    );
    NGCP::Panel::Utils::Navigation::check_form_buttons(
        c => $c,
        form => $form,
        back_uri => $c->req->uri,
    );
    if($posted && $form->validated) {
        try {
            $c->model('DB')->schema->txn_do( sub {
                $c->model('DB')->resultset('reseller_phonebook')->create({
                    reseller_id => $reseller->id,
                    name => $form->values->{name},
                    number => $form->values->{number},
                });
            });

            NGCP::Panel::Utils::Message::info(
                c => $c,
                desc => $c->loc('Phonebook entry successfully created'),
            );
        } catch ($e) {
            NGCP::Panel::Utils::Message::error(
                c => $c,
                error => $e,
                desc  => $c->loc('Failed to create phonebook entry.'),
            );
        }
        NGCP::Panel::Utils::Navigation::back_or($c, $c->uri_for_action("/reseller/details", [$reseller->id]));
    }

    $c->stash(
        close_target => $c->uri_for_action("/reseller/details", [$reseller->id]),
        phonebook_create_flag => 1,
        form => $form
    );
}

sub phonebook_base :Chained('base_details') :PathPart('phonebook') :CaptureArgs(1) {
    my ($self, $c, $phonebook_id) = @_;

    unless($phonebook_id && is_int($phonebook_id)) {
        $phonebook_id //= '';
        NGCP::Panel::Utils::Message::error(
            c => $c,
            data => { id => $phonebook_id },
            desc => $c->loc('Invalid phonebook id detected'),
        );
        $c->response->redirect($c->uri_for());
        $c->detach;
        return;
    }

    my $res = $c->stash->{reseller}->first->phonebook->find($phonebook_id);
    unless(defined($res)) {
        NGCP::Panel::Utils::Message::error(
            c => $c,
            desc => $c->loc('Phonebook entry does not exist'),
        );
        $c->response->redirect($c->uri_for());
        $c->detach;
        return;
    }

    $c->stash(phonebook => {$res->get_inflated_columns},
              phonebook_result => $res);
}

sub phonebook_edit :Chained('phonebook_base') :PathPart('edit') :Args(0) :Does(ACL) :ACLDetachTo('/denied_page') :AllowedRole(admin) :AllowedRole(reseller) {
    my ($self, $c) = @_;

    my $reseller = $c->stash->{reseller}->first;
    my $posted = ($c->request->method eq 'POST');
    my $form = NGCP::Panel::Form::get("NGCP::Panel::Form::Phonebook::Reseller", $c);
    my $params = $c->stash->{phonebook};
    $params = merge($params, $c->session->{created_objects});
    $form->process(
        posted => $posted,
        params => $c->request->params,
        item => $params,
    );
    if($posted && $form->validated) {
        try {
            $c->model('DB')->schema->txn_do( sub {
                $c->stash->{'phonebook_result'}->update({
                    name => $form->values->{name},
                    number => $form->values->{number},
                });
            });
            NGCP::Panel::Utils::Message::info(
                c => $c,
                desc  => $c->loc('Phonebook entry successfully updated'),
            );
        } catch ($e) {
            NGCP::Panel::Utils::Message::error(
                c => $c,
                error => $e,
                desc  => $c->loc('Failed to update phonebook entry'),
            );
        }

        NGCP::Panel::Utils::Navigation::back_or($c, $c->uri_for_action("/reseller/details", [$reseller->id]));

    }

    $c->stash(
        close_target => $c->uri_for_action("/reseller/details", [$reseller->id]),
        phonebook_edit_flag => 1,
        form => $form
    );
}

sub phonebook_delete :Chained('phonebook_base') :PathPart('delete') :Args(0) :Does(ACL) :ACLDetachTo('/denied_page') :AllowedRole(admin) :AllowedRole(reseller) {
    my ($self, $c) = @_;

    my $reseller = $c->stash->{reseller}->first;
    my $phonebook = $c->stash->{phonebook_result};

    try {
        $phonebook->delete;
        NGCP::Panel::Utils::Message::info(
            c => $c,
            data => $c->stash->{phonebook},
            desc => $c->loc('Phonebook entry successfully deleted'),
        );
    } catch ($e) {
        NGCP::Panel::Utils::Message::error(
            c => $c,
            error => $e,
            data  => $c->stash->{phonebook},
            desc  => $c->loc('Failed to delete phonebook entry'),
        );
    };

    NGCP::Panel::Utils::Navigation::back_or($c, $c->uri_for_action("/reseller/details", [$reseller->id]));
}

sub phonebook_upload_csv :Chained('base_details') :PathPart('phonebook_upload_csv') :Args(0) {
    my ($self, $c) = @_;

    my $reseller = $c->stash->{reseller}->first;
    my $form = NGCP::Panel::Form::get("NGCP::Panel::Form::Phonebook::Upload", $c);
    NGCP::Panel::Utils::Phonebook::ui_upload_csv(
        $c, $c->stash->{phonebook}, $form, 'reseller', $reseller->id,
        $c->uri_for_action('/reseller/phonebook_upload_csv',[$reseller->id]),
        $c->uri_for_action('/reseller/details',[$reseller->id])
    );

    $c->stash(
        phonebook_create_flag => 1,
        form => $form
    );
    return;
}

sub phonebook_download_csv :Chained('base') :PathPart('phonebook_download_csv') :Args(0) {
    my ($self, $c) = @_;

    my $reseller = $c->stash->{reseller}->first;
    $c->response->header ('Content-Disposition' => 'attachment; filename="reseller_phonebook_entries.csv"');
    $c->response->content_type('text/csv');
    $c->response->status(200);
    NGCP::Panel::Utils::Phonebook::download_csv(
        $c, $c->stash->{phonebook}, 'reseller', $reseller->id
    );
    return;
}

sub timeset_ajax :Chained('base') :PathPart('reseller/ajax') :Args(0) :Does(ACL) :ACLDetachTo('/denied_page') :AllowedRole(admin) :AllowedRole(reseller) {
    my ($self, $c) = @_;
    NGCP::Panel::Utils::Datatables::process($c,
        @{$c->stash}{qw(timesets_rs timeset_dt_columns)});
    $c->detach( $c->view("JSON") );
}

sub timeset_root :Chained('base_details') :PathPart('timeset') :Args(0) {
    my ($self, $c) = @_;
}

sub timeset_create :Chained('base_details') :PathPart('timeset/create') :Args(0) :Does(ACL) :ACLDetachTo('/denied_page') :AllowedRole(admin) :AllowedRole(reseller) {
    my ($self, $c) = @_;

    my $reseller = $c->stash->{reseller}->first;
    my $posted = ($c->request->method eq 'POST');
    my $form = NGCP::Panel::Form::get("NGCP::Panel::Form::TimeSet::Reseller", $c);
    my $upload = $c->req->upload('calendarfile');
    my $params = {
        %{$c->request->params},
        upload => $posted ? $upload : undef,
    };
    $params = merge($params, $c->session->{created_objects});
    $form->process(
        posted => $posted,
        params => $params,
        action => $c->uri_for_action('/reseller/timeset_create'),
    );
    NGCP::Panel::Utils::Navigation::check_form_buttons(
        c => $c,
        form => $form,
        back_uri => $c->req->uri,
    );
    if($posted && $form->validated) {
        try {
            my $resource = $form->values;
            $resource = NGCP::Panel::Utils::TimeSet::timeset_resource(
                c => $c,
                resource => $resource,
            );
            $resource->{reseller_id} = $reseller->id;
            $c->model('DB')->schema->txn_do( sub {
                NGCP::Panel::Utils::TimeSet::create_timeset(
                    c => $c,
                    resource => $resource,
                );
            });

            NGCP::Panel::Utils::Message::info(
                c => $c,
                desc => $c->loc('Timeset entry successfully created'),
            );
        } catch ($e) {
            NGCP::Panel::Utils::Message::error(
                c => $c,
                error => $e,
                desc  => $c->loc('Failed to create timeset entry.'),
            );
        }
        NGCP::Panel::Utils::Navigation::back_or($c, $c->uri_for_action("/reseller/details", [$reseller->id]));
    }

    $c->stash(
        close_target => $c->uri_for_action("/reseller/details", [$reseller->id]),
        timeset_create_flag => 1,
        form => $form
    );
}

sub timeset_base :Chained('base_details') :PathPart('timeset') :CaptureArgs(1) {
    my ($self, $c, $timeset_id) = @_;

    unless($timeset_id && is_int($timeset_id)) {
        $timeset_id //= '';
        NGCP::Panel::Utils::Message::error(
            c => $c,
            data => { id => $timeset_id },
            desc => $c->loc('Invalid timeset id detected'),
        );
        $c->response->redirect($c->uri_for());
        $c->detach;
        return;
    }

    my $rs = $c->stash->{reseller}->first->time_sets->find($timeset_id);
    unless(defined($rs)) {
        NGCP::Panel::Utils::Message::error(
            c => $c,
            desc => $c->loc('Timeset entry does not exist'),
        );
        $c->response->redirect($c->uri_for());
        $c->detach;
        return;
    }

    $c->stash(
        timeset => {$rs->get_inflated_columns},
        timeset_rs => $rs
    );
}

sub timeset_edit :Chained('timeset_base') :PathPart('edit') :Args(0) :Does(ACL) :ACLDetachTo('/denied_page') :AllowedRole(admin) :AllowedRole(reseller) {
    my ($self, $c) = @_;

    my $reseller = $c->stash->{reseller}->first;
    my $posted = ($c->request->method eq 'POST');
    my $form = NGCP::Panel::Form::get("NGCP::Panel::Form::TimeSet::Reseller", $c);
    my $upload = $c->req->upload('calendarfile');

    my $params = {
        %{$c->request->params},
        upload => $posted ? $upload : undef,
    };

    my $item = NGCP::Panel::Utils::TimeSet::get_timeset(c => $c, timeset => $c->stash->{timeset_rs});
    $item = merge($item, $c->session->{created_objects});
    $form->process(
        posted => $posted,
        params => $params,
        item   => $item,
    );
    if($posted && $form->validated) {
        try {
            $c->model('DB')->schema->txn_do( sub {
                my $resource = $form->values;
                $resource = NGCP::Panel::Utils::TimeSet::timeset_resource(
                    c => $c,
                    resource => $resource
                );
                $resource->{reseller_id} = $reseller->id;
                NGCP::Panel::Utils::TimeSet::update_timeset(
                    c => $c,
                    timeset => $c->stash->{'timeset_rs'},
                    resource => $resource,
                );
            });
            NGCP::Panel::Utils::Message::info(
                c => $c,
                desc  => $c->loc('Timeset entry successfully updated'),
            );
        } catch ($e) {
            NGCP::Panel::Utils::Message::error(
                c => $c,
                error => $e,
                desc  => $c->loc('Failed to update timeset entry'),
            );
        }

        NGCP::Panel::Utils::Navigation::back_or($c, $c->uri_for_action("/reseller/details", [$reseller->id]));

    }

    $c->stash(
        close_target => $c->uri_for_action("/reseller/details", [$reseller->id]),
        timeset_edit_flag => 1,
        form => $form
    );
}

sub timeset_delete :Chained('timeset_base') :PathPart('delete') :Args(0) :Does(ACL) :ACLDetachTo('/denied_page') :AllowedRole(admin) :AllowedRole(reseller) {
    my ($self, $c) = @_;

    my $reseller = $c->stash->{reseller}->first;
    my $timeset = $c->stash->{timeset};

    try {
        $c->stash->{timeset_rs}->delete;
        NGCP::Panel::Utils::Message::info(
            c => $c,
            data => $c->stash->{timeset},
            desc => $c->loc('Timeset entry successfully deleted'),
        );
    } catch ($e) {
        NGCP::Panel::Utils::Message::error(
            c => $c,
            error => $e,
            data  => $c->stash->{timeset},
            desc  => $c->loc('Failed to delete timeset entry'),
        );
    };

    NGCP::Panel::Utils::Navigation::back_or($c, $c->uri_for_action("/reseller/details", [$reseller->id]));
}

1;

__END__

=encoding UTF-8

=head1 NAME

NGCP::Panel::Controller::Reseller - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=head2 C<reseller_contacts>

=head2 C<reseller_contracts>

=head2 C<reseller_single>

=head2 C<reseller_admin>

These are Ajax actions called from L</details>, rendering datatables with a single result each.

=head2 C<details>

Renders the F<reseller/details.tt> template, whose datatables relate to and are derived from a reseller id in the
captures.

=head2 C<create_defaults>

Creates a reseller with all dependent contract, contact, billing mapping, admin login in a single step with default
values. Redirects to L</details>.

=head1 AUTHOR

Andreas Granig,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

# vim: set tabstop=4 expandtab:
