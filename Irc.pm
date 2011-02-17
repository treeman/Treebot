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
my $sock_lock = Thread::Semaphore->new(0);

my %plugins;
my @cmd_list;

sub register_plugin;
sub load_plugins;
sub unload_plugins;

sub read_sock;
sub write_sock;

sub send_msg;
sub send_privmsg;

sub recieve_msg;
sub parse_msg;
sub process_msg;

sub start;
sub quit;

## Implementation

sub register_plugin
{
    my ($name, $plugin) = @_;

    $plugins{$name} = $plugin;
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
}

sub unload_plugins
{
    for my $plugin (values %plugins)
    {
        $plugin->unload();
    }
    %plugins = ();
}

sub write_sock
{
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

sub read_sock
{
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

sub send_msg
{
    my $msg = join("", @_);

    if (length($msg) > 0 ) {
        write_sock $msg;
    }
    else {
        Log::error("trying to send an empty message.");
    }
}

sub send_privmsg
{
    my ($target, $msg) = @_;

    send_msg ("PRIVMSG $target :$msg");
}

sub recieve_msg
{
    Log::recieved @_;
}

sub parse_msg
{
    my ($msg) = @_;

    for my $plugin (values %plugins)
    {
        $plugin->process_bare_msg ($msg);
    }

    if( $msg =~ /
            ^
            (?:
               :(\S+) # (1) prefix
               \s
            )?        # prefix isn't mandatory
            (\S+)     # (2) cmd
            \s
            (.+)      # (3) parameters
            \r        # irc standard includes carriage return :<
            $
        /x )
    {
        my $prefix;
        if (!defined ($1)) {
            $prefix = "";
        }
        else {
            $prefix = "$1";
        }
        my $cmd = $2;
        my $param = $3;

        process_msg($prefix, $cmd, $param);
    }
    else {
        Log::error("! peculiar, we couldn't capture the message: ", $msg);
    }
}

sub process_msg
{
    my ($prefix, $irc_cmd, $param) = @_;

    for my $plugin (values %plugins)
    {
        $plugin->process_irc_msg ($prefix, $irc_cmd, $param);
    }

    if( $irc_cmd =~ /PRIVMSG/ ) {
        if( $param =~ /^(\S+)\s:(.*)$/ ) {
            my $target = $1;
            my $msg = $2;

            $prefix =~ /^(.+?)!~/;
            my $sender = $1;

            # if we're the target change target so we don't message ourselves
            # this looks pretty bad really, change?
            if ($target =~ /$Bot_Config::nick/) {
                $target = $sender;
            }

            if ($msg =~ /
                      ^\Q$Bot_Config::cmd_prefix\E  # cmd prefix
                      (\S*)                     # (1) cmd
                      \s*
                      (.*)                      # (2) args
                    /x) {
                my $cmd = $1;
                my $args = $2;

                if ($cmd eq "help") {
                    if ($args =~ /^\s*$/) {
                        Irc::send_privmsg ($target, $Bot_Config::help_msg);
                    }
                }
                elsif ($cmd eq "cmds") {
                    my $msg = "Documented commands: " . join(", ", @cmd_list);
                    Irc::send_privmsg ($target, $msg);
                }
                else {
                    for my $plugin (values %plugins)
                    {
                        $plugin->process_cmd ($sender, $target, $cmd, $args);
                    }
                }
            }
            else {
                for my $plugin (values %plugins)
                {
                    $plugin->process_privmsg ($sender, $target, $msg);
                }
            }
        }
    }
}

sub start
{
    # Connect to the IRC server.
    $sock = new IO::Socket::INET(PeerAddr => $Bot_Config::server,
                                 PeerPort => $Bot_Config::port,
                                 Proto => 'tcp') or
                                    die "Can't connect\n";

    # Now the socket is ready for usage.
    $sock_lock->up();

    # Log on to the server.
    send_msg "NICK $Bot_Config::nick";
    send_msg "USER $Bot_Config::username 0 * :$Bot_Config::realname";

    my $has_connected = 0;
    while (my $input = <$sock>) {
        chop $input;

        recieve_msg $input;

        # We must respond to PINGs to avoid being disconnected.
        if ($input =~ /^PING\s(.*)$/i) {
            send_msg "PONG $1";
        }

        if ($has_connected) {
            parse_msg $input;
        }
        else {
            # Check the numerical responses from the server.
            if ($input =~ /004/) {
                # We are now logged in, so join.
                for my $channel (@Bot_Config::channels)
                {
                    $has_connected = 1;

                    send_msg "JOIN $channel";

                    # Actually load all plugins.
                    load_plugins();
                }
            }
            elsif ($input =~ /433/) {
                # Instead of death try to force use of some random nickname.
                my $rand_int = int(rand(100));
                send_msg "NICK $Bot_Config::nick$rand_int";
            }
        }
    }
}

sub quit
{
    send_msg ("QUIT :$Bot_Config::quit_msg");
}

1;

