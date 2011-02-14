#!/usr/bin/perl -w

use Modern::Perl;

package Config;

our $server = "irc.quakenet.org";
our $port = 6667;

our $nick = "treebot";
our $username = "treebot";
our $realname = "Random Hacks Robot";

our $channel = "#madeoftree";

our $quit_msg = "Time for my beauty sleep.";

our $cmd_prefix = qr/\./;

