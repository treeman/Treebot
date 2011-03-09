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

1;

