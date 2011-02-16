#!/usr/bin/perl

use Modern::Perl;
use Test::More;

use MooseX::Declare;
use Plugin;

class Git extends DefaultPlugin
{
    override load
    {
        $self->head(`git rev-parse HEAD`);
    }
    override module_cmds
    {
        return qw(git);
    }

    override process_cmd ($sender, $target, $cmd, $arg)
    {
        if ($cmd =~ /git/ && $arg =~ /status/) {
            my $head = $self->head();
            Irc::send_privmsg ($target, "Latest commit: $head");
        }
    }

    has 'head', is => 'rw';
}

1;

