#!/usr/bin/perl

use utf8;
use locale;

use Modern::Perl;
use Test::More;

use MooseX::Declare;
use Plugin;
use insults::MonkeyIsland;

class Insults extends DefaultPlugin
{
    override cmds {
        return qw(mi_insult);
    }

    override process_cmd ($sender, $target, $cmd, $args) {
        if ($cmd eq "mi_insult") {
            my $insult = MI::get_random_insult();

            Irc::irc_privmsg ($target, $insult);
        }
    }

    override process_privmsg ($sender, $target, $msg) {
        if (my $retort = MI::retort_to ($msg)) {
            Irc::irc_privmsg ($target, $retort);
        }
        elsif (my $msg = MI::retort_recieved ($msg)) {
            Irc::irc_privmsg ($target, $msg);
        }
    }

    override cmd_help ($cmd) {
        if ($cmd eq "mi_insult") {
            return "Launch a terrifying insult!";
        }
    }
}

1;

