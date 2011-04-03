#!/usr/bin/perl -w

use utf8;
use locale;

use Modern::Perl;
use Test::More;
use MooseX::Declare;
use LWP::Simple;

use Plugin;
use Log;
use Find;
use Info;
use Util;

class Probe extends DefaultPlugin
{
    override cmds
    {
        return qw(down?
                  whois?
                  train);
    }

    override process_cmd ($sender, $target, $cmd, $arg)
    {
        if ($cmd eq "down?") {
            my $msg = Info::down ($arg);
            if ($msg) {
                Irc::send_privmsg ($target, $msg);
            }
            else {
                Irc::send_privmsg ($target, "Error occured.");
            }
        }
        elsif ($cmd eq "whois?") {
            my $msg = Find::number ($arg);
            Irc::send_privmsg ($target, $msg);
        }
        elsif ($cmd eq "train") {
            my @args = split (/ /, $arg);

            my $date;
            my $train;
            my $station;

            $date = Util::parse_as_date ($args[0]);

            if (!defined ($date)) {
                if (scalar @args == 1) {
                    $train = shift @args;
                }
                elsif (scalar @args == 2) {
                    $train = shift @args;
                    $station = join ("", @args);
                }
                else {
                    $train = $args[0];
                    $station = join ("", @args[1 .. $#args]);
                }
            }
            else {
                $train = $args[1];
                $station = join ("", @args[2 .. $#args]);
            }

            if ($train !~ /^\d+$/) {
                Irc::send_privmsg ($target, "A train is only specified by a number.");
                return;
            }

            my @result;
            @result = Info::train ($date, $train);

            # Utf mixed in with ascii will cause trouble
            # Not sure why, but this fixes it. Replaces 2 non-ascii utf chars with '.'
            # So we can match swedish characters and others.
            if ($station) { $station =~ s/[^[:ascii:]]{2}/./g; }

            if (!@result) {
                Irc::send_privmsg ($target, "We couldn't find the train.");
            }
            else {
                my @filtered;
                for my $m (@result) {
                    if (!$station or $m =~ /$station/i) {
                        push (@filtered, $m);
                    }
                }

                if (!@filtered) {
                    Irc::send_privmsg ($target, "We couldn't find the station.");
                    for (@result) {
                        Irc::send_privmsg ($target, $_);
                    }
                }
                else {
                    for (@filtered) {
                        Irc::send_privmsg ($target, $_);
                    }
                }
            }
        }
    }

    override cmd_help ($cmd)
    {
        if ($cmd eq "down?") {
            return "Check if a site is down for everyone or just you.";
        }
        elsif ($cmd eq "whois?") {
            return "Got an unknown number? I'm here to help.";
        }
        elsif ($cmd eq "train") {
            return "Check an SJ train: [date] train-id station. Example: train 8647 linköping. Will return 'arrival, departure'.";
        }
    }

    override run_tests ()
    {
        Find::number_tests();
        Util::date_test();
    }
}

1;

