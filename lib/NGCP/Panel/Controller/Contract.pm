package NGCP::Panel::Controller::Contract;
use Sipwise::Base;

BEGIN { extends 'Catalyst::Controller'; }
use NGCP::Panel::Form::Contract;
use NGCP::Panel::Utils::Navigation;
use NGCP::Panel::Utils::Contract;
use NGCP::Panel::Utils::Subscriber;

sub auto :Does(ACL) :ACLDetachTo('/denied_page') :AllowedRole(admin) :AllowedRole(reseller) {
    my ($self, $c) = @_;
    $c->log->debug(__PACKAGE__ . '::auto');
    NGCP::Panel::Utils::Navigation::check_redirect_chain(c => $c);
    return 1;
}

sub contract_list :Chained('/') :PathPart('contract') :CaptureArgs(0) {
    my ($self, $c) = @_;

    $c->stash->{contract_dt_columns} = NGCP::Panel::Utils::Datatables::set_columns($c, [
        { name => "id", search => 1, title => "#" },
        { name => "external_id", search => 1, title => "External #" },
        { name => "contact.reseller.name", search => 1, title => "Reseller" },
        { name => "contact.email", search => 1, title => "Contact Email" },
        { name => "billing_mappings.billing_profile.name", search => 1, title => "Billing Profile" },
        { name => "status", search => 1, title => "Status" },
    ]);

    my $mapping_rs = $c->model('DB')->resultset('billing_mappings');
    my $rs = $c->model('DB')->resultset('contracts')
        ->search({
            'me.status' => { '!=' => 'terminated' },
            'billing_mappings.id' => {
                '=' => $mapping_rs->search({
                    contract_id => { -ident => 'me.id' },
                    start_date => [ -or =>
                        { '<=' => DateTime->now },
                        { -is  => undef },
                    ],
                    end_date => [ -or =>
                        { '>=' => DateTime->now },
                        { -is  => undef },
                    ],
                },{
                    alias => 'bilmap',
                    rows => 1,
                    order_by => {-desc => ['bilmap.start_date', 'bilmap.id']},
                })->get_column('id')->as_query,
            },
        },{
            'join' => 'billing_mappings',
            '+select' => [
                'billing_mappings.id',
                'billing_mappings.start_date',
            ],
            '+as' => [
                'billing_mapping_id',
                'billing_mapping_start_date',
            ],
            alias => 'me',
        });

    unless($c->user->is_superuser) {
        $rs = $rs->search({
            'contact.reseller_id' => $c->user->reseller_id,
        }, {
            join => 'contact',
        });
    }
    $c->stash(contract_select_rs => $rs);

    $c->stash(ajax_uri => $c->uri_for_action("/contract/ajax"));
    $c->stash(template => 'contract/list.tt');
}

sub root :Chained('contract_list') :PathPart('') :Args(0) {
    my ($self, $c) = @_;
}

sub create :Chained('contract_list') :PathPart('create') :Args(0) {
    my ($self, $c, $no_reseller) = @_;
    
    my $posted = ($c->request->method eq 'POST');
    my $params = {};
    $params = $params->merge($c->session->{created_objects});
    my $form;
    $form = NGCP::Panel::Form::Contract->new;
    $form->process(
        posted => $posted,
        params => $c->request->params,
        item => $params
    );

    my $suffix = '';
    if($c->user->is_superuser && $no_reseller) {
        $suffix = '/noreseller';
    }
    NGCP::Panel::Utils::Navigation::check_form_buttons(
        c => $c,
        form => $form,
        fields => {'contact.create' => $c->uri_for('/contact/create'.$suffix),
                   'billing_profile.create'  => $c->uri_for('/billing/create'.$suffix)},
        back_uri => $c->req->uri,
    );
    if($posted && $form->validated) {
        try {
            my $schema = $c->model('DB');
            $schema->txn_do(sub {
                $form->params->{contact_id} = $form->params->{contact}{id};
                delete $form->params->{contract};
                my $bprof_id = $form->params->{billing_profile}{id};
                delete $form->params->{billing_profile};
                my $contract = $schema->resultset('contracts')->create($form->params);
                my $billing_profile = $schema->resultset('billing_profiles')->find($bprof_id);
                $contract->billing_mappings->create({
                    billing_profile_id => $bprof_id,
                });
                
                NGCP::Panel::Utils::Contract::create_contract_balance(
                    c => $c,
                    profile => $billing_profile,
                    contract => $contract,
                );
                delete $c->session->{created_objects}->{contact};
                delete $c->session->{created_objects}->{billing_profile};
                $c->session->{created_objects}->{contract} = { id => $contract->id };
                $c->flash(messages => [{type => 'success', text => 'Contract successfully created!'}]);
            });
        } catch($e) {
            $c->log->error("Failed to create contract: $e");
            $c->flash(messages => [{type => 'error', text => 'Failed to create contract'}]);
        }
        NGCP::Panel::Utils::Navigation::back_or($c, $c->uri_for('/contract'));
    } 

    $c->stash(create_flag => 1);
    $c->stash(form => $form);
}

