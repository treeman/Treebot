#!/usr/bin/perl

use Modern::Perl;
use Test::More;
use MooseX::Declare;
use LWP::Simple;

use Plugin;
use Log;
use Find;

class Probe extends DefaultPlugin
{
    override cmds
    {
        return qw(down?
                  whois?);
    }

    override process_cmd ($sender, $target, $cmd, $arg)
    {
        if ($cmd eq "down?") {
            my $site = LWP::Simple::get "http://www.isup.me/$arg";

            if ($site =~ /<div\sid="container">\s*?
                          (.+)?
                          \s*<p>
                         /xs)
            {
                my $isup = $1;
                $isup =~ s/<[^>]*>//g;
                $isup =~ s/\n//g;
                $isup =~ s/\r//g;
                $isup =~ s/ +/ /g;
                $isup =~ s/^ +//g;

                Irc::send_privmsg ($target, $isup);
            }
            else {
                Log::error "Couldn't match down? response!";
            }
        }
        elsif ($cmd eq "whois?") {
            my $msg = Find::number ($arg);
            Irc::send_privmsg ($target, $msg);
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
    }
}

1;

