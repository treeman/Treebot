#!/usr/bin/perl -w

use Modern::Perl;

package Conf;

our $server = "irc.quakenet.org";
our $port = 6667;

our $nick = "treebot";
our $username = "treebot";
our $realname = "Random Hacks Robot";

our @channels = ('#madeoftree', '#theobald');

our $quit_msg = "Time for my beauty sleep.";

our $cmd_prefix = ".";

our $help_msg = "I'm just a simple bot. Prefix with a '$cmd_prefix' for commands. Type '${cmd_prefix}cmds' for a list of commands.";
our $help_missing = "Sorry you're on your own.";

our $log_dir = "logs/";
our $log_ping = 0;
our $log_pong = 0;

our @admins = ('Mowah');

our $plugin_folder = "plugin/";

# Used to filter out unnecessary stuff
our @log_blacklist = (
    # Ping pong is interesting to play but not to watch
    qr/^. PING/,
    qr/^. PONG/,

    # Huge messages
    qr/^< \S+ (37\d|25\d)/,

    # Dunno about this, seems not very useful - and large
    qr/^< \S+ 005/,
);

# Used to only show bare essentials
our @log_whitelist = (
    qr/PRIVMSG/,
    qr/JOIN|PART|QUIT/,
    qr/^[!*]/,
);

1;