sub create_without_reseller :Chained('contract_list') :PathPart('create/noreseller') :Args(0) {
    my ($self, $c) = @_;
    $self->create($c, 1);
}

sub base :Chained('contract_list') :PathPart('') :CaptureArgs(1) {
    my ($self, $c, $contract_id) = @_;

    unless($contract_id && $contract_id->is_integer) {
        $c->flash(messages => [{type => 'error', text => 'Invalid contract id detected!'}]);
        NGCP::Panel::Utils::Navigation::back_or($c, $c->uri_for('/contract'));
    }

    my $res = $c->stash->{contract_select_rs};
    $res = $res->search(undef, {
            '+select' => 'billing_mappings.id',
            '+as' => 'bmid',
        })
        ->find($contract_id);

    unless(defined($res)) {
        $c->flash(messages => [{type => 'error', text => 'Contract does not exist'}]);
        NGCP::Panel::Utils::Navigation::back_or($c, $c->uri_for('/contract'));
    }
    
    $c->stash(contract => {$res->get_inflated_columns});
    $c->stash(contract_result => $res);
    return;
}

sub edit :Chained('base') :PathPart('edit') :Args(0) {
    my ($self, $c) = @_;

    my $posted = ($c->request->method eq 'POST');
    
    my $contract = $c->stash->{contract_result};
    my $billing_mapping = $contract->billing_mappings->find($contract->get_column('bmid'));
    my $params = {};
    $params = $params->merge($c->session->{created_objects});
    unless($posted) {
        $params->{billing_profile}{id} = $billing_mapping->billing_profile->id;
        $params->{contact}{id} = $contract->contact_id;
        $params->{external_id} = $contract->external_id;
        $params->{status} = $contract->status;
    }

    # TODO: handle created contact/bilprof

    my $form = NGCP::Panel::Form::Contract->new;
    $form->process(
        posted => $posted,
        params => $c->req->params,
        item => $params,
    );
    NGCP::Panel::Utils::Navigation::check_form_buttons(
        c => $c, form => $form,
        fields => {'contract.contact.create' => $c->uri_for('/contact/create'),
                   'billing_profile.create'  => $c->uri_for('/billing/create')},
        back_uri => $c->req->uri,
    );
    if($posted && $form->validated) {
        try {
            my $schema = $c->model('DB');
            $schema->txn_do(sub {
                if($form->values->{billing_profile}{id} != $billing_mapping->billing_profile->id) {
                    $contract->billing_mappings->create({
                        start_date => DateTime->now(),
                        billing_profile_id => $form->values->{billing_profile}{id},
                    });
                }
                my $old_status = $contract->status;
                delete $form->values->{billing_profile};
                $form->values->{contact_id} = $form->values->{contact}{id};
                delete $form->values->{contact};
                $contract->update($form->values);

                # if status changed, populate it down the chain
                if($contract->status ne $old_status) {
                    NGCP::Panel::Utils::Contract::recursively_lock_contract(
                        c => $c,
                        contract => $contract,
                    );
                }

                delete $c->session->{created_objects}->{contact};
                delete $c->session->{created_objects}->{billing_profile};
            });
            $c->flash(messages => [{type => 'success', text => 'Contract successfully changed!'}]);
        } catch($e) {
            $c->log->error("failed to update contract: $e");
            $c->flash(messages => [{type => 'error', text => 'Failed to update contract'}]);
        }
        NGCP::Panel::Utils::Navigation::back_or($c, $c->uri_for('/contract'));
    }

    $c->stash(form => $form);
    $c->stash(edit_flag => 1);
}

