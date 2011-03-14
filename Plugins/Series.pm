#!/usr/bin/perl -w

use Modern::Perl;
use Test::More;
use LWP::Simple;
use MooseX::Declare;

use threads;
use threads::shared;

use Plugin;
use Log;
use Util::Site;
use Show;

class Series extends DefaultPlugin
{
    override cmds
    {
        return qw(nextep);
    }

    override process_cmd ($sender, $target, $cmd, $arg)
    {
        if ($cmd eq "nextep") {
            chomp $arg;

            if ($arg =~ /^\s*$/) {
                return;
            }
            else {
                my $msg = Show::show_info ($arg);
                Irc::send_privmsg ($target, $msg);
            }
        }
    }

    override cmd_help ($cmd)
    {
        if ($cmd eq "nextep") {
            return "Get the latest episode of your fav tv series.";
        }
    }
}

1;

