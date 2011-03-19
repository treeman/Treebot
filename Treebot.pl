#!/usr/bin/perl -w

use Modern::Perl;

use threads;
use Thread::Queue;

use MooseX::Declare;
use Test::More;
use Getopt::Long;
use POSIX 'setsid';
use Carp;

use Log;
use Irc;
use Plugin;
use Tests;

my $daemonize;      # Start as daemon

my $dry;            # Don't connect at all
my $test;           # Run in test mode. Implies dry but connects directly
my $run_tests;      # Run tests

my $verbose;        # Verbose output, both log and stdout
my $log_verbose;    # Verbose logging, stdout as usual
my $bare;           # Only log bare essentials
my $show_bare;      # Only say the bare essentials
my $debug;          # Log debug messages;
my $no_show;        # Nothing to stdout

my @args = @ARGV;

Getopt::Long::Configure ("bundling");
GetOptions(
    'bare|b' => \$bare,
    'daemon|d' => \$daemonize,
    'debug' => \$debug,
    'dry' => \$dry,
    'log_verbose' => \$log_verbose,
    'no_show' => \$no_show,
    'run_tests' => \$run_tests,
    'show_bare|B' => \$show_bare,
    'test|t' => \$test,
    'verbose|v' => \$verbose,
);

# Only show test messages, no garbage ty
if ($run_tests) {
    $no_show = 1;
}

# register SIGINT failure for cleanup
$SIG{INT} = \&quit;

if ($daemonize) {
    daemonize();
}

Log::init ($verbose, $log_verbose, $bare, $show_bare, $debug, $no_show);
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

sub restart
{
    my ($msg) = @_;

    if ($msg) {
        Irc::quit ($msg);
    }
    else {
        Irc::quit ("Restarting...");
    }

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

sub daemonize
{
    open STDIN, '/dev/null' or croak "Can't read /dev/null: $!";
    open STDOUT, '>/dev/null' or croak "Can't write to /dev/null: $!";
    defined(my $pid = fork) or croak "Can't fork: $!";
    exit if $pid;
    croak "Can't start a new session: $!" if setsid == -1;
    open STDERR, '>&STDOUT' or croak "Can't dup stdout: $!";
}

