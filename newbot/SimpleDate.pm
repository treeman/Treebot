#!/usr/bin/perl -w

use locale;

package SimpleDate;

use Modern::Perl;
use POSIX qw(strftime);

# Simple date time formating

# Create a pretty format of time passed
# Example output: 2d 13h 10m 4s
sub time_passed
{
    my ($time) = @_;

    if (!$time) {
        return "0s";
    }

    my @parts = gmtime($time);
    my ($d, $h, $m, $s) = @parts[7, 2, 1, 0];

    my $msg;
    if ($d) {
        $msg .= "${d}d ";
    }
    if ($h) {
        $msg .= "${h}h ";
    }
    if ($m) {
        $msg .= "${m}m ";
    }
    if ($s) {
        $msg .= "${s}s";
    }

    # Trim trailing possible space
    $msg =~ s/\s$//;

    return $msg;
}

1;

