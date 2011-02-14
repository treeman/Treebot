#!/usr/bin/perl -w

use Modern::Perl;

package Config;

# The server to connect to and our details.
our $server = "irc.quakenet.org";
our $port = 6667;

our $nick = "treebot";
our $username = "treebot";
our $realname = "Random Hacks Robot";

# The channel which the bot will join.
our $channel = "#madeoftree";

our $quit_msg = "Time for my beauty sleep.";

