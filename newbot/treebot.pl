#!/usr/bin/perl -w

use utf8;
use locale;

use threads;
use threads::shared;

use Modern::Perl;
use IO::Socket;
use Carp;
use Test::More;
use Getopt::Long;

use Conf;
use Log;
use Irc;
use Plugin;

# Command line options
my $help;               # Print help
my $daemonize;          # Start as daemon.

my $dry;                # Don't connect at all.
my $test;               # Run in test mode. Implies dry but test connect.
my $run_tests;          # Run tests.

my $verbose;            # Verbose output, both log and stdout
my $bare;               # Only log bare essentials
my $debug;              # Log debug messages;
my $no_out;             # Nothing to stdout

# Save options
my @args = @ARGV;

Getopt::Long::Configure ("bundling");
GetOptions(
    'bare|b' => \$bare,
    'daemon|d' => \$daemonize,
    'debug' => \$debug,
    'dry' => \$dry,
    'help|h' => \$help,
    'no_out' => \$no_out,
    'run_tests' => \$run_tests,
    'test|t' => \$test,
    'verbose|v' => \$verbose,
);

if ($help) {
    say "A simple perl irc bot.";
    exit;
}

# Only show test messages, no garbage ty
if ($run_tests) {
    $no_out = 1;
}

if ($daemonize) {
    daemonize();
}

Log::init ($verbose, $bare, $debug, $no_out);

Log::debug ("Loading plugins.");

# Load all plugins
Plugin::load_plugins();

# Thread for piping commands and stuff to our irc handler
my $stdin_listener = threads->create(\&stdin_listener);

# Run tests
if ($run_tests) {
    Irc::run_tests();
}
# Launch irc
else {
    Irc::start($dry, $test);
}

# Clean threads etc
cleanup();

# Should be run in a separate thread
sub stdin_listener
{
    while (<STDIN>) {
        my $in = $_;
        chomp $in;

        # We've recieved a command. It will be parsed in the in queue, will be run on the main thread.
        if ($in =~ /^\Q$Conf::cmd_prefix\E/) {
            Irc::push_in($in);
        }
        # Act like we've recieved the message from the socket.
        elsif ($in =~ /^<\s*(.*)/) {
            Irc::push_in ("$1\r\n");
        }
        # If nothing special pipe it to the server.
        else {
            Irc::output ($in);
        }
    }
}

# Do some cleanup
sub cleanup
{
    Log::exe ("Cleaning threads.");

    for my $t (threads->list()) {
        $t->detach();
    }
}

