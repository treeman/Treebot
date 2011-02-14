#!/usr/bin/perl

use Modern::Perl;
use Test::More;

use MooseX::Declare;
use Plugin;

class Stuff extends DefaultPlugin
{
    override module_cmds
    {
        return qw(id);
    }

    override process_cmd ($sender, $target, $cmd, $arg)
    {
        if ($cmd =~ /id/) {
            Irc::send_privmsg ($target, $arg);
        }
        elsif ($cmd =~ /botsnack/) {
            Irc::send_privmsg ($target, ":)");
        }
    }

    override process_privmsg ($sender, $target, $msg)
    {
        if ($msg =~ /(?:H[aei]l{1,3}o+|Y[o0]{1,2}|Tj[ao])\s+$Config::nick(!*)/i)
        {
            if (length($1) > 3) {
                Irc::send_privmsg ($target, "Mature $sender...");
            }
            else {
                Irc::send_privmsg ($target, "Hello $sender$1");
            }
        }
    }

    override cmd_help ($cmd)
    {
        if( $cmd eq "id" ) {
            return "user discretion is adviced.";
        }
    }
}

1;

