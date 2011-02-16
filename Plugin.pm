#!/usr/bin/perl

use Modern::Perl;
use Test::More;
use MooseX::Declare;

role Plugin
{
    requires qw(
        module_cmds
        process_cmd
        process_irc_msg
        process_privmsg
        process_bare_msg
        cmd_help
        load
        unload );
}

class DefaultPlugin with Plugin
{
    method load { }
    method unload { }

    # return list of commands the plugin listens to
    method module_cmds { return (); }

    # sender, target, cmd, args
    method process_cmd { }

    # sender, target, msg
    method process_privmsg { }

    # a standard irc message
    # prefix, command, parameters (the rest)
    method process_irc_msg { }

    # whole recieved irc message
    method process_bare_msg { }

    # should return a help message for every command the module defines
    method cmd_help { }
}

1;

