#!/usr/bin/perl

use utf8;
use locale;

use Modern::Perl;
use Test::More;
use MooseX::Declare;
use LWP::Simple;

use Plugin;
use Log;

class Admin extends DefaultPlugin
{
    override admin_cmds
    {
        return qw(msg join part is_auth? is_admin? authed_as?);
    }

    override process_admin_cmd ($sender, $target, $cmd, $arg)
    {
        if ($cmd eq "msg") {
            $arg =~ /^(\S+)\s+(\S+)$/;
            my $target = $1;
            my $msg = $2;
            Irc::send_privmsg ($target, $msg);
        }
        elsif ($cmd eq "pipe") {
            if ($arg) {
                Irc::push_out ($arg);
            }
        }
        elsif ($cmd eq "join") {
            my @joined;
            map {
                if ($_ =~ /^[#&][^,]+$/) {
                    push (@joined, $_);
                }
            } split(/ /, $arg);

            if (scalar @joined) {
                Irc::irc_join @joined;

                my $msg = "Joined " . join(", ", @joined) . ".";
                Irc::send_privmsg ($target, $msg);
            }
        }
        elsif ($cmd eq "part") {
            $arg =~ /^(\S+)\s*(.*)$/;
            my $channel = $1;
            my $msg = $2;

            say $channel;
            say $msg;

            Irc::irc_part ($channel, $msg);
        }
        elsif ($cmd eq "is_auth?") {
            if (Irc::is_authed ($arg)) {
                Irc::send_privmsg $target, "$arg is auth";
            }
            else {
                Irc::send_privmsg $target, "$arg is not auth";
            }
        }
        elsif ($cmd eq "authed_as?") {
            if (Irc::is_authed ($arg)) {
                my $nick = Irc::authed_as ($arg);
                Irc::send_privmsg $target, "$arg is authed as $nick";
            }
            else {
                Irc::send_privmsg $target, "$arg is not auth";
            }
        }
        elsif ($cmd eq "is_admin?") {
            if (Irc::is_admin ($arg)) {
                Irc::send_privmsg $target, "$arg is admin!";
            }
            else {
                Irc::send_privmsg $target, "$arg is not admin";
            }
        }
        elsif ($cmd eq "is_op?") {
            if ($target =~ /^#/) {
                if (Irc::is_op ($target)) {
                    Irc::send_privmsg ($target, "yes i'm op.");
                }
                else {
                    Irc::send_privmsg ($target, "no i'm not :/");
                }
            }
            else {
                Irc::send_privmsg ($target, "i'm opping this conversation!!");
            }
        }
        elsif ($cmd eq "is_online?") {
            if ($arg) {
                if (Irc::is_online ($arg)) {
                    Irc::send_privmsg ($target, "$arg is online.");
                }
                else {
                    Irc::send_privmsg ($target, "$arg isn't online.");
                }
            }
            else {
                Irc::send_privmsg ($target, "Hell yeah I'm online!");
            }
        }
    }
}

1;

