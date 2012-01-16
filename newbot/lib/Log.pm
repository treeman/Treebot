#!/usr/bin/perl -w

use utf8;
use locale;

use Modern::Perl;

package Log;

use Carp;

my $verbose;            # Verbose output, both log and stdout
my $bare;               # Only log bare essentials
my $debug;              # Log debug messages;
my $no_out;             # Nothing to stdout

sub init
{
    ($verbose, $bare, $debug, $no_out) = @_;

    # Register error signal to our custom
    $SIG{'__WARN__'} = \&error;
}

# Log works by prefixing stuff with a corresponding letter
sub debug { show ("+", @_) if $debug; }     # Debug
sub error { show ("!", @_); carp (@_); }    # Error... xD
sub exe { show ("*", @_); }                 # Execution of program, quit etc
sub out { show (":", @_); }                 # Output to command line
sub plugin { show ("~", @_); }              # Plugin loading
sub recieved { show ("<", @_); }            # In from server
sub sent { show (">", @_); }                # Out to server

# Log a bare message
sub show
{
    my ($msg) = join (" ", @_);
    chomp $msg;

    if (!is_blacklisted ($msg)) {
        say $msg;
    }
}

# Check if log message is blacklisted
sub is_blacklisted
{
    my ($msg) = @_;

    for (@Conf::log_blacklist) {
        if ($msg =~ /$_/) {
            return 1;
        }
    }
    return 0;
}

# Check if log message is whitelisted
sub is_whitelisted
{
    my ($msg) = @_;

    for (@Conf::log_whitelist) {
        if ($msg =~ /$_/) {
            return 1;
        }
    }
    return 0;
}

1;

