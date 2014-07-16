package GomiCal::CLI::cache;

use feature 'say';
use Mojo::Base qw/Mojolicious::Command/;
use Mojo::Util qw/encode dumper/;
use Encode::Locale;
use Mojo::UserAgent::CacheUA;

has description => encode 'console_out', "キャッシュのテスト\n";
has usage => <<EOF;
usage: $0
EOF

has conf => sub {
    my ($self) = @_;
    my $conf = do $self->rel_file('cache.conf');
    return $conf;
};

sub run {
    my ($self) = @_;
    my $url = "mojolicio.us/perldoc";
    my $ua = Mojo::UserAgent::CacheUA->new();
    $ua->agent("KinokoBot/0.1");
    $ua->cache_conf($self->conf->{cache});
    my $data;

    $data = $ua->cache($url);
    say ref(\$data);
    $data = $ua->cache($url);
    say ref(\$data);
};


1;
