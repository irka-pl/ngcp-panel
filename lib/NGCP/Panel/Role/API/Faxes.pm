package NGCP::Panel::Role::API::Faxes;
use NGCP::Panel::Utils::Generic qw(:all);

use Sipwise::Base;

use parent 'NGCP::Panel::Role::API';


use boolean qw(true);
use Data::HAL qw();
use Data::HAL::Link qw();
use HTTP::Status qw(:constants);
use DateTime::Format::Strptime;
use NGCP::Panel::Utils::Subscriber;
use NGCP::Panel::Utils::Fax;

sub resource_name{
    return 'faxes';
}

sub _item_rs {
    my ($self, $c) = @_;

    my $item_rs = $c->model('DB')->resultset('voip_fax_journal')->search({
        'voip_subscriber.id' => { '!=' => undef },
    },{
        join => { 'provisioning_voip_subscriber' => 'voip_subscriber' }
    });
    if($c->user->roles eq "admin") {
    } elsif($c->user->roles eq "reseller") {
        $item_rs = $item_rs->search({
            'contact.reseller_id' => $c->user->reseller_id
        },{
            join => { provisioning_voip_subscriber => { voip_subscriber => { contract => 'contact' } } }
        });
    } elsif ($c->user->roles eq "subscriberadmin") {
        $item_rs = $item_rs->search_rs({
            'contract.id' => $c->user->account_id,
        },{
            join => { provisioning_voip_subscriber => { voip_subscriber => { contract => 'contact' } } }
        });
    } elsif ($c->user->roles eq "subscriber") {
        $item_rs = $item_rs->search_rs({
            'voip_subscriber.uuid' => $c->user->uuid,
        });
    }
    return $item_rs;
}

sub get_form {
    my ($self, $c) = @_;
    return NGCP::Panel::Form::get("NGCP::Panel::Form::Subscriber::WebfaxAPI", $c);
}

sub hal_from_item {
    my ($self, $c, $item, $form) = @_;

    my $hal = Data::HAL->new(
        links => [
            Data::HAL::Link->new(
                relation => 'curies',
                href => 'http://purl.org/sipwise/ngcp-api/#rel-{rel}',
                name => 'ngcp',
                templated => true,
            ),
            Data::HAL::Link->new(relation => 'collection', href => sprintf("/api/%s/", $self->resource_name)),
            Data::HAL::Link->new(relation => 'profile', href => 'http://purl.org/sipwise/ngcp-api/'),
            Data::HAL::Link->new(relation => 'self', href => sprintf("%s%d", $self->dispatch_path, $item->id)),
            Data::HAL::Link->new(relation => 'ngcp:subscribers', href => sprintf("/api/subscribers/%d", $item->provisioning_voip_subscriber->voip_subscriber->id)),
            Data::HAL::Link->new(relation => 'ngcp:faxrecordings', href => sprintf("/api/faxrecordings/%d", $item->id)),
        ],
        relation => 'ngcp:'.$self->resource_name,
    );

    my $resource = $self->resource_from_item($c, $item, $form);
    $hal->resource($resource);
    return $hal;
}

sub resource_from_item {
    my ($self, $c, $item, $form) = @_;

    $form //= $self->get_form($c);

    my $datetime_fmt = DateTime::Format::Strptime->new(
        pattern => '%F %T',
    );

    my $subscriber = $item->provisioning_voip_subscriber->voip_subscriber;

    my %resource = ();
    $resource{id} = int($item->id);
    $resource{time} = $datetime_fmt->format_datetime($item->time);
    $resource{subscriber_id} = int($subscriber->id);
    foreach(qw/direction caller callee reason status quality filename/){
        $resource{$_} = $item->$_;
    }
    foreach(qw/duration pages signal_rate/){
        $resource{$_} = is_int($item->$_) ? $item->$_ : 0;
    }
    my $data = NGCP::Panel::Utils::Fax::process_fax_journal_item($c, $item, $subscriber);
    map { $resource{$_} = $data->{$_} } qw(caller callee);
    return \%resource;
}

sub item_by_id {
    my ($self, $c, $id) = @_;
    my $item_rs = $self->item_rs($c);
    return $item_rs->find($id);
}

1;
# vim: set tabstop=4 expandtab:
