#!/usr/bin/perl -w

use Modern::Perl;
use FileHandle;

use Bot_Config;

package Log;

sub log_file_name
{
    my @time = localtime();
    my ($year, $month, $day) = @time[5, 4, 3];
    $year += 1900;

    my $log_dir = $Bot_Config::log_dir;
    return "${log_dir}$year-$month-$day.log";
}

sub get_log_file
{
    my $log_file = log_file_name();
    open my $fh, '>>', $log_file
        or die "Couldn't open log file: '$log_file'\n$!\n";
    return $fh;
}

sub cmd
{
    my $msg = "." . join("", @_);

    my $fh = get_log_file();
    say $fh $msg;
}

sub out
{
    my $msg = ": " . join("", @_);
    say $msg;

    my $fh = get_log_file();
    say $fh $msg;
}

sub error
{
    my $msg = "! " . join("", @_);
    say $msg;

    my $fh = get_log_file();
    say $fh $msg;
}
sub recieved
{
    # We might think of a prettier solution sometime
    return if (!$Bot_Config::log_ping && $_[0] =~ /^PING/);

    my $msg = "< " . join("", @_);
    say $msg;

    my $fh = get_log_file();
    say $fh $msg;
}
sub sent
{
    # We might think of a prettier solution sometime
    return if (!$Bot_Config::log_pong && $_[0] =~ /^PONG/);

    my $msg = "> " . join("", @_);
    say $msg;

    my $fh = get_log_file();
    say $fh $msg;
}

1;

