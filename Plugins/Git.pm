#!/usr/bin/perl

use Modern::Perl;
use Test::More;

use MooseX::Declare;
use Plugin;

class Git extends DefaultPlugin
{
    override load
    {
        say "Git loaded!";
        $self->head(`git rev-parse HEAD`);
    }

    override cmds
    {
        return qw(git);
    }

    override process_cmd ($sender, $target, $cmd, $arg)
    {
        if ($cmd eq "git") {
            if ($arg =~ /^commit$/) {
                my $head = $self->head();
                chomp $head;
                Irc::send_privmsg ($target, "Latest commit: $head");
            }
        }
    }

    override cmd_help ($cmd)
    {
        say "cmd: $cmd";
        if ($cmd eq "git") {
            return "Supported cmds: commit";
        }
        elsif ($cmd eq "git commit") {
            return "Show current commit.";
        }
    }

    has 'head', is => 'rw';
}

1;

