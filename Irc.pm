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
my $sock_lock = Thread::Semaphore->new(1);

my $has_connected = 0;

my %plugins;
my @cmd_list;

# "Automatic" plugin handling
sub register_plugin;
sub load_plugins;
sub unload_plugins;

# Locking down the socket for operations
sub read_sock;
sub write_sock;
# Our sock listening, should start in it's own thread
sub sock_listener;

# Send something to the server
sub send_msg;
# Send a PRIVMSG to the server
sub send_privmsg;

# When we've recieved a message
sub recieve_msg;
# Parse the recieved message
sub parse_recieved;
# Parse the message if we're not logged in
sub parse_pre_login_recieved;
# Process the message split into irc parts: prefix, cmd, param
sub process_irc_msg;

# We've recieved a PRIVMSG
sub process_privmsg;

# Process a bot command which came from irc
sub process_privmsg_cmd;
# Process a command from stdin
sub process_in_cmd;

# Main function which connects and waits for events
sub start;
# Will get called when we quit, either by SIGINT or regular quit
sub quit;

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
        (\S+)           # (2) cmd
        \s
        (.+)            # (3) parameters
        \r              # irc standard includes carriage return which we don't want
        $
    /x;

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

sub sock_listener
{
    my ($queue, $sock) = @_;
    while(my $input = read_sock($sock)) {
        # Prevent the server from being confused with our own input commands
        if ($input =~ /^\Q$Bot_Config::cmd_prefix\E/) {
            $input = "\\$input";
        }
        $queue->enqueue($input);
    }
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
    else {
        send_msg ("PRIVMSG $target :$msg");
    }
}

sub recieve_msg
{
    Log::recieved @_;
}

sub parse_recieved
{
    my ($msg) = @_;

    for my $plugin (values %plugins)
    {
        $plugin->process_bare_msg ($msg);
    }

    if ($msg =~ $match_irc_msg) {
        my $prefix;
        if (!defined ($1)) {
            $prefix = "";
        }
        else {
            $prefix = "$1";
        }
        my $cmd = $2;
        my $param = $3;

        process_irc_msg($prefix, $cmd, $param);
    }
    else {
        Log::error("Peculiar, we couldn't capture the message: ", $msg);
    }
}

sub parse_pre_login_recieved
{
    my ($input) = @_;

    # Check the numerical responses from the server.
    if ($input =~ /004/) {
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
    elsif ($input =~ /433/) {
        # Instead of death try to force use of some random nickname.
        my $rand_int = int(rand(100));
        send_msg "NICK $Bot_Config::nick$rand_int";
    }
}

sub process_irc_msg
{
    my ($prefix, $irc_cmd, $param) = @_;

    for my $plugin (values %plugins)
    {
        $plugin->process_irc_msg ($prefix, $irc_cmd, $param);
    }

    if( $irc_cmd =~ /PRIVMSG/ ) {
        process_privmsg ($prefix, $irc_cmd, $param);
    }
}

sub process_privmsg
{
    my ($prefix, $irc_cmd, $param) = @_;

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

        if ($msg =~ $match_cmd) {
            my $cmd = $1;
            my $args = $2;

            process_privmsg_cmd ($sender, $target, $cmd, $args);
        }
        else {
            for my $plugin (values %plugins)
            {
                $plugin->process_privmsg ($sender, $target, $msg);
            }
        }
    }
}

sub process_privmsg_cmd
{
    my ($sender, $target, $cmd, $args) = @_;

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

sub process_in_cmd
{
    my ($cmd, $args) = @_;

    Log::cmd "$cmd $args";

    if ($cmd eq "quit") {
        main::quit();
    }
    elsif ($cmd eq "msg" && $args =~ /(\S+)\s+(.*)/) {
        my $target = $1;
        my $msg = $2;

        send_privmsg $target, $msg;
    }
    elsif ($has_connected) {
        for my $plugin (values %plugins)
        {
            $plugin->process_cmd ("", "", $cmd, $args);
        }
    }
}

sub start
{
    my ($queue) = @_;

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

    # Worker thread so we can handle both socket input
    # and stdin input through queues.
    my $listener = threads->create(\&sock_listener, $queue, $sock);

    while (my $input = $queue->dequeue()) {
        chomp $input;

        if ($input =~ $match_cmd) {
            my $cmd = $1;
            my $args = $2;

            process_in_cmd ($cmd, $args);
        }
        else {
            if ($input =~ /^\\(.*)/) {
                $input = $1;
            }
            recieve_msg $input;

            # We must respond to PINGs to avoid being disconnected.
            if ($input =~ $match_ping) {
                send_msg "PONG $1";
            }

            if ($has_connected) {
                parse_recieved $input;
            }
            else {
                parse_pre_login_recieved $input;
            }
        }
    }
}

sub quit
{
    send_msg ("QUIT :$Bot_Config::quit_msg");
}

1;

