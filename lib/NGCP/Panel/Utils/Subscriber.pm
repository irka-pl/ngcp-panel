package NGCP::Panel::Utils::Subscriber;
use strict;
use warnings;

use Sipwise::Base;
use DBIx::Class::Exception;
use NGCP::Panel::Utils::DateTime;
use NGCP::Panel::Utils::Preferences;
use UUID qw/generate unparse/;

my %LOCK = (
    0, 'none',
    1, 'foreign',
    2, 'outgoing',
    3, 'incoming and outgoing',
    4, 'global',
);


sub period_as_string {
    my $set = shift;

    my @wdays = (qw/
        invalid Sunday Monday Tuesday Wednesday Thursday Friday Saturday    
    /);
    my @months = (qw/
        invalid January February March April May June July August September October November December
    /);

    my $string = "";
    foreach my $type(qw/year month mday wday hour minute/) {
        my $s = $set->{$type};
        if(defined $s) {
            given($type) {
                when(/^month$/) { 
                    my ($from, $to) = split /\-/, $s;
                    $s = $months[$from];
                    $s .= '-'.$months[$to] if defined($to);
                }
                when(/^wday$/) { 
                    my ($from, $to) = split /\-/, $s;
                    $s = $wdays[$from];
                    $s .= '-'.$wdays[$to] if defined($to);
                }
            }
        }
        $string .= "$type { $s } " if defined($s);
    }
    return $string;
}

sub destination_as_string {
    my $destination = shift;
    my $dest = $destination->{destination};

    if($dest =~ /\@voicebox\.local$/) {
        return "VoiceMail";
    } elsif($dest =~ /\@fax2mail\.local$/) {
        return "Fax2Mail";
    } elsif($dest =~ /\@conference\.local$/) {
        return "Conference";
    } elsif($dest =~ /^sip:callingcard\@app\.local$/) {
        return "CallingCard";
    } elsif($dest =~ /^sip:callthrough\@app\.local$/) {
        return "CallThrough";
    } elsif($dest =~ /^sip:localuser\@.+\.local$/) {
        return "Local Subscriber";
    } elsif($dest =~ /^sip:auto-attendant\@app\.local$/) {
        return "Auto Attendant";
    } elsif($dest =~ /^sip:office-hours\@app\.local$/) {
        return "Office Hours Announcement";
    } else {
        my $d = $dest;
        $d =~ s/sip:(.+)\@.+$/$1/;
        if($d->is_int) {
            return $d;
        } else {
            return $dest;
        }
    }
}

sub lock_provisoning_voip_subscriber {
    my %params = @_;

    my $c = $params{c};
    my $prov_subscriber= $params{prov_subscriber};
    my $level = $params{level};

    return unless $prov_subscriber;

    my $rs = NGCP::Panel::Utils::Preferences::get_usr_preference_rs(
        c => $c, 
        prov_subscriber => $prov_subscriber, 
        attribute => 'lock'
    );
    try {
        if($rs->first) {
            if($level == 0) {
                $rs->first->delete;
            } else {
                $rs->first->update({ value => $level });
            }
        } elsif($level > 0) { # nothing to do for level 0, if no lock is set yet
            $rs->create({ value => $level });
        }
    } catch($e) {
        $c->log->error("failed to set provisioning_voip_subscriber lock: $e");
        $e->rethrow;
    }
}

sub get_lock_string {
    my $level = shift;
    return $LOCK{$level};
}

sub get_admin_subscribers {
    my %params = @_;
    my $subs = $params{voip_subscribers};
    my @subscribers = ();
    foreach my $s(@{ $subs }) {
        push @subscribers, $s if($s->{admin});
    }
    return \@subscribers;
}

