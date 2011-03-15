#!/usr/bin/perl -w

use Modern::Perl;
use FileHandle;

package Log;

use Carp;

use Conf;

my $fh;
my $file_name;

# Logging options
my $log_verbose;
my $verbose;
my $bare;
my $show_bare;
my $debug;

sub init
{
    ($verbose, $log_verbose, $bare, $show_bare, $debug) = @_;
    open_log_file();

    # Log warnings
    $SIG{'__WARN__'} = \&error;
}

sub cmd { store (". ", @_); }
sub out { store (": ", @_); }
sub error { store ("! ", @_); }
sub recieved { store ("< ", @_); }
sub sent { store ("> ", @_); }
sub plugin { store ("~ ", @_); }
sub file { store ("\$ ", @_); }
sub exe { store ("* ", @_); }
sub it { store ("? ", @_); }
sub debug { store ("£ ", @_) if $debug; }

sub store
{
    my ($msg) = join("", @_);
    chomp $msg;

    my $blacklisted = blacklisted ($msg);
    my $whitelisted = whitelisted ($msg);

    # Shall I say?
    if ($bare or $show_bare) {
        if ($whitelisted) {
            say $msg;
        }
    }
    elsif ($verbose) {
        say $msg;
    }
    elsif (!$blacklisted) {
        say $msg;
    }

    # Or shall I log now?
    if ($bare) {
        if ($whitelisted) {
            output ($msg);
        }
    }
    elsif ($verbose or $log_verbose) {
        output ($msg);
    }
    elsif (!$blacklisted) {
        output ($msg);
    }
}

sub output
{
    my ($msg) = join("", @_);
    if ($file_name ne file_name()) {
        open_log_file();
    }
    say $fh $msg;
}

sub file_name
{
    my @time = localtime();
    my ($year, $month, $day) = @time[5, 4, 3];
    $month++; # Months start with 0.

    $year += 1900;

    my $log_dir = $Conf::log_dir;
    return "${log_dir}$year-$month-$day.log";
}

sub open_log_file
{
    $file_name = file_name();
    open $fh, '>>', $file_name
        or croak "Couldn't open log file: '$file_name'\n$!\n";
}

sub blacklisted
{
    my ($msg) = @_;

    for (@Conf::log_blacklist) {
        if ($msg =~ /$_/) {
            return 1;
        }
    }
    return 0;
}

sub whitelisted
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

