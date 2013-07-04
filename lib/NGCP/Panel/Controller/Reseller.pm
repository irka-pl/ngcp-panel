package NGCP::Panel::Controller::Reseller;
use Sipwise::Base;
use namespace::sweep;
BEGIN { extends 'Catalyst::Controller'; }
use DateTime qw();
use HTTP::Status qw(HTTP_SEE_OTHER);
use NGCP::Panel::Form::Reseller;
use NGCP::Panel::Utils;

sub auto :Does(ACL) :ACLDetachTo('/denied_page') :AllowedRole(admin) {
    my ($self, $c) = @_;
    $c->log->debug(__PACKAGE__ . '::auto');
    return 1;
}

sub list_reseller :Chained('/') :PathPart('reseller') :CaptureArgs(0) {
    my ($self, $c) = @_;

    $c->stash(
        resellers => $c->model('billing')
            ->resultset('resellers')->search_rs({}),
        template => 'reseller/list.tt'
    );
    NGCP::Panel::Utils::check_redirect_chain(c => $c);
}

sub root :Chained('list_reseller') :PathPart('') :Args(0) {
    my ($self, $c) = @_;
}

sub ajax :Chained('list_reseller') :PathPart('ajax') :Args(0) {
    my ($self, $c) = @_;
    my $resellers = $c->stash->{resellers};
    $c->forward(
        '/ajax_process_resultset', [
            $resellers,
            [qw(id contract_id name status)],
            [ "contract_id", "name", "status" ]
        ]
    );
    $c->detach($c->view('JSON'));
    return;
}

sub create :Chained('list_reseller') :PathPart('create') :Args(0) {
    my ($self, $c) = @_;

    # TODO: check in session if contract has just been created, and set it
    # as default value

    my $posted = $c->request->method eq 'POST';
    my $form = NGCP::Panel::Form::Reseller->new;
    $form->process(
        posted => $posted,
        params => $c->request->params,
        action => $c->uri_for('create'),
    );
    return if NGCP::Panel::Utils::check_form_buttons(
        c => $c, 
        form => $form, 
        fields => [qw/contract.create/], 
        back_uri => $c->uri_for('create')
    );
    # TODO: preserve the current "reseller" object for continuing editing
    # when coming back from /contract/create

    if($form->validated) {
        try {
            delete $form->params->{save};
            $form->params->{contract_id} = delete $form->params->{contract}->{id};
            delete $form->params->{contract};
            $c->model('billing')->resultset('resellers')->create($form->params);

            $c->flash(messages => [{type => 'success', text => 'Reseller successfully created.'}]);
        } catch($e) {
            $c->log->error($e);
            $c->flash(messages => [{type => 'error', text => 'Creating reseller failed.'}]);
        }
        $c->response->redirect($c->uri_for());
        return;
    }

    $c->stash(create_flag => 1);
    $c->stash(close_target => $c->uri_for());
    $c->stash(form => $form);
}

sub base :Chained('list_reseller') :PathPart('') :CaptureArgs(1) {
    my ($self, $c, $reseller_id) = @_;

    unless($reseller_id && $reseller_id =~ /^\d+$/) {
        $c->flash(messages => [{type => 'error', text => 'Invalid reseller id detected.'}]);
        $c->response->redirect($c->uri_for());
        return;
    }

    $c->stash(reseller => $c->stash->{resellers}->search_rs({id => $reseller_id}));
}

sub reseller_contacts :Chained('base') :PathPart('contacts') :Args(0) {
    my ($self, $c) = @_;
    $c->forward(
        '/ajax_process_resultset', [
            $c->stash->{reseller}->first->contract->search_related_rs('contact'),
            [qw(id firstname lastname email create_timestamp)],
            [ "firstname", "lastname", "email" ]
        ]
    );
    $c->detach($c->view('JSON'));
    return;
}

sub reseller_contracts :Chained('base') :PathPart('contracts') :Args(0) {
    my ($self, $c) = @_;
    $c->forward(
        '/ajax_process_resultset', [
            $c->stash->{reseller}->first->search_related_rs('contract'),
            [qw(id contact_id)],
            [ "contact_id" ]
        ]
    );
    $c->detach($c->view('JSON'));
    return;
}

sub reseller_single :Chained('base') :PathPart('single') :Args(0) {
    my ($self, $c) = @_;

    $c->forward(
        '/ajax_process_resultset', [
            $c->stash->{reseller},
            [qw(id contract_id name status)],
            [ "contract_id", "name", "status" ]
        ]
    );
    $c->detach($c->view('JSON'));
    return;
}

sub reseller_admin :Chained('base') :PathPart('admins') :Args(0) {
    my ($self, $c) = @_;
    $c->forward(
        '/ajax_process_resultset', [
            $c->stash->{reseller}->first->search_related_rs('admins'),
            [qw(id reseller_id login)],
            [ "reseller_id", "login" ]
        ]
    );
    $c->detach($c->view('JSON'));
    return;
}

