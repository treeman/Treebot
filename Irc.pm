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

my $has_connected :shared = 0;

my %plugins;
my @cmd_list;

my @history :shared;
my $history_lock = Thread::Semaphore->new(1);

my %authed_nicks :shared;
my $nick_lock = Thread::Semaphore->new(1);

my $in_queue = Thread::Queue->new();
my $out_queue = Thread::Queue->new();

# Pairs of code to match against and the function reference to call when it happens
my @code_hooks;

# Worker threads for dispatching commands
my @workers;

# Create a worker thread and store it in workers
sub create_cmd_worker;

# "Automatic" plugin handling
sub register_plugin;
sub load_plugins;
sub unload_plugins;

# Thread for listening to stdin and dispatching cmds and stuff
sub stdin_listener;

# Locking down the socket for operations
sub read_sock;
# Our sock listening, should start in it's own thread
sub sock_listener;

# Place message in $in_queue
sub write_sock;
# Sends all messages in $in_queue for writing, should be a thread
sub socket_writer;
# Lock down socket and write
sub output_to_sock;

# Format and send a string to the server
sub send_msg;
# Send a PRIVMSG to the server
sub send_privmsg;

# Add a callback hook (code to match, function to call)
sub hook_at_code;
# Call, and remove, from code_hooks if the code matches (code, params-to-func)
sub call_code_hook;

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

# Process a bot command, should be a thread
sub process_cmd;
# Process an admin command, should be in a non main-thread
sub process_admin_cmd;

# Main function which connects and waits for events
sub start;
# Will get called when we quit, either by SIGINT or regular quit
sub quit;

# Cannot run in the same thread as a listener, will sleep
sub is_authed;

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

sub create_cmd_worker
{
    my $f = shift;
    my $thr = threads->create($f, @_);
    push (@workers, $thr);
}

sub get_history
{
    $history_lock->down();
    return @history;
    $history_lock->up();
}

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

