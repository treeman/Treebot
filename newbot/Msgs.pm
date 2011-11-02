#!/usr/bin/perl -w

use utf8;
use locale;

package Msgs;

use Modern::Perl;

use Conf;

our $quit = "Time for my beauty sleep.";

our $want_help = "If you want my help try ${Conf::cmd_prefix}help";

our $help = "I'm just a simple bot. Prefix commands with a $Conf::cmd_prefix to issue a command, ex `.mi_insult`. Type `${Conf::cmd_prefix}cmds for a list of commands.";
our $help_help = "Find out how I can service you.";
our $help_missing = "Sorry you're on your own!";