sub edit :Chained('base') :PathPart('edit') :Args(0) {
    my ($self, $c) = @_;

    my $posted = $c->request->method eq 'POST';
    my $form = NGCP::Panel::Form::Reseller->new;
    $form->process(
        posted => 1,
        params => $posted ? $c->request->params : {$c->stash->{reseller}->get_inflated_columns},
        action => $c->uri_for($c->stash->{reseller}->get_column('id'), 'edit'),
    );
    return if NGCP::Panel::Utils::check_form_buttons(
        c => $c, form => $form, fields => [qw/contract.create/], 
        back_uri => $c->uri_for($c->stash->{reseller}->get_column('id'), 'edit')
    );

    if($posted && $form->validated) {
        try {
            my $form_values = $form->value;
            $form_values->{contract_id} = delete $form_values->{contract}{id};
            delete $form_values->{contract};
            $c->stash->{reseller}->update($form_values);            
            $c->flash(messages => [{type => 'success', text => 'Reseller successfully changed.'}]);
            delete $c->session->{contract_id};
        } catch($e) {
            $c->log->error($e);
            $c->flash(messages => [{type => 'error', text => 'Updating reseller failed.'}]);
        }
        $c->response->redirect($c->uri_for());
    }

    $c->stash(close_target => $c->uri_for());
    $c->stash(form => $form);
    $c->stash(edit_flag => 1);

    $c->session(contract_id => $c->stash->{reseller}->get_column('contract_id'));

    return;
}

sub delete :Chained('base') :PathPart('delete') :Args(0) {
    my ($self, $c) = @_;

    try {
        $c->stash->{reseller}->delete;
        $c->flash(messages => [{type => 'success', text => 'Reseller successfully deleted.'}]);
    } catch($e) {
        $c->log->error($e);
        $c->flash(messages => [{type => 'error', text => 'Deleting reseller failed.'}]);
    }
    $c->response->redirect($c->uri_for());
}

sub details :Chained('base') :PathPart('details') :Args(0) {
    my ($self, $c) = @_;
    $c->stash(template => 'reseller/details.tt');
    return;
}

sub ajax_contract :Chained('list_reseller') :PathPart('ajax_contract') :Args(0) {
    my ($self, $c) = @_;
  
    my $contract_id = $c->session->{contract_id};

    my @used_contracts = map { 
        $_->get_column('contract_id') unless(
            $contract_id && 
            $contract_id == $_->get_column('contract_id')
        )
    } $c->stash->{resellers}->all;
    my $free_contracts = $c->model('billing')
        ->resultset('contracts')
        ->search_rs({
            id => { 'not in' => \@used_contracts }
        });
    
    $c->forward("/ajax_process_resultset", [ 
        $free_contracts,
        ["id", "contact_id", "external_id", "status"],
        ["contact_id", "external_id", "status"]
    ]);
    
    $c->detach( $c->view("JSON") );
}

sub create_defaults :Path('create_defaults') :Args(0) {
    my ($self, $c) = @_;
    $c->detach('/denied_page') unless $c->request->method eq 'POST';
    my $now = DateTime->now;
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
        },
        resellers => {
            name => 'Default reseller' . sprintf('%04d', rand 10000),
            status => 'active',
        },
        billing_mappings => {
            start_date => $now,
        },
        admins => {
            md5pass => 'defaultresellerpassword',
            is_active => 1,
            show_passwords => 1,
            call_data => 1,
        },
    );
    $defaults{admins}->{login} = $defaults{resellers}->{name} =~ tr/A-Za-z0-9//cdr,

    my $billing = $c->model('billing');
    my %r;
    try {
        $billing->txn_do(sub {
            $r{contacts} = $billing->resultset('contacts')->create({ %{ $defaults{contacts} } });
            $r{contracts} = $billing->resultset('contracts')->create({
                %{ $defaults{contracts} },
                contact_id => $r{contacts}->id,
            });
            $r{resellers} = $billing->resultset('resellers')->create({
                %{ $defaults{resellers} },
                contract_id => $r{contracts}->id,
            });
            $r{billing_mappings} = $billing->resultset('billing_mappings')->create({
                %{ $defaults{billing_mappings} },
                billing_profile_id => 1,
                contract_id => $r{contracts}->id,
                product_id => $billing->resultset('products')->search({ class => 'reseller' })->first->id,
            });
            $r{admins} = $billing->resultset('admins')->create({
                %{ $defaults{admins} },
                reseller_id => $r{resellers}->id,
            });
            NGCP::Panel::Utils::Contract::create_contract_balance(
                c => $c,
                profile => $r{billing_mappings}->billing_profile,
                contract => $r{contracts},
            );
        });
    } catch($e) {
        $c->log->error($e);
        $c->flash(messages => [{type => 'error', text => 'Creating reseller failed.'}]);
    };
    $c->flash(messages => [{type => 'success', text => "Reseller successfully created with login '".$defaults{admins}->{login}."' and password '".$defaults{admins}->{md5pass}."', please change your settings below!" }]);
    $c->res->redirect(sprintf('/reseller/%d/details', $r{resellers}->id), HTTP_SEE_OTHER);
    $c->detach;
    return;
}

__PACKAGE__->meta->make_immutable;

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
