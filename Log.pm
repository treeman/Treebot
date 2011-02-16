#!/usr/bin/perl -w

use Modern::Perl;
use FileHandle;

require "Config.pl";

package Log;

sub log_file_name
{
    my @time = localtime();
    my ($year, $month, $day) = @time[5, 4, 3];
    $year += 1900;

    my $log_dir = $Config::log_dir;
    return "log_$log_dir$year-$month-$day.log";
}

sub error
{
    #local $, = "";
    #say "! ", @_;
    my $msg = "! " . join("", @_);
    say $msg;

    #say "!!! ", log_file_name();
    open my $f, '>>', log_file_name();
    #open my $f, '>>', "logs/log";
    say $f $msg;
}
sub recieved
{
    local $, = "";
    say "< ", @_;
}
sub sent
{
    local $, = "";
    say "> ", @_;
}

1;

