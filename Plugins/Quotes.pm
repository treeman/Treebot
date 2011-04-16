#!/usr/bin/perl

use utf8;
use locale;

use Modern::Perl;
use Test::More;

use MooseX::Declare;
use Plugin;
use DukeNukem;

class Quotes extends DefaultPlugin
{
    override cmds
    {
        return qw(duke
                  duke3D
                  dnf);
    }

    override process_cmd ($sender, $target, $cmd, $args)
    {
        if ($cmd eq "duke") {
            my $quote = Duke::random_quote();

            Irc::send_privmsg ($target, $quote);
        }
        elsif ($cmd =~ /duke3[dD]/) {
            my $quote = Duke::duke3D_quote();

            Irc::send_privmsg ($target, $quote);
        }
        elsif ($cmd eq "dnf") {
            my $quote = Duke::dnf_quote();

            Irc::send_privmsg ($target, $quote);
        }
    }

    override cmd_help ($cmd)
    {
        if ($cmd eq "duke") {
            return "My job is to kick ass, not make small talk.";
        }
        elsif ($cmd =~ /duke3[dD]/) {
            return "Come get some!";
        }
        elsif ($cmd eq "dnf") {
            return "Girl: What about the game Duke? Was it any good?\nDuke: Yeah, but after 12 fucking years it should be!";
        }
    }

}

1;

