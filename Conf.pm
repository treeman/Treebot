#!/usr/bin/perl -w

use Modern::Perl;

package Conf;

our $server = "irc.quakenet.org";
our $port = 6667;

our $nick = "treebot";
our $username = "treebot";
our $realname = "Random Hacks Robot";

our @nick_reserves = ('treebot_', 'treebot2000', 'treestbot');

our @channels = ('#madeoftree', '#theobald');

our $cmd_prefix = ".";

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
    '.gitignore',
);
our %ignore_on_update;
for (@harmless_files) {
    $ignore_on_update{$_} = 1;
}

1;

