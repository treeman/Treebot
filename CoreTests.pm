#!/usr/bin/perl -w

package CoreTests;

use Modern::Perl;
use Test::More;
use Carp;

use threads;
use threads::shared;
use Thread::Queue;

use Plugin;

# Will get threaded
sub run_tests
{
    Irc::push_in (":wineasy1.se.quakenet.org 001 treebot :Welcome dawg");
    Irc::push_in (":wineasy1.se.quakenet.org 002 treebot :I shall be your host today");
    Irc::push_in (":wineasy1.se.quakenet.org 003 treebot :I was carved out of wood");
    Irc::push_in (":wineasy1.se.quakenet.org 004 treebot :And oh how I wanted to log you in!");

    # Give some time to respond
    sleep 1;

    ok(Irc::has_connected(), "Test connection");
}

# Need to figure out a nice way to check events after we sent something
sub out
{
    my ($msg) = @_;

    if ($msg) {
        Log::sent $msg;
    }
}

1;

