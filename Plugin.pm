#!/usr/bin/perl

use Modern::Perl;
use Test::More;
use MooseX::Declare;

# module_cmds -> @commands to listen to
# module_help -> $cmd -> $help_msg
# process -   -> $msg -> $target -> $cmd -> 

role Plugin
{
    requires qw(
        name
        module_cmds
        process_cmd
        process_msg
        cmd_help
        load
        unload );
}

class DefaultPlugin
{
    # return list of commands the plugin listens to
    method module_cmds { return (); }

    # target, cmd, args
    method process_cmd { }

    # a standard irc message
    # prefix, command, parameters (the rest)
    method process_irc_msg { }

    # whole recieved irc message
    method process_msg { }

    # should return a help message for every command the module defines
    method cmd_help { }

    method load { }
    method unload { }
}

1;

