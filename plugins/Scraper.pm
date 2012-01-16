#!/usr/bin/perl

use utf8;
use locale;

use Modern::Perl;
use Test::More;

use MooseX::Declare;
use Time::Seconds;

use Plugin;
use Conf;

class Scraper extends DefaultPlugin
{
    override cmds () {
        return qw(nextep);
    }

    override process_cmd ($sender, $target, $cmd, $arg) {

        if ($cmd eq "nextep") {
            if ($arg =~ /^\s*$/) {
                Irc::irc_privmsg ($target, "Input a serie to search for plz.");
            }
            else {
                my $msg = `nextep --short $arg`;
                Irc::irc_privmsg ($target, $msg);
            }
        }
    }

    override cmd_help ($cmd) {
        if ($cmd eq "nextep") {
            return "Get episode info about your fav tv series.";
        }
    }
}

1;

