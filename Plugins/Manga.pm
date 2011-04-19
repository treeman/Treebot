#!/usr/bin/perl

use utf8;
use locale;

use Modern::Perl;
use Test::More;
use MooseX::Declare;
use LWP::Simple;

use Plugin;
use Log;
use Mangaprobe;

class Manga extends DefaultPlugin
{
    override load
    {
        #Manga::init();
        #Manga::load_from_disk();
        #Manga::recheck_known_manga();
    }

    override unload
    {
        #Manga::close();
    }

    override cmds
    {
        return qw(manga);
    }

    override process_cmd ($sender, $target, $cmd, $arg)
    {
        if ($cmd eq "manga") {
            say "getting '$arg'";
            my @manga = Manga::get_manga ($arg);
            if (scalar @manga) {
                map { Irc::send_privmsg ($target, $_) } @manga;
            }
            else {
                Irc::send_privmsg ($target, "Nothing found sorry.");
            }
        }
    }
}

1;

