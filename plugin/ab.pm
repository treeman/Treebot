#!/usr/bin/perl

use Modern::Perl;
use Test::More;

use MooseX::Declare;
use Plugin;

class ab extends DefaultPlugin
{
    method name
    {
        return "ab";
    }

    override module_cmds
    {
        return ("pew");
    }

    override process_cmd ($target, $cmd, $arg)
    {
        say "$target: .$cmd $arg";
    }

    override process_msg ($msg)
    {
        say "overridden! ", $msg;
    }

    override cmd_help ($cmd)
    {
        if( $cmd eq "pew" ) {
            return "user discretion is adviced.";
        }
    }
}

1;

