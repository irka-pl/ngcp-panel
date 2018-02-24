package NGCP::Panel::Role::API::Numbers;
use NGCP::Panel::Utils::Generic qw(:all);

use Sipwise::Base;

use parent 'NGCP::Panel::Role::API';

use Data::HAL qw();
use Data::HAL::Link qw();
use NGCP::Panel::Form;

sub resource_name{
    return 'numbers';
}

sub dispatch_path{
    return '/api/numbers/';
}

sub relation{
    return 'http://purl.org/sipwise/ngcp-api/#rel-numbers';
}

sub get_form {
    my ($self, $c) = @_;
    if($c->user->roles eq "admin") {
        return NGCP::Panel::Form::get("NGCP::Panel::Form::Number::AdminAPI", $c);
    } elsif($c->user->roles eq "reseller") {
        #return NGCP::Panel::Form::get("NGCP::Panel::Form::Number::ResellerAPI", $c);
        # there is currently no difference in the form
        return NGCP::Panel::Form::get("NGCP::Panel::Form::Number::SubadminAPI", $c);
    } elsif($c->user->roles eq "subscriberadmin") {
        return NGCP::Panel::Form::get("NGCP::Panel::Form::Number::SubadminAPI", $c);
    }
    return;
}

sub _item_rs {
    my ($self, $c) = @_;

    my $item_rs = $c->model('DB')->resultset('voip_numbers')->search({
        'me.reseller_id' => { '!=' => undef },
        'me.subscriber_id' => { '!=' => undef },
        'subscriber.status' => { '!=' => 'terminated' },
    },{
        '+select' => [\'if(me.id=subscriber.primary_number_id,1,0)'],
        '+as' => ['is_primary'],
        join => 'subscriber'
    });
    if($c->user->roles eq "admin") {
    } elsif($c->user->roles eq "reseller") {
        $item_rs = $item_rs->search({
            'me.reseller_id' => $c->user->reseller_id,
        });
    } elsif($c->user->roles eq "subscriberadmin") {
        $item_rs = $item_rs->search({
            'subscriber.contract_id' => $c->user->account_id,
        });
    }

    if($c->req->param('type') && $c->req->param('type') eq "primary") {
        $item_rs = $item_rs->search({
            'voip_subscribers.id' => { '!=' => undef },
        }, {
            join => ['subscriber', 'voip_subscribers'],
        });
    } elsif($c->req->param('type') && $c->req->param('type') eq "alias") {
        $item_rs = $item_rs->search({
            'voip_subscribers.id' => { '=' => undef },
        }, {
            join => ['subscriber', 'voip_subscribers'],
        });
    }
    return $item_rs;
}

sub hal_links{
    my($self, $c, $item, $resource, $form) = @_;
    return [
        Data::HAL::Link->new(relation => 'ngcp:subscribers', href => sprintf("/api/subscribers/%d", $item->subscriber_id)),
    ];
}

sub post_process_hal_resource {
    my($self, $c, $item, $resource, $form) = @_;
    if($c->user->roles eq "admin") {
        $resource->{reseller_id} = int($item->reseller_id);
    }
    return $resource;
}

1;
# vim: set tabstop=4 expandtab:
