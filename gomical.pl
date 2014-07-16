#!/usr/bin/env perl
use Mojolicious::Lite;

use FindBin;
BEGIN { unshift @INC, "$FindBin::Bin/lib" }

use DBI;
use Teng::Schema::Loader;
use Mojo::Util qw/slurp encode decode dumper squish/;
use Time::Piece;
use Time::Seconds;

my $commands = app->commands;
push @{$commands->namespaces}, 'GomiCal::CLI';

my $dbh = DBI->connect(
        'dbi:SQLite:dbname=gomi.db',
        '', '',
        {sqlite_unicode => 1},
    );
my $teng = Teng::Schema::Loader->load('dbh' => $dbh, 'namespace' => 'GomiCal::DB');

get '/' => sub {
    my $self = shift;
    $self->render('index');
};

get '/tutor' => sub {
    my $self = shift;
    $self->render('tutor');
};

get '/api/v0/addr' => sub {
    my $self = shift;
    my @res = ();
    for ($teng->search('region')) {
        push @res, {name => "$_->{row_data}->{ku} $_->{row_data}->{jusho}", value => "$_->{row_data}->{cal_id}"};
    }
    #say dumper \@res;
    $self->render(json => \@res);
};

get '/api/v0/cal/:addr' => sub {
    my $self = shift;
    say $self->param('addr');
    say $self->param('start');
    my $now = localtime;
    my $strfmt = '%Y%m%d';
    my $cond = Time::Piece->strptime($self->param('start'), $strfmt);
    my $next = $cond + (ONE_DAY * 7);
    my $prev = $cond + (ONE_DAY * -7);
    my %type_jp = (
        -1 => "収集なし",
        0 => "びん・缶・ペットボトル",
        1 => "容器包装プラスチック ",
        2 => "燃やせるごみ",
        3 => "枝・葉・草",
        4 => "燃やせないごみ",
        5 => "雑がみ",
    );
    #カレンダーのデータを作る
    my @cal = ();
    my @wday_jp = qw/日 月 火 水 木 金 土/;
    for ($teng->search('cal', {cal_id => $self->param('addr'), date => {'>=' => $cond->ymd}}, {order_by => 'date', limit => 7})) {
        say dumper $_;
        #for ($teng->search('cal', +{cal_id => $self->param('addr'), date => {'>' => $cond->ymd}}, +{order_by => 'date', limit => 7})) {
        next unless my $date = $_->{row_data}->{date};
        my $wday = $wday_jp[Time::Piece->strptime($date, '%Y-%m-%d')->_wday()];
        my $type = $_->{row_data}->{type};
        $type = -1 unless defined($type);
        push @cal, {date => "$date ($wday)", type => $type_jp{$type}};
    }
    #次ページ、前ページのデータを作る
    my $pager = {
        prev  => $prev->strftime($strfmt), 
        today => $now->strftime($strfmt), 
        next  => $next->strftime($strfmt)
    };
    my $res = {cal => \@cal, pager => $pager};
    say dumper $res;
    $self->render(json => $res);
};

app->start;

