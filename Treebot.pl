#!/usr/bin/perl -w

use Modern::Perl;

use threads;
use Thread::Queue;

use MooseX::Declare;
use Test::More;
use Getopt::Long;

use Log;
use Irc;
use Plugin;

my $dry;            # Don't connect at all
my $test;           # Run in test mode. Implies dry but connects directly
my $run_tests;      # Run tests
my $verbose;        # Verbose output, both log and stdout
my $log_verbose;    # Verbose logging, stdout as usual
my $bare;           # Only log bare essentials
my $show_bare;      # Only say the bare essentials

my @args = @ARGV;

Getopt::Long::Configure ("bundling");
GetOptions('test|t' => \$test,
           'run_tests' => \$run_tests,
           'dry|d' => \$dry,
           'verbose|v' => \$verbose,
           'log_verbose' => \$log_verbose,
           'bare|b' => \$bare,
           'show_bare|B' => \$show_bare);

# register SIGINT failure for cleanup
$SIG{INT} = \&quit;

Log::init ($verbose, $log_verbose, $bare, $show_bare);
Log::exe ("Starting");

if ($run_tests) {
    Irc::run_tests();
}
else {
    Irc::init ($dry, $test);
    Irc::start;
}

quit();

sub quit
{
    Irc::quit(@_);

    for my $thr (threads->list()) {
        $thr->detach();
    }

    Plugin::unload_all();

    if ($run_tests) {
        done_testing();
    }

    Log::exe ("Quitting");
    exit;
}

$SIG{CHLD} = "IGNORE";

sub restart
{
    Irc::quit ("Restarting...");

    for my $thr (threads->list()) {
        $thr->detach();
    }

    Plugin::unload_all();

    if ($run_tests) {
        done_testing();
    }

    Log::exe ("Restarting");

    # We need to wait a bit so we don't throttle the poor server
    sleep 2;

    exec ('Treebot.pl', @args);
}

