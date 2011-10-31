#!/usr/bin/perl

use utf8;
use locale;

use Modern::Perl;
use Test::More;

use MooseX::Declare;
use Time::Seconds;

use Plugin;
use Conf;

class Stuff extends DefaultPlugin
{
    override load () {
        $self->started(time);
    }

    override cmds () {
        return qw(id
                  botsnack
                  status
                  uptime
                  hello
                  pokédex);
    }

    override undocumented_cmds () {
        return qw(pew
                  src
                  bnet);
    }

    override admin_cmds () {
        return qw(server_uptime);
    }

    override process_cmd ($sender, $target, $cmd, $arg) {

        if ($cmd eq "id" && length($arg) < 80) {
            Irc::irc_privmsg ($target, $arg);
        }
        elsif ($cmd eq "botsnack") {
            Irc::irc_privmsg ($target, ":)");
        }
        elsif ($cmd eq "status") {
            # http status of the bot
            Irc::irc_privmsg ($target, "Status: 418 I'm a teapot");
        }
        elsif ($cmd =~ /^src|source$/) {
            Irc::irc_privmsg ($target, "http://github.com/treeman/Treebot");
        }
        elsif ($cmd eq "bnet") {
            Irc::irc_privmsg ($target, "bnet 2.0: so good you won't want lan.");
        }
    }

    override process_privmsg ($sender, $target, $msg) {

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
            my ($shout, $exclam, $one) = ($1, $2, $3);
            $one = "" if (!$one);

            if ($one) {
                Irc::irc_privmsg ($target, "$shout $sender$exclam");
            }
            elsif (length ($exclam) > 3) {
                Irc::irc_privmsg ($target, "Mature $sender...");
            }
            else {
                Irc::irc_privmsg ($target, "$shout $sender$exclam");
            }
        }
    }

    has 'started', is => 'rw';
}

1;

