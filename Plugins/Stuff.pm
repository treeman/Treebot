#!/usr/bin/perl

use Modern::Perl;
use Test::More;

use MooseX::Declare;
use Plugin;
use Conf;
use Util;

use Time::Seconds;

class Stuff extends DefaultPlugin
{
    override load
    {
        $self->started(time);
    }

    override cmds
    {
        return qw(id
                  botsnack
                  status
                  uptime
                  hello);
    }

    override undocumented_cmds
    {
        return qw(pew
                  src);
    }

    override admin_cmds
    {
        return qw(server_uptime);
    }

    override process_cmd ($sender, $target, $cmd, $arg)
    {
        if ($cmd eq "id" && length($arg) < 80) {
            Irc::send_privmsg ($target, $arg);
        }
        elsif ($cmd eq "botsnack") {
            Irc::send_privmsg ($target, ":)");
        }
        elsif ($cmd eq "status") {
            # http status of the bot
            Irc::send_privmsg ($target, "Status: 418 I'm a teapot");
        }
        elsif ($cmd eq "uptime") {
            my $passed = time() - $self->started();

            my $time = Util::format_time ($passed);
            my $msg = "Uptime: $time";

            Irc::send_privmsg ($target, $msg);
        }
        elsif ($cmd eq "pew") {
            if (Irc::is_admin ($sender)) {
                Irc::send_privmsg ($target, "IMBALAZOR!!!!");
            }
            else {
                Irc::send_privmsg ($target, "pew..");
            }
        }
        elsif ($cmd =~ /^src|source$/) {
            Irc::send_privmsg ($target, "http://github.com/treeman/Treebot");
        }
    }

    override process_admin_cmd ($sender, $target, $cmd, $arg)
    {
        if ($cmd eq "server_uptime") {
            my $txt = `cat /proc/uptime`;
            if ($txt =~ /^(\d+\.\d+)/) {
                my $time = Util::format_time ($1);
                my $msg = "Server uptime: $time";

                Irc::send_privmsg ($target, $msg);
            }
        }
    }

    override process_privmsg ($sender, $target, $msg)
    {
        if ($msg =~ /
              ^(                  # Match opening greeting phrase
                H[aei]l{1,3}o+|
                (?:Y[o0]{1,2})+|
                Tj[ao]|
                Hi|
                Yoho|
                Hoho|
                håjj\s?håjj
              )
              \s+                 # Mannered men don't use random words after greeting
              $Conf::nick
              (                   # Of course some exclamationmarks are cool
                [!\?\s]*
              )
              (!+1+one)?        # Match the wonderful !!!!!11one
              $
            /ix)
        {
            if (defined($3) ) {
                Irc::send_privmsg ($target, "$1 $sender$2$3");
            }
            elsif (length($2) > 3) {
                Irc::send_privmsg ($target, "Mature $sender...");
            }
            else {
                Irc::send_privmsg ($target, "$1 $sender$2");
            }
        }
    }

    override cmd_help ($cmd)
    {
        if ($cmd eq "id") {
            return "Return whatever you write.";
        }
        elsif ($cmd eq "botsnack") {
            return "Give me a snack will ya?";
        }
        elsif ($cmd eq "status") {
            return "Check my status.";
        }
        elsif ($cmd eq "uptime") {
            return "How long have I been alive?";
        }
        elsif ($cmd eq "hello") {
            return "I'll try to respond when you say hi to me.";
        }
    }

    has 'started', is => 'rw';
}

1;