sub stdin_listener
{
    while(<STDIN>) {
        chomp $_;
        if (/^\./) {
            # We've recieved an admin command
            create_cmd_worker(\&process_admin_cmd, $_);
        }
        elsif (/^<\s*(.*)/) {
            # Act like we recieve it from the socket
            say "~ $1";
            $in_queue->enqueue("$1\r\n");
        }
        else {
            # If it's not a command we just pipe it to the server
            send_msg ($_);
        }
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

sub sock_listener
{
    my ($in_queue, $sock) = @_;
    while(my $input = read_sock($sock)) {
        # Prevent the server from being confused with our own input commands
        if ($input =~ /^\Q$Bot_Config::cmd_prefix\E/) {
            $input = "\\$input";
        }
        $in_queue->enqueue($input);
    }
}

sub write_sock
{
    my ($msg) = @_;

    $out_queue->enqueue ($msg);
}

sub socket_writer
{
    my $sock = shift;

    while(my $msg = $out_queue->dequeue()) {
        chomp $msg;
        output_to_sock ($sock, $msg);
    }
}

sub output_to_sock
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

sub send_msg
{
    my $msg = join("", @_);

    if (length($msg) > 0 ) {
        write_sock($msg);
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

sub hook_at_code
{
    my ($code, $callback) = @_;

    push (@code_hooks, $code);
    push (@code_hooks, $callback);
}

sub call_code_hook
{
    my $code = shift @_;

    for (my $i = 0; $i < length (@code_hooks); $i += 2) {
        if ($code_hooks[$i] == $code) {
            my $id = $code_hooks[$i];
            my $f = $code_hooks[$i + 1];

            $f->();

            @code_hooks = splice( @code_hooks, $i, 2 );
        }
    }
}

sub recieve_msg
{
    Log::recieved @_;

    my ($msg) = join("", @_);
    $history_lock->down();
    @history = ($msg, @history);
    #$#history = 100; # Max history of 100, shouldn't need more
    $history_lock->up();
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
    #elsif ($input =~ /433/) {
        # Instead of death try to force use of some random nickname.
    #    my $rand_int = int(rand(100));
    #    send_msg "NICK $Bot_Config::nick$rand_int";
    #}
}

sub process_irc_msg
{
    my ($prefix, $irc_cmd, $param) = @_;

    for my $plugin (values %plugins)
    {
        $plugin->process_irc_msg ($prefix, $irc_cmd, $param);
    }

    if ($irc_cmd =~ /PRIVMSG/) {
        process_privmsg ($prefix, $irc_cmd, $param);
    }
    # Nick is authed
    elsif ($irc_cmd =~ /330/) {
        $param =~ /^\S+\s+(\S+)\s+(\S+)/;
        my $nick = $1;
        my $authed_nick = $2;

        $authed_nicks{$nick} = $authed_nick;
    }
    # End of whois
    elsif ($irc_cmd =~ /318/) {
        $param =~ /^\S+\s+(\S+)/;
        my $nick = $1;

        # If no entry, he isn't authed
        if (!defined($authed_nicks{$nick})) {
            $nick_lock->down();
                $authed_nicks{$nick} = 0;
            $nick_lock->up();
        }
    }
    elsif ($irc_cmd =~ /QUIT/) {
        $prefix =~ /^(.+?)!~/;
        my $nick = $1;

        # If entry exists, set it to 0
        if (exists($authed_nicks{$nick})) {
            $authed_nicks{$nick} = 0;
        }
    }
    elsif ($irc_cmd =~ /JOIN/) {
        $prefix =~ /^(.+?)!~/;
        my $nick = $1;

        # If we have an entry of this fellaw, undef it so we must check it again
        if (exists($authed_nicks{$nick})) {
            $authed_nicks{$nick} = undef;
        }
    }
    elsif ($irc_cmd =~ /NICK/) {
        $prefix =~ /^(.+?)!~/;
        my $old_nick = $1;

        $param =~ /^:(.*)/;
        my $new_nick = $1;

        say "swapping nicks: $old_nick $new_nick";

        if (exists($authed_nicks{$old_nick})) {
            $authed_nicks{$new_nick} = $authed_nicks{$old_nick};
            $authed_nicks{$old_nick} = undef;
        }
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

            create_cmd_worker (\&process_cmd, $sender, $target, $cmd, $args);
        }
        else {
            for my $plugin (values %plugins)
            {
                $plugin->process_privmsg ($sender, $target, $msg);
            }
        }
    }
}

sub process_cmd
{
    my ($sender, $target, $cmd, $args) = @_;

    if ($cmd eq "help") {
        if ($args =~ /^\s*$/) {
            Irc::send_privmsg ($target, $Bot_Config::help_msg);
        }
    }
    elsif ($cmd =~ /^cmds|commands$/) {
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

sub process_admin_cmd
{
    my ($input) = @_;

    if ($input =~ $match_cmd) {
        my $cmd = $1;
        my $args = $2;

        Log::cmd" $cmd $args";

        if ($cmd eq "quit") {
            main::quit();
        }
        elsif ($cmd eq "msg" && $args =~ /(\S+)\s+(.*)/) {
            my $target = $1;
            my $msg = $2;

            send_privmsg $target, $msg;
        }
        elsif ($cmd eq "history") {
            $, = "\n";
            say @history;
        }
        elsif ($cmd eq "check") {
            $args =~ /^(\S+)/;
            my $nick = $1;

            if (is_authed ($nick) ) {
                say "Very authed indeed!";
            }
            else {
                say "Nope, no auth there!";
            }
        }
        elsif ($cmd eq "admin") {
            $args =~ /^(\S+)/;
            my $nick = $1;

            if (is_admin ($nick) ) {
                say "Very admin indeed!";
            }
            else {
                say "Nope, no admin there!";
            }
        }
        elsif ($has_connected) {
            for my $plugin (values %plugins)
            {
                $plugin->process_cmd ("", "", $cmd, $args);
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
    $sock_lock->up(2);

    # Log on to the server.
    send_msg "NICK $Bot_Config::nick";
    send_msg "USER $Bot_Config::username 0 * :$Bot_Config::realname";

    # Worker thread for listening and parsing stdin cmds
    my $stdin_listener = threads->create(\&stdin_listener);

    # Worker thread so we can handle both socket input
    # and stdin input through queues.
    my $sock_listener = threads->create(\&sock_listener, $in_queue, $sock);

    # Worker who outputs everything from the $out_queue to the socket
    # so we can write to socket from other threads
    my $sock_writer = threads->create(\&socket_writer, $sock);

    while (my $input = $in_queue->dequeue()) {
        chomp $input;

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

sub quit
{
    send_msg ("QUIT :$Bot_Config::quit_msg");
}

sub is_authed
{
    my ($nick) = @_;
    my $whois_sent = 0;

    while (1) {
        if (defined($authed_nicks{$nick})) {
            if ($authed_nicks{$nick}) {
                return 1;
            }
            else {
                return 0;
            }
        }
        elsif (!$whois_sent) {
            send_msg "WHOIS $nick";
            sleep 1;
        }
        else {
            sleep 1;
        }
    }
}

sub is_admin
{
    my ($nick) = @_;

    if (is_authed ($nick)) {
        my $authed_nick = $authed_nicks{$nick};
        for my $admin (@Bot_Config::admins) {
            if ($admin eq $authed_nick) {
                return 1;
            }
        }
    }
    return 0;
}

1;

