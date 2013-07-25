package NGCP::Panel::Utils::Datatables;
use strict;
use warnings;

use Sipwise::Base;
use List::Util qw/first/;
use Scalar::Util qw/blessed/;
use DateTime::Format::Strptime;

sub process {
    my ($c, $rs, $cols) = @_;

    my $aaData = [];
    my $totalRecords = $rs->count;
    my $displayRecords = 0;

    # check if we need to join more tables
    # TODO: can we nest it deeper than once level?
    for my $c(@{ $cols }) {
        my @parts = split /\./, $c->{name};
        if(@parts == 2) {
            $rs = $rs->search_rs(undef, {
                join => $parts[0],
                '+select' => [ $c->{name} ],
                '+as' => [ $c->{accessor} ],
            });
        } elsif(@parts > 2) {
            # TODO throw an error for now as we only support one level
        }
    }

    # generic searching
    my @searchColumns = ();
    foreach my $c(@{ $cols }) {
        # avoid amigious column names if we have the same column in different joined tables
        my $name = $c->{name} =~ /\./ ? $c->{name} : 'me.'.$c->{name};
        push @searchColumns, $name if $c->{search};
    }
    my $searchString = $c->request->params->{sSearch} // "";
    if($searchString) {
        $rs = $rs->search([ map{ +{ $_ => { like => '%'.$searchString.'%' } } } @searchColumns ]);
    }

    # data-range searching
    my $from_date = $c->request->params->{sSearch_0} // "";
    my $to_date = $c->request->params->{sSearch_1} // "";
    my $parser = DateTime::Format::Strptime->new(
        #pattern => '%Y-%m-%d %H:%M',
        pattern => '%Y-%m-%d',
    );
    if($from_date) {
        $from_date = $parser->parse_datetime($from_date);
    }
    if($to_date) {
        $to_date = $parser->parse_datetime($to_date);
    }
    @searchColumns = ();
    foreach my $c(@{ $cols }) {
        # avoid amigious column names if we have the same column in different joined tables
        my $name = $c->{name} =~ /\./ ? $c->{name} : 'me.'.$c->{name};
        if($c->{search_from_epoch} && $from_date) {
            $rs = $rs->search({
                $name => { '>=' => $from_date->epoch },
            });
        }
        if($c->{search_to_epoch} && $to_date) {
            $rs = $rs->search({
                $name => { '<=' => $to_date->epoch },
            });
        }
    }

    $displayRecords = $rs->count;

    # show specific row on top (e.g. if we come back from a newly created entry)
    my $topId = $c->request->params->{iIdOnTop};
    if(defined $topId) {
        if(defined(my $row = $rs->find($topId))) {
            push @{ $aaData }, _prune_row($cols, $row->get_inflated_columns);
            $rs = $rs->search({ 'me.id' => { '!=', $topId} });
        } else {
            $c->log->error("iIdOnTop id $topId not found in resultset " . ref $rs);
        }
    }


    # sorting
    my $sortColumn = $c->request->params->{iSortCol_0};
    my $sortDirection = $c->request->params->{sSortDir_0} || 'asc';
    if(defined $sortColumn && defined $sortDirection) {
        if('desc' eq lc $sortDirection) {
            $sortDirection = 'desc';
        } else {
            $sortDirection = 'asc';
        }

        # first, get the fields we're actually showing
        my @displayedFields = ();
        for my $c(@{ $cols }) {
            next unless $c->{title};
            # again, add 'me' to avoid ambiguous column names
            my $name = $c->{name} =~ /\./ ? $c->{name} : 'me.'.$c->{name};
            push @displayedFields, $name;
        }
        # ... and pick the name defined by the dt index
        my $sortName = $displayedFields[$sortColumn];

        $rs = $rs->search(undef, {
            order_by => {
                "-$sortDirection" => $sortName,
            }
        });
    }

    # pagination
    my $pageStart = $c->request->params->{iDisplayStart};
    my $pageSize = $c->request->params->{iDisplayLength};
    if(defined $pageStart && defined $pageSize && $pageSize > 0) {
        $rs = $rs->search(undef, {
            offset => $pageStart,
            rows => $pageSize,
        });
    }

    for my $row ($rs->all) {
        push @{ $aaData }, _prune_row($cols, $row->get_inflated_columns);
    }

    $c->stash(
        aaData               => $aaData,
        iTotalRecords        => $totalRecords,
        iTotalDisplayRecords => $displayRecords,
        sEcho                => int($c->request->params->{sEcho} // 1),
    );

}

sub set_columns {
    my ($c, $cols) = @_;

    for my $c(@{ $cols }) {
        $c->{accessor} = $c->{name};
        $c->{accessor} =~ s/\./_/g;
    }
    return $cols;
}

sub _prune_row {
    my ($columns, %row) = @_;
    while (my ($k,$v) = each %row) {
        unless (first { $_->{accessor} eq $k && $_->{title} } @{ $columns }) {
            delete $row{$k};
            next;
        }
        if(blessed($v) && $v->isa('DateTime')) {
            $row{$k} = $v->ymd('-') . ' ' . $v->hms(':');
            $row{$k} .= '.'.$v->millisecond if $v->millisecond > 0.0;
        }
    }
    return { %row };
}


1;

# vim: set tabstop=4 expandtab:
