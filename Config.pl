#!/usr/bin/perl -w

use Modern::Perl;

package Config;

our $server = "irc.quakenet.org";
our $port = 6667;

our $nick = "treebot";
our $username = "treebot";
our $realname = "Random Hacks Robot";

our @channels = ('#madeoftree', '#theobald');

our $quit_msg = "Time for my beauty sleep.";

our $cmd_prefix = ".";

our $help_msg = "I'm just a simple bot. Prefix with a '$cmd_prefix' for commands. Type '.cmds' for a list of commands.";

our $log_dir = "logs/";

