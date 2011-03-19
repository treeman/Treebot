#!/usr/bin/perl

use Modern::Perl;
use Test::More;

use MooseX::Declare;
use Plugin;
use MonkeyIsland;

class Insults extends DefaultPlugin
{
    override process_cmd ($sender, $target, $cmd, $args)
    {
        if ($cmd eq "mi_insult") {
            my $insult = MI::get_random_insult();

            Irc::send_privmsg ($target, $insult);
        }
    }

    override process_privmsg ($sender, $target, $msg)
    {
        my $retort = MI::retort_to ($msg);
        Irc::send_privmsg ($target, $retort);
    }
}

1;