sub create_subscriber {
    my %params = @_;
    my $c = $params{c};

    my $contract = $params{contract};
    my $params = $params{params};
    my $administrative = $params{admin_default};
    my $preferences = $params{preferences};

    my $schema = $params{schema} // $c->model('DB');
    my $reseller = $contract->contact->reseller;
    my $billing_domain = $schema->resultset('domains')
            ->find($params->{domain}{id} // $params->{domain_id});
    my $prov_domain = $schema->resultset('voip_domains')
            ->find({domain => $billing_domain->domain});
    
    $schema->txn_do(sub {
        my ($uuid_bin, $uuid_string);
        UUID::generate($uuid_bin);
        UUID::unparse($uuid_bin, $uuid_string);

        # TODO: check if we find a reseller and contract and domains

        my $billing_subscriber = $contract->voip_subscribers->create({
            uuid => $uuid_string,
            username => $params->{username},
            domain_id => $billing_domain->id,
            status => $params->{status},
            external_id => ((defined $params->{external_id} && length $params->{external_id}) ? $params->{external_id} : undef), # make null if empty
            primary_number_id => undef, # will be filled in next step
        });
        my ($cli);
        if(defined $params->{e164}{cc} && $params->{e164}{cc} ne '') {
            $cli = $params->{e164}{cc} .
                ($params->{e164}{ac} || '') .
                $params->{e164}{sn};

            update_subscriber_numbers(
                schema => $schema,
                subscriber_id => $billing_subscriber->id,
                reseller_id => $reseller->id,
                primary_number => $params->{e164},
            );
        }

        unless(exists $params->{password}) {
            my ($pass_bin, $pass_str);
            UUID::generate($pass_bin);
            UUID::unparse($pass_bin, $pass_str);
            $params->{password} = $pass_str;
        }
        my $prov_subscriber = $schema->resultset('provisioning_voip_subscribers')->create({
            uuid => $uuid_string,
            username => $params->{username},
            password => $params->{password},
            webusername => $params->{webusername} || $params->{username},
            webpassword => $params->{webpassword},
            admin => $params->{administrative} // $administrative,
            account_id => $contract->id,
            domain_id => $prov_domain->id,
            is_pbx_group => $params->{is_pbx_group} // 0,
            pbx_group_id => $params->{pbx_group_id},
            create_timestamp => NGCP::Panel::Utils::DateTime::current_local,
        });

        $preferences->{account_id} = $contract->id;
        $preferences->{ac} = $params->{e164}{ac}
            if(defined $params->{e164}{ac} && length($params->{e164}{ac}) > 0);
        $preferences->{cc} = $params->{e164}{cc}
            if(defined $params->{e164}{cc} && length($params->{e164}{cc}) > 0);
        $preferences->{cli} = $cli
            if(defined $cli);

        update_preferences(c => $c, 
            prov_subscriber => $prov_subscriber, 
            preferences => $preferences
        );

        $schema->resultset('voicemail_users')->create({
            customer_id => $uuid_string,
            mailbox => $cli // 0,
            password => sprintf("%04d", int(rand 10000)),
            email => '',
        });
        if($cli) {
            $schema->resultset('voip_dbaliases')->create({
                username => $cli,
                domain_id => $prov_subscriber->domain->id,
                subscriber_id => $prov_subscriber->id,
            });
        }

        return $billing_subscriber;
    });
}

sub update_preferences {
    my (%params) = @_;
    my $c = $params{c};
    my $prov_subscriber = $params{prov_subscriber};
    my $preferences = $params{preferences};

    foreach my $k(keys %{ $preferences } ) {
        my $pref = NGCP::Panel::Utils::Preferences::get_usr_preference_rs(
            c => $c, attribute => $k, prov_subscriber => $prov_subscriber);
        if($pref->first && $pref->first->attribute->max_occur == 1) {
            unless(defined $preferences->{$k}) {
                $pref->first->delete;
            } else {
                $pref->first->update({ 
                    'value' => $preferences->{$k},
                });
            }
        } else {
            $pref->create({ 
                'value' => $preferences->{$k},
            }) if(defined $preferences->{$k});
        }
    }
}

sub get_custom_subscriber_struct {
    my %params = @_;

    my $c = $params{c};
    my $contract = $params{contract};

    my @subscribers = ();
    my @pbx_groups = ();
    my $voip_sub_rs = $contract->voip_subscribers;
    if($params{show_locked}) {
        $voip_sub_rs = $voip_sub_rs->search_rs({ status => { -in => [ 'active', 'locked' ] } });
    } else {
        $voip_sub_rs = $voip_sub_rs->search_rs({ status => 'active' });
    }
    foreach my $s($voip_sub_rs->all) {
        my $sub = { $s->get_columns };
        if($c->config->{features}->{cloudpbx}) {
            $sub->{voip_pbx_group} = { $s->provisioning_voip_subscriber->voip_pbx_group->get_columns }
                if($s->provisioning_voip_subscriber->voip_pbx_group);
        }
        $sub->{domain} = $s->domain->domain;
        $sub->{admin} = $s->provisioning_voip_subscriber->admin if
            $s->provisioning_voip_subscriber;
        $sub->{primary_number} = {$s->primary_number->get_columns} if(defined $s->primary_number);
        $sub->{locations} = [ map { { $_->get_columns } } $c->model('DB')->resultset('location')->
            search({
                username => $s->username,
                ($c->config->{features}->{multidomain}) ? (domain => $s->domain->domain) : (),
            })->all ];
        if($c->config->{features}->{cloudpbx} && $s->provisioning_voip_subscriber->is_pbx_group) {
            my $grp = $contract->voip_pbx_groups->find({ subscriber_id => $s->provisioning_voip_subscriber->id });
            $sub->{voip_pbx_group} = { $grp->get_columns } if $grp;
            push @pbx_groups, $sub;
        } else {
            push @subscribers, $sub;
        }
    }

    return { subscribers => \@subscribers, pbx_groups => \@pbx_groups };
}

sub update_pbx_group_prefs {
    my %params = @_;

    my $c = $params{c};
    my $schema = $params{schema} // $c->model('DB');
    my $old_group_id = $params{old_group_id};
    my $new_group_id = $params{new_group_id};
    my $username = $params{username};
    my $domain = $params{domain};

    return if(defined $old_group_id && defined $new_group_id && $old_group_id == $new_group_id);

    my $old_grp_subscriber;
    my $new_grp_subscriber;

    my $uri = "sip:$username\@$domain";
    if($old_group_id) {
        $old_grp_subscriber= $c->model('DB')->resultset('voip_pbx_groups')
                        ->find($old_group_id)
                        ->provisioning_voip_subscriber;
        if($old_grp_subscriber) {
            my $grp_pref_rs = NGCP::Panel::Utils::Preferences::get_usr_preference_rs(
                c => $c, attribute => 'cloud_pbx_hunt_group', prov_subscriber => $old_grp_subscriber
            );
            my $pref = $grp_pref_rs->find({ value => $uri });
            $pref->delete if($pref);
        }
    }
    if($new_group_id) {
        $new_grp_subscriber = $c->model('DB')->resultset('voip_pbx_groups')
                        ->find($new_group_id)
                        ->provisioning_voip_subscriber;
        if($new_grp_subscriber) {
            my $grp_pref_rs = NGCP::Panel::Utils::Preferences::get_usr_preference_rs(
                c => $c, attribute => 'cloud_pbx_hunt_group', prov_subscriber => $new_grp_subscriber
            );
            unless($grp_pref_rs->find({ value => $uri })) {
                $grp_pref_rs->create({ value => $uri });
            }
        }
    }
}

sub update_subscriber_numbers {
    my %params = @_;

    my $schema         = $params{schema};
    my $subscriber_id  = $params{subscriber_id};
    my $reseller_id    = $params{reseller_id};
    my $primary_number = $params{primary_number};
    my $alias_numbers  = $params{alias_numbers}; # alias numbers

    my $billing_subs = $schema->resultset('voip_subscribers')->find({
            id => $subscriber_id,
        });
    my $prov_subs = $billing_subs->provisioning_voip_subscriber;
    my @nums = (); my @dbnums = ();

    if(exists $params{primary_number} && !defined $primary_number) {
        $billing_subs->update({
            primary_number_id => undef,
        });
    }
    elsif(defined $primary_number) {

        my $old_cc;
        my $old_ac;
        my $old_sn;
        if (defined $billing_subs->primary_number) {
            $old_cc = $billing_subs->primary_number->cc;
            $old_ac = $billing_subs->primary_number->ac;
            $old_sn = $billing_subs->primary_number->sn;
        }

        my $number;
        if (defined $primary_number->{cc}
            && $primary_number->{cc} ne '') {

            my $old_number = $schema->resultset('voip_numbers')->search({
                    cc            => $primary_number->{cc},
                    ac            => $primary_number->{ac} // '',
                    sn            => $primary_number->{sn},
                    subscriber_id => [undef, $subscriber_id],
                },{
                    for => 'update',
                })->first;

            if(defined $old_number) {
                $old_number->update({
                    status        => 'active',
                    reseller_id   => $reseller_id,
                    subscriber_id => $subscriber_id,
                });
                $number = $old_number;
            } else {
                $number = $schema->resultset('voip_numbers')->create({
                    cc            => $primary_number->{cc},
                    ac            => $primary_number->{ac} // '',
                    sn            => $primary_number->{sn},
                    status        => 'active',
                    reseller_id   => $reseller_id,
                    subscriber_id => $subscriber_id,
                });
            }
        }

        if(defined $number) {
            my $cli = $number->cc . ($number->ac // '') . $number->sn;

            if(defined $billing_subs->primary_number
                && $billing_subs->primary_number_id != $number->id) {
                $billing_subs->primary_number->delete;
            }
            $billing_subs->update({
                    primary_number_id => $number->id,
                });
            if(defined $prov_subs) {
                my $dbalias = $prov_subs->voip_dbaliases->find({
                    username => $cli,
                });
                if($dbalias) {
                    if(!$dbalias->is_primary) {
                        $dbalias->update({ is_primary => 1 });
                    }
                } else {
                    $dbalias = $prov_subs->voip_dbaliases->create({
                        username => $cli,
                        domain_id => $prov_subs->domain->id,
                        is_primary => 1,
                    });
                }
                push @dbnums, $dbalias->id;
                if(defined $prov_subs->voicemail_user) {
                    $prov_subs->voicemail_user->update({
                        mailbox => $cli,
                    });
                }

                for my $cfset($prov_subs->voip_cf_destination_sets->all) {
                    for my $cf($cfset->voip_cf_destinations->all) {
                        if($cf->destination =~ /\@voicebox\.local$/) {
                            $cf->update({ destination => 'sip:vmu'.$cli.'@voicebox.local' });
                        } elsif($cf->destination =~ /\@fax2mail\.local$/) {
                            $cf->update({ destination => 'sip:'.$cli.'@fax2mail.local' });
                        } elsif($cf->destination =~ /\@conference\.local$/) {
                            $cf->update({ destination => 'sip:conf='.$cli.'@conference.local' });
                        }
                    }
                }
            }
        } else {
            if (defined $billing_subs->primary_number) {
                $billing_subs->primary_number->delete;
            }
            if(defined $prov_subs->voicemail_user) {
                $prov_subs->voicemail_user->update({ mailbox => '0' });
            }
        }

        if ( (defined $old_cc && defined $old_sn)
                && $billing_subs->contract->billing_mappings->first->product->class eq "pbxaccount"
                && ! defined $prov_subs->voip_pbx_group
                && $prov_subs->admin ) {
            my $customer_subscribers_rs = $billing_subs->contract->voip_subscribers;
            my $my_cc = $primary_number->{cc};
            my $my_ac = $primary_number->{ac};
            my $my_sn = $primary_number->{sn};
            my $new_base_cli = $my_cc . ($my_ac // '') . $my_sn;
            my $usr_preferences_base_cli_rs = $schema->resultset('voip_preferences')->find({
                    attribute => 'cloud_pbx_base_cli',
                })->voip_usr_preferences;
            $usr_preferences_base_cli_rs->search_rs({subscriber_id=>$prov_subs->id})->update_all({value => $new_base_cli});
            for my $sub ($customer_subscribers_rs->all) {
                next if $sub->id == $billing_subs->id; # myself
                next unless $sub->primary_number;
                next unless $sub->primary_number->cc == $old_cc;
                next unless $sub->primary_number->ac == $old_ac;
                next unless $sub->primary_number->sn =~ /^$old_sn/;
                $usr_preferences_base_cli_rs->search_rs({subscriber_id=>$sub->provisioning_voip_subscriber->id})->update_all({value => $new_base_cli});
                $schema->resultset('voip_dbaliases')->search_rs({
                    username => $old_cc . ($old_ac // '') . $sub->primary_number->sn,
                })->delete;
                update_subscriber_numbers(
                    schema => $schema,
                    subscriber_id => $sub->id,
                    reseller_id => $reseller_id,
                    primary_number => {
                        cc => $my_cc,
                        ac => $my_ac,
                        sn => $sub->primary_number->sn =~ s/^$old_sn/$my_sn/r,
                    }
                );
            }
        }

    }


    if(defined $alias_numbers && ref($alias_numbers) eq 'ARRAY') {
        my $number;
        for my $alias(@$alias_numbers) {

            my $old_number = $schema->resultset('voip_numbers')->search({
                    cc            => $alias->{e164}->{cc},
                    ac            => $alias->{e164}->{ac} // '',
                    sn            => $alias->{e164}->{sn},
                    subscriber_id => [undef, $subscriber_id],
                },{
                    for => 'update',
                })->first;

            if(defined $old_number) {
                $old_number->update({
                    status        => 'active',
                    reseller_id   => $reseller_id,
                    subscriber_id => $subscriber_id,
                });
                $number = $old_number;
            } else {
                $number = $schema->resultset('voip_numbers')->create({
                    cc            => $alias->{e164}->{cc},
                    ac            => $alias->{e164}->{ac} // '',
                    sn            => $alias->{e164}->{sn},
                    status        => 'active',
                    reseller_id   => $reseller_id,
                    subscriber_id => $subscriber_id,
                });
            }
            push @nums, $number->id;
            my $cli = $number->cc . ($number->ac // '') . $number->sn;
            my $dbalias = $prov_subs->voip_dbaliases->find({
                username => $cli,
            });
            if($dbalias) {
                if($dbalias->is_primary) {
                    $dbalias->update({ is_primary => 0 });
                }
            } else {
                $dbalias = $prov_subs->voip_dbaliases->create({
                    username => $cli,
                    domain_id => $prov_subs->domain->id,
                    is_primary => 0,
                });
            }
            push @dbnums, $dbalias->id;
        }
    }

    push @nums, $billing_subs->primary_number_id
        if($billing_subs->primary_number_id);
    $billing_subs->voip_numbers->search({
        id => { 'not in' => \@nums },
    })->update_all({
        subscriber_id => undef,
        reseller_id => undef,
    });
    if($prov_subs) {
        $prov_subs->voip_dbaliases->search({
            id => { 'not in' => \@dbnums },
        })->delete;
    }

    return;
}

sub update_subadmin_sub_aliases {
    my %params = @_;

    my $schema         = $params{schema};
    my $subscriber_id  = $params{subscriber_id};
    my $sadmin_id      = $params{sadmin_id};
    my $contract_id    = $params{contract_id};
    my $alias_selected = $params{alias_selected};

    my $num_rs = $schema->resultset('voip_numbers')->search_rs({
        'subscriber.contract_id' => $contract_id,
    },{
        prefetch => 'subscriber',
    });
    for my $num ($num_rs->all) {
        next if ($num->voip_subscribers->first); # is a primary number
        if ($num->id ~~ $alias_selected) {
            $num->update({
                subscriber_id => $subscriber_id
            });
        } elsif ($num->subscriber_id == $subscriber_id) { #unselected
            $num->update({
                subscriber_id => $sadmin_id
            });
        }
    }
}

sub terminate {
    my %params = @_;

    my $c = $params{c};
    my $subscriber = $params{subscriber};

    my $schema = $c->model('DB');
    $schema->txn_do(sub {
        if($subscriber->provisioning_voip_subscriber->is_pbx_group) {
            my $pbx_group = $schema->resultset('voip_pbx_groups')->find({
                subscriber_id => $subscriber->provisioning_voip_subscriber->id
            });
            if($pbx_group) {
                $pbx_group->provisioning_voip_subscribers->update_all({
                    pbx_group_id => undef,
                });
            }
            $pbx_group->delete;
        }
        my $prov_subscriber = $subscriber->provisioning_voip_subscriber;
        if($prov_subscriber) {
            update_pbx_group_prefs(
                c => $c,
                schema => $schema,
                old_group_id => $prov_subscriber->voip_pbx_group->id,
                new_group_id => undef,
                username => $prov_subscriber->username,
                domain => $prov_subscriber->domain->domain,
            ) if($prov_subscriber->voip_pbx_group);
            $prov_subscriber->delete;
        }
        if ($c->user->roles eq 'subscriberadmin') {
            update_subadmin_sub_aliases(
                schema => $schema,
                subscriber_id => $subscriber->id,
                contract_id => $subscriber->contract_id,
                alias_selected => [], #none, thus moving them back to our subadmin
                sadmin_id => $schema->resultset('voip_subscribers')
                    ->find({uuid => $c->user->uuid})->id
            );
        } else {
            $subscriber->voip_numbers->update_all({
                subscriber_id => undef,
                reseller_id => undef,
            });
        }
        $subscriber->update({ status => 'terminated' });
    });
}

1;

=head1 NAME

NGCP::Panel::Utils::Subscriber

=head1 DESCRIPTION

A temporary helper to manipulate subscriber data

=head1 METHODS

=head2 update_subscriber_numbers

This reimplements the behavior of ossbss. When adding numbers to a subscriber,
we first check, if the number is already available in voip_numbers but
has no subscriber_id set. In that case we can just reuse that number.
If the number does not exist at all, we just create it.
For reference see _get_number_for_update() in ossbss.

=head1 AUTHOR

Andreas Granig,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
# vim: set tabstop=4 expandtab:
