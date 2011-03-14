#!/usr/bin/perl -w

use Modern::Perl;
use Test::More;
use LWP::Simple;

use Util;

package Show;

sub next_show
{
    my ($show) = @_;

    my $txt = LWP::Simple::get
        "http://services.tvrage.com/tools/quickinfo.php?show=$show";

    my %info;

    if ($txt =~ /no show results were found/i) {
        say "$show was not found.";
    }
    else {

        if ($txt =~ /Show Name\@(.+)/) {
            $info{'name'} = $1;
        }
        if ($txt =~ /Latest Episode\@(.+)/) {
            $info{'latest'} = $1;
        }
        if ($txt =~ /Next Episode\@(.+)/) {
            $info{'next'} = $1;
        }
    }

    return %info;
}

sub format_show
{
    my ($show, %info) = @_;

    if (!%info) {
        return "Show $show not found";
    }

    my $latest = format_ep ($info{'latest'});
    my $next = format_ep ($info{'next'});

    return "$info{'name'} | Latest: $latest | Next: $next";
}

sub format_ep
{
    my ($str) = @_;

    my $ep_info = qr/
        (\d+)x(\d+)         # (1) (2) season and episode
        \^
        ([^\^]+)            # (3) ep title
        \^
        ([^\/]+)            # (4) month
        \/
        ([^\/]+)            # (5) day
        \/
        ([^\/]+)            # (6) year
    /xs;

    if ($str) {
        $str =~ /$ep_info/;

        my $m = Util::get_month_num ($4);
        return "$1x$2, $3, $5-$m-$6";
    }
    else {
        return "No info";
    }
}

sub show_info
{
    my ($show) = @_;
    my %info = next_show ($show);
    return format_show ($show, %info);
}

1;

