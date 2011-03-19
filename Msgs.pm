#!/usr/bin/perl -w

use Modern::Perl;

package Msgs;

use Conf;

our $quit_msg = "Time for my beauty sleep.";

our $help_msg = "I'm just a simple bot. Prefix with a $Conf::cmd_prefix to issue a command, ex: `.mi_insult`. Type `${Conf::cmd_prefix}cmds` for a list of commands.";

our $help_missing = "Sorry you're on your own.";

1;

