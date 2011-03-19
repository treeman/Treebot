#!/usr/bin/perl -w

package Util;

use Modern::Perl;
use utf8;
use locale;

sub remove_matches
{
    my ($origin, $remove) = @_;

    for (@{$remove}) {
        delete $origin->{$_};
    }

    return %{$origin};
}

sub get_month_num {
    my ($m) = @_;
    my %months = (
        Jan => "01",
        Feb => "02",
        Mar => "03",
        Apr => "04",
        May => "05",
        Jun => "06",
        Jul => "07",
        Aug => "08",
        Sep => "09",
        Okt => "10",
        Nov => "11",
        Dec => "12",
    );

    return $months{$m};
}

sub format_time
{
    my ($time) = @_;

    my @parts = localtime($time);
    my ($d, $h, $m, $s) = @parts[7, 2, 1, 0];

    my $msg;
    if ($d) {
        $msg .= "${d}d ";
    }
    if ($h) {
        $msg .= "${h}h ";
    }
    if ($m) {
        $msg .= "${m}m ";
    }
    $msg .= "${s}s ";

    return $msg;
}

# Add in spaces if the string isn't at least this long
sub pre_space_str
{
    my ($str, $min) = @_;

    # For some reason it doesn't count these chars as it should. Simple workaround.
    my $botch = $str;
    $botch =~ s/(ä|ö|å)/x/g;
    #$botch =~ s/[^[:ascii:]]/x/g;
    my $spaces = $min - length ($botch);

    return " " x $spaces . $str;
}

sub post_space_str
{
    my ($str, $min) = @_;

    # For some reason it doesn't count these chars as it should. Simple workaround.
    my $botch = $str;
    #$botch =~ s/(ä|ö|å)/x/g;
    $botch =~ s/[^[:ascii:]]/x/g;
    my $spaces = $min - length ($botch);
    return $str . " " x $spaces;
}

# Swedish lower case
sub lc_se
{
    my ($txt) = @_;
    $txt = lc($txt);

    my %map = ('Å' => 'å', 'Ä' => 'ä', 'Ö' => 'ö');
    $txt =~ s/(Å|Ä|Ö)/$map{$1}/g;
    #$txt =~ s/[^[:ascii:]]//g;
    return $txt;
}

1;

