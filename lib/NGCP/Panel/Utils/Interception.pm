package NGCP::Panel::Utils::Interception;

use Data::Dumper;
use LWP::UserAgent;
use TryCatch;
use JSON;

sub request {
    my ($c, $method, $uuid, $data) = @_;

    my $a = _init($c);
    return unless($a);

    return unless($method eq 'POST' || $method eq 'PUT' || $method eq 'DELETE');

    my @agents = @{ $a->{ua} };
    my @urls = @{ $a->{url} };
    for(my $i = 0; $i < scalar(@agents); ++$i) {
        my $ua = $agents[$i];
        my $url = $urls[$i];
        if($method eq 'PUT' or $method eq 'DELETE') {
            return unless($uuid);
            $url .= '/'.$uuid;
        }
        $c->log->debug("performing $method for interception at $url");
        try {
            _request($c, $ua, $url, $method, $data);
        } catch($e) {
            # skip errors
        }
    }
    return 1;
}

sub _request {
    my ($c, $ua, $url, $method, $data) = @_;

    my $req = HTTP::Request->new($method => $url);
    if($data) {
        $req->content_type('application/json');
        $req->content(encode_json($data));
    }
    my $res = $ua->request($req);
    if($res->is_success) {
        return 1;
    } else {
        $c->log->error("Failed to do $method on $url: " . $res->status_line);
        return;
    }
}

sub _init {
    my ($c) = @_;

    my @ua = ();
    my @url = ();
    my @cfgs = ();
    if(ref $c->config->{intercept}->{agent} eq 'HASH') {
        push @cfgs, $c->config->{intercept}->{agent};
    } elsif(ref $c->config->{intercept}->{agent} eq 'ARRAY') {
        @cfgs = @{ $c->config->{intercept}->{agent} };
    }
    unless(@cfgs) {
        $c->log->error("No intercept agents configured in ngcp_panel.conf, rejecting request");
        return;
    }
    foreach my $cfg(@cfgs) {
        my $agent = LWP::UserAgent->new();
        $agent->agent("Sipwise NGCP X1/0.2");
        $agent->timeout(2);
        if($cfg->{user} && $cfg->{pass}) {
            $agent->credentials(
                $cfg->{host}.":".$cfg->{port},
                $cfg->{realm},
                $cfg->{user},
                $cfg->{pass}
            );
        }
        push @ua, $agent;
        push @url, $cfg->{schema}.'://'.$cfg->{host}.':'.$cfg->{port}.$cfg->{url};
    }
    return { ua => \@ua, url => \@url };
}

1;