sub terminate :Chained('base') :PathPart('terminate') :Args(0) {
    my ($self, $c) = @_;

    try {
        my $contract = $c->stash->{contract_result};
        my $old_status = $contract->status;
        $contract->update({ status => 'terminated' });
        # if status changed, populate it down the chain
        if($contract->status ne $old_status) {
            NGCP::Panel::Utils::Contract::recursively_lock_contract(
                c => $c,
                contract => $contract,
            );
        }
        $c->flash(messages => [{type => 'success', text => 'Contract successfully terminated'}]);
    } catch (DBIx::Class::Exception $e) {
        $c->log->info("failed to terminate contract: $e");
        $c->flash(messages => [{type => 'error', text => 'Failed to terminate contract'}]);
    };
    NGCP::Panel::Utils::Navigation::back_or($c, $c->uri_for('/contract'));
}

sub ajax :Chained('contract_list') :PathPart('ajax') :Args(0) {
    my ($self, $c) = @_;
    
    my $res = $c->stash->{contract_select_rs};
    NGCP::Panel::Utils::Datatables::process($c, $res, $c->stash->{contract_dt_columns});
    $c->detach( $c->view("JSON") );
}

sub peering_list :Chained('contract_list') :PathPart('peering') :CaptureArgs(0) {
    my ($self, $c) = @_;

    $c->stash(ajax_uri => $c->uri_for_action("/contract/peering_ajax"));
}

sub peering_root :Chained('peering_list') :PathPart('') :Args(0) {

}

sub peering_ajax :Chained('peering_list') :PathPart('ajax') :Args(0) {
    my ($self, $c) = @_;
    
    my $base_rs = $c->stash->{contract_select_rs};
    my $rs = $base_rs->search({
            'product.class' => 'sippeering',
        }, {
            'join' => {'billing_mappings' => 'product'},
        });
   
    NGCP::Panel::Utils::Datatables::process($c, $rs,  $c->stash->{contract_dt_columns});
    $c->detach( $c->view("JSON") );
}

sub peering_create :Chained('peering_list') :PathPart('create') :Args(0) {
    my ($self, $c) = @_;

    my $posted = ($c->request->method eq 'POST');
    my $params = {};
    $params = $params->merge($c->session->{created_objects});
    my $form = NGCP::Panel::Form::Contract->new;
    $form->process(
        posted => $posted,
        params => $c->request->params,
        item => $params
    );
    NGCP::Panel::Utils::Navigation::check_form_buttons(
        c => $c,
        form => $form,
        fields => {'contact.create' => $c->uri_for('/contact/create/noreseller'),
                   'billing_profile.create'  => $c->uri_for('/billing/create/noreseller')},
        back_uri => $c->req->uri,
    );
    if($posted && $form->validated) {
        try {
            my $schema = $c->model('DB');
            $schema->txn_do(sub {
                $form->params->{contact_id} = $form->params->{contact}{id};
                delete $form->params->{contract};
                my $bprof_id = $form->params->{billing_profile}{id};
                delete $form->params->{billing_profile};
                my $contract = $schema->resultset('contracts')->create($form->params);
                my $billing_profile = $schema->resultset('billing_profiles')->find($bprof_id);
                my $product = $schema->resultset('products')->find({ class => 'sippeering' }); 
                $contract->billing_mappings->create({
                    billing_profile_id => $bprof_id,
                    product_id => $product->id,
                });
                
                NGCP::Panel::Utils::Contract::create_contract_balance(
                    c => $c,
                    profile => $billing_profile,
                    contract => $contract,
                );
                $c->session->{created_objects}->{contract} = { id => $contract->id };
                delete $c->session->{created_objects}->{contact};
                delete $c->session->{created_objects}->{billing_profile};
                $c->flash(messages => [{type => 'success', text => 'Contract successfully created'}]);
            });
        } catch($e) {
            $c->log->error("Failed to create contract: $e");
            $c->flash(messages => [{type => 'error', text => 'Failed to create contract'}]);
        }
        NGCP::Panel::Utils::Navigation::back_or($c, $c->uri_for('/contract'));
    } 

    $c->stash(create_flag => 1);
    $c->stash(form => $form);
}

sub customer_list :Chained('contract_list') :PathPart('customer') :CaptureArgs(0) {
    my ($self, $c) = @_;

    $c->stash(ajax_uri => $c->uri_for_action("/contract/customer_ajax"));
}

sub customer_root :Chained('customer_list') :PathPart('') :Args(0) {

}

sub customer_ajax :Chained('customer_list') :PathPart('ajax') :Args(0) {
    my ($self, $c) = @_;
    
    my $base_rs = $c->stash->{contract_select_rs};
    my $rs = $base_rs->search({
            'product_id' => undef,
        }, {
            'join' => {'billing_mappings' => 'product'},
        });
   
    NGCP::Panel::Utils::Datatables::process($c, $rs,  $c->stash->{contract_dt_columns});
    $c->detach( $c->view("JSON") );
}

sub customer_create :Chained('customer_list') :PathPart('create') :Args(0) {
    my ($self, $c) = @_;

    my $posted = ($c->request->method eq 'POST');
    my $params = {};
    $params = $params->merge($c->session->{created_objects});
    my $form = NGCP::Panel::Form::Contract->new;
    $form->process(
        posted => $posted,
        params => $c->request->params,
        item => $params
    );
    NGCP::Panel::Utils::Navigation::check_form_buttons(
        c => $c,
        form => $form,
        fields => {'contact.create' => $c->uri_for('/contact/create'),
                   'billing_profile.create'  => $c->uri_for('/billing/create')},
        back_uri => $c->req->uri,
    );
    if($posted && $form->validated) {
        try {
            my $schema = $c->model('DB');
            $schema->txn_do(sub {
                $form->params->{contact_id} = $form->params->{contact}{id};
                delete $form->params->{contract};
                my $bprof_id = $form->params->{billing_profile}{id};
                delete $form->params->{billing_profile};
                my $contract = $schema->resultset('contracts')->create($form->params);
                my $billing_profile = $schema->resultset('billing_profiles')->find($bprof_id);
                $contract->billing_mappings->create({
                    billing_profile_id => $bprof_id,
                });
                
                NGCP::Panel::Utils::Contract::create_contract_balance(
                    c => $c,
                    profile => $billing_profile,
                    contract => $contract,
                );
                $c->session->{created_objects}->{contract} = { id => $contract->id };
                delete $c->session->{created_objects}->{contact};
                delete $c->session->{created_objects}->{billing_profile};
                $c->flash(messages => [{type => 'success', text => 'Contract successfully created'}]);
            });
        } catch($e) {
            $c->log->error("Failed to create contract: $e");
            $c->flash(messages => [{type => 'error', text => 'Failed to create contract'}]);
        }
        NGCP::Panel::Utils::Navigation::back_or($c, $c->uri_for('/contract'));
    } 

    $c->stash(create_flag => 1);
    $c->stash(form => $form);
}

__PACKAGE__->meta->make_immutable;

1;

=head1 NAME

NGCP::Panel::Controller::Contract - Catalyst Controller

=head1 DESCRIPTION

View and edit Contracts. Optionally filter them by only peering contracts.

=head1 METHODS

=head2 contract_list

Basis for contracts.

=head2 root

Display contracts through F<contract/list.tt> template.

=head2 create

Show modal dialog to create a new contract.

=head2 base

Capture id of existing contract. Used for L</edit> and L</delete>. Stash "contract" and "contract_result".

=head2 edit

Show modal dialog to edit a contract.

=head2 delete

Delete a contract.

=head2 ajax

Get contracts from the database and output them as JSON.
The output format is meant for parsing with datatables.

The selected rows should be billing.billing_mappings JOIN billing.contracts with only one billing_mapping per contract (the one that fits best with the time).

=head2 peering_list

Basis for peering_contracts.

=head2 peering_root

Display contracts through F<contract/list.tt> template. Use L</peering_ajax> as data source.

=head2 peering_ajax

Similar to L</ajax>. Only select contracts, where billing.product is of class "sippeering".

=head2 peering_create

Similar to L</create> but sets product_id of billing_mapping to match the
product of class "sippeering".

=head1 AUTHOR

Andreas Granig,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

# vim: set tabstop=4 expandtab:
