#!/usr/bin/perl

use utf8;
use locale;

use Modern::Perl;
use Test::More;
use MooseX::Declare;
use LWP::Simple;

use Plugin;
use Log;
use Tell;

class TellUser extends DefaultPlugin
{
    override cmds
    {
        return qw(tell);
    }

    override process_cmd ($sender, $target, $cmd, $arg)
    {
        if ($cmd eq "tell") {
            $arg =~ /(\S+)\s(.*)/;
            my $nick = $1;
            my $what = $2;

            Tell::tell_user_from ($nick, $sender, $what);
            Tell::issue_tell ($nick);
        }
        elsif ($cmd eq "messages") {
            my @messages = Tell::shift_tell ($sender, Irc::authed_as ($sender));
            if (scalar @messages) {
                map { Irc::send_privmsg ($sender, $_); } @messages;
            }
            else {
                Irc::send_privmsg ($sender, "Sorry no new messages.");
            }
        }
        elsif ($cmd eq "tt") {
            #Tell::issue_tell ($arg);
        }
    }

    override process_irc_msg ($prefix, $cmd, $param)
    {
        if ($cmd eq "JOIN") {
            my $nick = Irc::prefix_to_nick ($prefix);

            Tell::issue_tell ($nick);
        }
    }
}

1;

