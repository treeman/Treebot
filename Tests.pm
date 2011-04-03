#!/usr/bin/perl -w

use utf8;
use locale;

package Tests;

use Modern::Perl;

use threads;
use threads::shared;
use Thread::Queue;

use Test::More;
use Carp;

use Plugin;

# Need to figure out a nice way to check events after we sent something
sub out
{
    my ($msg) = @_;

    if ($msg) {
        Log::sent $msg;
    }
}

1;

