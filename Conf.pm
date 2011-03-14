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

# Trailing / important
our $plugin_folder = "Plugins/";

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
    # Interesting stuff
    qr/PRIVMSG/,
    qr/JOIN|PART|QUIT/,

    # Errors and exe stuff
    qr/^[!*]/,
);

# Files that don't matter if we change when the bot is running
# So it won't reload after a git pull if they're the only thing changed
my @harmless_files = (
    'readme',
    'ideas',
);
our %ignore_on_update;
for (@harmless_files) {
    $ignore_on_update{$_} = 1;
}

1;

