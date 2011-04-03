#!/usr/bin/perl

use utf8;
use locale;

use Modern::Perl;
use Test::More;

use MooseX::Declare;
use Plugin;
use MonkeyIsland;

class Pokemon extends DefaultPlugin
{
    override cmds
    {
        return qw(pokédex);
    }

    override process_cmd ($sender, $target, $cmd, $args)
    {
        if ($cmd =~ /^pok[eé]dex/) {
            if ($cmd =~ /random/) {
                1;
            }
        }
    }

    override cmd_help ($cmd)
    {
        if ($cmd =~ /^pok[eé]dex/) {
            return "Pokémons <3.";
        }
    }
}

1;

