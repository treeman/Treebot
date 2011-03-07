#!/usr/bin/perl -w

use Modern::Perl;
use FileHandle;

package Log;

use Carp;

use Conf;

my $fh;
my $file_name;

my $log_verbose;
my $verbose;

sub init
{
    ($verbose, $log_verbose) = @_;
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
sub it { store ("? ", @_); }

sub store
{
    my ($msg) = join("", @_);
    chomp $msg;

    my $blacklisted = blacklisted ($msg);

    if ($verbose or !$blacklisted) {
        say $msg;
    }
    if ($verbose or $log_verbose or !$blacklisted) {

        if ($file_name ne file_name()) {
            open_log_file();
        }
        say $fh $msg;
    }
}

sub file_name
{
    my @time = localtime();
    my ($year, $month, $day) = @time[5, 4, 3];
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
    return 0;
}

1;

