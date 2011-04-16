#!/usr/bin/perl

use utf8;
use locale;

use Modern::Perl;
use Test::More;
use MooseX::Declare;
use LWP::Simple;

use Plugin;
use Log;
use HN;

class News extends DefaultPlugin
{
    override cmds
    {
        return qw(hn);
    }

    override process_cmd ($sender, $target, $cmd, $arg)
    {
        if ($cmd eq "hn") {
            my @items = HN::short_frontpage();
            map { Irc::send_privmsg ($target, $_) } @items;
        }
    }
}

1;

