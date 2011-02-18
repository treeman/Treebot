#!/usr/bin/perl -w

use Modern::Perl;
use MooseX::Declare;
use IO::Socket;

use threads;
use threads::shared;
use Thread::Semaphore;

use Plugin;
use Log;
use Bot_Config;

package Irc;

my $sock;
my $sock_lock = Thread::Semaphore->new(2);

my $has_connected = 0;

my %plugins;
my @cmd_list;

my %authed_nicks;

my $queue;

# Public
sub start;
sub quit;

sub register_plugin;

sub send_msg;
sub send_privmsg;

sub read_sock;
sub write_sock;

# Private
sub load_plugins;
sub unload_plugins;

sub parse_recieved_from_irc;

sub process_irc_msg;
sub process_privmsg;
sub process_privmsg_cmd;
sub process_in_cmd;

# Threaded
sub sock_listener;
sub stdin_listener;

## Implementation

# Regex parsing of useful stuff
my $match_ping = qr/^PING\s(.*)$/i;

my $match_cmd =
    qr/
        ^\Q$Bot_Config::cmd_prefix\E  # cmd prefix
        (\S*)                         # (1) cmd
        \s*
        (.*)                          # (2) args
    /x;

my $match_irc_msg =
    qr/
        ^
        (?:
            :(\S+)      # (1) prefix
            \s
        )?              # prefix isn't mandatory
        (\S+)           # (2) code
        \s
        (.+)            # (3) parameters
        \r              # irc standard includes carriage return which we don't want
        $
    /x;

sub start;
sub quit
{
    send_msg ("QUIT :$Bot_Config::quit_msg");
}

sub register_plugin
{
    my ($name, $plugin) = @_;

    $plugins{$name} = $plugin;
}

sub send_msg
{
    my $msg = join("", @_);

    if (length($msg) > 0 ) {
        write_sock($sock, $msg);
    }
    else {
        Log::error("trying to send an empty message.");
    }
}
sub send_privmsg
{
    my ($target, $msg) = @_;

    # If target is empty it's to the commandline
    if ($target eq "") {
        Log::out $msg;
    }
    elsif (length($msg) > 0) {
        send_msg ("PRIVMSG $target :$msg");
    }
}

sub read_sock
{
    my $sock = shift;
    if (defined($sock)) {
        $sock_lock->down();
            my $input = <$sock>;
        $sock_lock->up();
        return $input;
    }
    else {
        Log::error "Trying to read sock but it's closed";
        return 0;
    }
}

sub write_sock
{
    my $sock = shift;
    my $msg = join("", @_);

    if (defined($sock)) {
        $sock_lock->down();
            print $sock "$msg\r\n";
            Log::sent($msg);
        $sock_lock->up();
    }
    else {
        Log::error "Trying to write to sock but it's closed: ", $msg;
    }
}

sub load_plugins
{
    for my $plugin (values %plugins)
    {
        $plugin->load();
        my @cmds = $plugin->module_cmds();
        for my $cmd (@cmds) {
            if ($cmd) {
                push(@cmd_list, $cmd);
            }
        }
    }

    push(@cmd_list, "cmds");
    push(@cmd_list, "help");

    @cmd_list = sort(@cmd_list);
}
sub unload_plugins
{
    for my $plugin (values %plugins)
    {
        $plugin->unload();
    }
    %plugins = ();
}

sub parse_recieved_from_irc
{
    my ($msg) = @_;

    my $parsed_okay = $msg =~ $match_irc_msg;

    my $prefix;
    if (!defined ($1)) {
        $prefix = "";
    }
    else {
        $prefix = "$1";
    }
    my $code = $2;
    my $param = $3;

    if (!$parsed_okay) {
        Log::error("Peculiar, we couldn't capture the message: ", $msg);
    }
    elsif ($has_connected) {
        process_irc_msg($prefix, $code, $param);
    else {
        # Check the numerical responses from the server.
        if ($code =~ /004/) {
            # We managed to login, yay!
            $has_connected = 1;

            # Actually load all plugins.
            load_plugins();

            # We are now logged in, so join.
            for my $channel (@Bot_Config::channels) {
                send_msg "JOIN $channel";
            }

            # Register our nick if we're on quakenet
            if ($Bot_Config::server =~ /quakenet/) {
                open my $fh, '<', "Q-pass";
                my $pass = <$fh>;
                chomp $pass;
                send_privmsg
                    "Q\@CServe.quakenet.org",
                    "AUTH $Bot_Config::nick $pass";
            }
        }
        elsif ($code =~ /433/) {
            # Instead of death try to force use of some random nickname.
            my $rand_int = int(rand(100));
            send_msg "NICK $Bot_Config::nick$rand_int";
        }
    }
}
sub process_irc_msg;

sub process_privmsg;
sub process_privmsg_cmd;
sub process_in_cmd; # Rename, perhaps to admin or something

sub sock_listener
{
    my ($queue, $sock) = @_;
    while(my $input = read_sock($sock)) {
        # Prevent the server from being confused with our own input commands
        if ($input =~ /^[.!]/) {
            $input = "\\$input";
        }
        $queue->enqueue($input);
    }
}
sub stdin_listener
{
    my ($queue) = @_;
    while(<STDIN>) {
        chomp $_;
        if (/^\./) {
            # If it's the command it will be taken care of
            $queue->enqueue($_);
        }
        else {
            # Differentiate from recieved commands
            # this will be sent raw, except the !
            $_ = "!" . $_;
            $queue->enqueue($_);
        }
    }
}

1;

