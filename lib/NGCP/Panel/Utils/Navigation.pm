package NGCP::Panel::Utils::Navigation;
use strict;
use warnings;

use Sipwise::Base;
use DBIx::Class::Exception;

sub check_redirect_chain {
    my %params = @_;

    # TODO: check for missing fields
    my $c = $params{c};

    if($c->session->{redirect_targets} && @{ $c->session->{redirect_targets} }) {
        my $target = ${ $c->session->{redirect_targets} }[0];
        if('/'.$c->request->path eq $target->path) {
            shift @{$c->session->{redirect_targets}};
            $c->stash(close_target => ${ $c->session->{redirect_targets} }[0]);
        } else {
            $c->stash(close_target => $target);
        }
    }
}

sub check_form_buttons {
    my %params = @_;

    # TODO: check for missing fields
    my $c = $params{c};
    my $fields = $params{fields};
    my $form = $params{form};
    my $back_uri = $params{back_uri};
    
    $fields = { map {($_, undef)} @$fields }
        if (ref($fields) eq "ARRAY");

    my $posted = ($c->request->method eq 'POST');

    if($posted && $form->field('submitid')) {
        my $val = $form->field('submitid')->value;
        if(defined $val and exists($fields->{$val}) ) {
            my $target;
            if (defined $fields->{$val}) {
                $target = $fields->{$val};
            } else {
                $target = '/'.$val;
                $target =~ s/\./\//g;
                $target = $c->uri_for($target);
            }
            if($c->session->{redirect_targets}) {
                unshift @{ $c->session->{redirect_targets} }, $back_uri;
            } else {
                $c->session->{redirect_targets} = [ $back_uri ];
            }
            $c->response->redirect($target);
            return 1;
        }
    }
    return;
}

1;

=head1 NAME

NGCP::Panel::Utils::Navigation

=head1 DESCRIPTION

A temporary helper to manipulate subscriber data

=head1 METHODS

=head2 check_redirect_chain

Sets close_target to the next uri in our redirect_chain if it exists.
Puts close_target to stash, which will be read by the templates.

=head2 check_form_buttons

Parameters:
    c
    fields - either an arrayref of fieldnames or a hashref with fieldnames
        key and redirect target as value (where it should redirect to)
    form
    back_uri - the uri we come from

Checks the hidden field "submitid" and redirects to its "value" when it
matches a field.

=head1 AUTHOR

Andreas Granig,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
# vim: set tabstop=4 expandtab:
