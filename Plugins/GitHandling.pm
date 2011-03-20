#!/usr/bin/perl -w

use Modern::Perl;
use Test::More;

use MooseX::Declare;
use Plugin;

use MyGit;

class GitHandling extends DefaultPlugin
{
    override cmds
    {
        return qw(git);
    }

    override process_cmd ($sender, $target, $cmd, $arg)
    {
        if ($cmd eq "git") {
            if ($arg eq "head") {
                my $head = Git::head();
                Irc::send_privmsg ($target, "Latest commit: $head");
            }
            elsif ($arg eq "impact") {
                Irc::send_privmsg ($target, Git::changes_this_week());
            }
        }
    }

    override cmd_help ($cmd)
    {
        if ($cmd eq "git") {
            return "Supported cmds: head impact";
        }
        elsif ($cmd eq "git head") {
            return "Show current commit.";
        }
        elsif ($cmd eq "git impact") {
            return "How active have I been?.";
        }
    }
}

1;

