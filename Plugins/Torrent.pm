#!/usr/bin/perl

use utf8;
use locale;

use Modern::Perl;
use Test::More;
use MooseX::Declare;
use LWP::Simple;

use Plugin;
use Log;
use Btpd;

class Torrent extends DefaultPlugin
{
    override admin_cmds
    {
        return qw(torrent);
    }

    override process_admin_cmd ($sender, $target, $cmd, $arg)
    {
        if ($cmd eq "torrent") {

            if ($arg eq "start") {
                if (Btpd::start()) {
                    Irc::send_privmsg ($target, "Daemon started.");
                }
                else {
                    Irc::send_privmsg ($target, "Already started.");
                }
            }
            elsif ($arg eq "kill") {
                Btpd::kill();
                Irc::send_privmsg ($target, "Daemon killed.");
            }
            elsif ($arg eq "stat") {
                my $msg = Btpd::stat();
                Irc::send_privmsg ($target, $msg);
            }
        }
    }
}

1;

