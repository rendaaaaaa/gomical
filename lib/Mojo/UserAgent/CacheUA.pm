package Mojo::UserAgent::CacheUA;
use Mojo::Base qw/Mojo::UserAgent/;
use Cache::FileCache;
use Time::Piece;
use Carp;

my $ua;

has agent => "";
has delay => 5;
has cache_conf => sub {return {}};

my $last_req = 0;
sub new {
    my ($self, @args) = @_;
    $ua = $self->SUPER::new(@args);
    $ua->on(start => sub {
            my ($c, $tx) = @_;
            $tx->req->headers->user_agent($c->agent) if $c->agent;
            while($last_req + $c->delay > localtime) {
                sleep(1);
            }
            say 'agent: ' . $c->agent;
            $last_req = localtime;
        });
    return $ua;
}

sub cache {
    my ($self, $url) = @_;
    my $cache = Cache::FileCache->new($self->cache_conf);
    my $data;
    unless ($data = $cache->get($url)) {
        $data = $self->get($url)->res->content->asset->slurp();
        $cache->set($url, $data);
    }
    return $data;
}

1;
