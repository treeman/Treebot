#!/usr/bin/perl -w

use utf8;
use locale;

use Modern::Perl;

package Log;

sub recieved
{
    my ($what) = @_;
    chomp $what;

    my $msg = "< $what";

    if (!is_blacklisted ($msg)) {
        say $msg;
    }
}

sub sent
{
    my ($what) = @_;
    chomp $what;

    my $msg = "> $what";

    if (!is_blacklisted ($msg)) {
        say $msg;
    }
}

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

