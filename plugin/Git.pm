#!/usr/bin/perl

use Modern::Perl;
use Test::More;

use MooseX::Declare;
use Plugin;

class Git extends DefaultPlugin
{
    override load
    {
        $self->git_commit = `git rev-parse HEAD`;
    }
    override module_cmds
    {
        return qw(git);
    }

    override process_cmd ($sender, $target, $cmd, $arg)
    {
        if ($cmd =~ /git/ && $arg =~ /status/) {
            my $head = `git rev-parse HEAD`;
            chomp $head;
            Irc::send_privmsg ($target, "Latest commit: $head");
        }
    }

    has 'git_commit', is => 'rw';
}

1;

