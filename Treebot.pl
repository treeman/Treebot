#!/usr/bin/perl -w

use Modern::Perl;
use MooseX::Declare;
use Test::More;

use threads;
use Thread::Queue;
use Getopt::Long;

use Log;
use Irc;
use Plugin;

my $test_mode = 0;
GetOptions('test|t' => \$test_mode);

# register SIGINT failure for cleanup
$SIG{INT} = \&quit;

sub quit
{
    for my $thr (threads->list()) {
        $thr->detach();
    }

    Plugin::unload_all();
    Irc::quit(@_);

    exit;
}

Irc::start($test_mode);

