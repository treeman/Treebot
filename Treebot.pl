#!/usr/bin/perl -w

use Modern::Perl;
use MooseX::Declare;
use Test::More;

use threads;
use Thread::Queue;
use Getopt::Long;

use Log;
use Bot_Config;
use Irc;
use PluginHandling;

my $test_mode = 0;
GetOptions('test|t' => \$test_mode);

# register SIGINT failure for cleanup
$SIG{INT} = \&quit;

sub quit
{
    for my $thr (threads->list()) {
        $thr->detach();
    }

    Irc::unload_plugins();
    Irc::quit(@_);

    exit;
}

Irc::start($test_mode);

