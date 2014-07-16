package GomiCal::CLI::refresh_cal;

use feature 'say';
use Mojo::Base qw/Mojolicious::Command/;
use Mojo::Util qw/slurp encode decode dumper squish/;
use Encode::Locale;
use Mojo::UserAgent::CacheUA;
use Mojo::DOM;
use Mojo::URL;
use Time::Piece::Month;
use Time::Seconds;
use DBI;
use Teng::Schema::Loader;

binmode STDERR, ':encoding(console_out)';
binmode STDOUT, ':encoding(console_out)';

has description => encode 'console_out', "札幌市ごみカレンダーを更新する\n";
has usage => <<EOF;
usage: $0
EOF

has conf => sub {
    my ($self) = @_;
    my $data = decode 'utf8', slurp $self->rel_file('refresh_cal.conf');
    my $conf = eval $data;
    return $conf;
};

has ua => sub {
    my ($self) = @_;
    return Mojo::UserAgent::CacheUA->new($self->conf->{ua});
};

has teng => sub {
    my ($self) = @_;
    my $dbh = DBI->connect(@{$self->conf->{db}});
    my $teng = Teng::Schema::Loader->load('dbh' => $dbh, 'namespace' => 'GomiCal::DB');
    return $teng;
};

sub run {
    my ($self) = @_;
    my @cal_url = map {$self->cal_url($_)} $self->ku_url();
    $self->teng->delete('cal');
    $self->teng->delete('region');
    for (@cal_url) {
        say "url: $_->{url}";
        say "ku $_->{ku}";
        say "jusho $_->{jusho}";

        my @cal = $self->cal($_->{url});
        my @tmp = split "/", $_->{url};
        my ($cal_id, undef) = split /\./, $tmp[(scalar @tmp)-1];
        my @insert = ();
        for my $i (@cal) {
            my @sp = map {$self->cal_type($_)} $self->cal_split($i);
            #say dumper @sp;
            push @insert, map { $_->{cal_id} = $cal_id; $_ } $self->make_cal(@sp);
        }
        #say dumper \@insert;
        $self->teng->insert('region', {
                ku => $_->{ku},
                jusho => $_->{jusho},
                cal_id => $cal_id,
            });
        $self->teng->bulk_insert('cal', \@insert) or die "$@";
        #last;
    }
};

sub ku_url {
    my ($self) = @_;
    my $url = Mojo::URL->new("http://www.city.sapporo.jp/seiso/kaisyu/yomiage/index.html");
    my $sel = "a:not(a[href*=index])[href*=yomiage][href^=/]";
    my $dom = Mojo::DOM->new($self->ua->cache($url));
    my @ku = ();
    $dom->find($sel)->each(sub {
            push @ku, Mojo::URL->new($_->attr('href'))->to_abs($url);
        });
    return @ku;
}

sub cal_url {
    my ($self, $u) = @_;
    my $url = Mojo::URL->new($u);
    my $sel = "a:not(a[href*=#]):not(a[href*=index])[href*=carender][href*=yomiage][href^=/]";
    my $dom = Mojo::DOM->new(decode "utf8", $self->ua->cache($url));
    my @jusho = ();
    my $ku = $dom->at('h1')->text;
    $dom->find($sel)->each(sub {
            push @jusho, {
                url => Mojo::URL->new($_->attr('href'))->to_abs($url), 
                ku => $ku, 
                jusho => $_->text
            };
        });
    return @jusho;
}

sub cal {
    my ($self, $u) = @_;
    my $url = Mojo::URL->new($u);
    my $dom = Mojo::DOM->new(decode "utf8", $self->ua->cache($url));
    my @result = ();
    $dom->find('a[href^="#h"]')->each(sub {
            my $id = $_->attr('href');
            push @result, squish $dom->at("#$id")->next->next_sibling;
        });
    return @result;
}

sub cal_split {
    my ($self, $s) = @_;
    for (@{$self->conf->{parse}->{normalize}}) {
        $s =~ s/$_->{re}/$_->{rep}/g;
    }
    return split $self->conf->{parse}->{split_ch}, $s;
}

sub cal_type {
    my ($self, $s) = @_;
    my $rule = {};
    my $caldata;
    for (@{$self->conf->{parse}->{rule}}) {
        next if $s !~ /$_->{cond}/ ;
        $rule = $_;
    }
    if ($rule->{method} eq 'date') {
        my ($erayear, $month) = $s =~ m{平成(\d+)年(\d+)月の};
        return {
            type => "date",
            year => $erayear + 1988,
            month => $month,
            name => $rule->{name},
        };
    } elsif ($rule->{method} eq 'weekly') {
        my @wday = $s =~ m{
            (?: #グループ化対象外
            (.)曜
            )+
        }gx;
        return {
            type => 'weekly',
            wday => [@wday],
            name => $rule->{name},
        };
    } elsif ($rule->{method} eq 'monthly') {
        if ($s =~ /ありません/) {
            return {
                type => 'monthly',
                day => [],
                name => $rule->{name},
            };
        }
        my @days = $s =~ m{
            (?: #グループ化対象外
            \d+
            )+
        }gx;
        return {
            type => 'monthly',
            day => [@days],
            name => $rule->{name},
        };
    }
}

sub make_cal {
    my ($self, @c) = @_;
    my ($year, $month);
    for (@c) {
        next if $_->{name} != -1;
        $year = $_->{year};
        $month = $_->{month};
        last;
    }
    my $r = Time::Piece::Month->new("$year-$month-01");
    my @w = qw/日 月 火 水 木 金 土/;
    my @result = ();
    day: for (my $i = $r->start; $i < $r->end; $i += ONE_DAY) {
        my $type = "";
        type: for (@c) {
            if ($_->{type} =~ /monthly/) {
                for my $j (@{$_->{day}}) {
                    next if $i->mday != $j;
                    $type = $_->{name};
                    #say $i->date . " $_->{name}";
                    #say $i->date . " " . $w[$i->_wday -1] . " " . $self->conf->{parse}->{name}[$type];
                    #next day;
                    last type;
                }
            }
            if ($_->{type} =~ /weekly/) {
                for my $j (@{$_->{wday}}) {
                    next if $w[$i->_wday] ne $j;
                    $type = $_->{name};
                    #say $i->date . " " . $w[$i->_wday -1] . " " . $self->conf->{parse}->{name}[$type];
                    #next day;
                    last type;
                }
            }
        }
        if ($type ne "") {
            say $i->date . " " . $w[$i->_wday -1] . " " . $self->conf->{parse}->{name}[$type];
            push @result, {date => $i->date, type => $type,};
        } else {
            say $i->date . " " . $w[$i->_wday -1] . " (収集なし)";
            push @result, {date => $i->date, type => undef,};
        }
    }
    return @result;
}

1;
