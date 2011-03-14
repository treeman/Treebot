#!/usr/bin/perl -w

package Util;

use Modern::Perl;

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

1;

