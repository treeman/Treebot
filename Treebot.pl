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

my $test;
my $dry;
my $run_tests;
my $verbose;
my $log_verbose;

GetOptions('test|t' => \$test,
           'runtests' => \$run_tests,
           'dry|d' => \$dry,
           'verbose|v' => \$verbose,
           'log_verbose|lg' => \$log_verbose);

# register SIGINT failure for cleanup
$SIG{INT} = \&quit;

sub quit
{
    Irc::quit(@_);

    for my $thr (threads->list()) {
        $thr->detach();
    }

    Plugin::unload_all();
    exit;
}

Log::init($verbose, $log_verbose);

Irc::start();

