#!/usr/bin/perl -w

use locale;
use Modern::Perl;

use Test::More tests => 6;

use lib "../";
use SimpleDate;

is (SimpleDate::time_passed (0), "0s", "Nothing.");
is (SimpleDate::time_passed (10), "10s", "Seconds.");
is (SimpleDate::time_passed (60), "1m", "One min.");
is (SimpleDate::time_passed (100), "1m 40s", "Min + seconds.");
is (SimpleDate::time_passed (3600), "1h", "Hour.");
is (SimpleDate::time_passed (24 * 3600), "1d", "Day.");

