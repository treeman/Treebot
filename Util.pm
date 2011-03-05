#!/usr/bin/perl -w

package Util;

use Modern::Perl;

sub remove_matches
{
    my ($origin, $remove) = @_;

    my %seen;
    for (@{$origin}) {
        $seen{$_} = 1;
    }

    for (@{$remove}) {
        delete $seen{$_};
    }

    return keys %seen;
}

1;

