#!/usr/bin/perl -w

package Irc;

use Modern::Perl;
use MooseX::Declare;
use IO::Socket;

use threads;
use threads::shared;
use Thread::Semaphore;

use Plugin;
use Log;
use Bot_Config;

# Create a worker thread and store it in workers
sub create_cmd_worker;

# Plugin handling
sub resolve_plugin_name;
sub list_loaded_plugins;
sub list_available_plugins;

sub load_plugins;
sub unload_plugins;

sub load_plugin;
sub unload_plugin;
sub reload_plugin;

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

# Logs everything from out_queue
sub out_redirect;

# Format and send a string to the server
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

# Process a bot command, should be a thread
sub process_cmd;
# Process an admin command, should be in a non main-thread
sub process_admin_cmd;

# Main function which connects and waits for events
sub start;
# Will get called when we quit, either by SIGINT or regular quit
sub quit;

# Irc helper functions
sub irc_join;
sub irc_part;
sub irc_kick;

# Cannot run in the same thread as a listener, will sleep
sub is_authed;
sub authed_as;
sub is_admin;

my $sock;
my $sock_lock = Thread::Semaphore->new(2);

my $has_connected :shared = 0;

# shared reference to our plugins
my $plugins :shared;
my %real_plugins;
$plugins = share(%real_plugins);
my $plugin_lock = Thread::Semaphore->new();

my @cmd_list :shared;
my @undoc_cmd_list :shared;
my @admin_cmd_list :shared;

my %authed_nicks :shared;
my $nick_lock = Thread::Semaphore->new();

my $in_queue = Thread::Queue->new();
my $out_queue = Thread::Queue->new();

# Worker threads dispatched for commands
# Probably should be removed when they're done?
my @workers;

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

sub resolve_plugin_name
{
    my ($name) = @_;
    my $dir = $Bot_Config::plugin_folder;
    my $file = $name;

    if ($file !~ /^.*\.pm$/) {
        $file = $file . ".pm";
    }
    if ($file !~ /^\E$dir\Q/) {
        $file = $dir . $file;
    }

    if (-e $file) {
        return $file;
    }
    else {
        return "";
    }
}
sub list_loaded_plugins
{
    my @list;

    for my $path (keys %{$plugins}) {
        if ($path =~ /\/([^\/]*)\.pm$/) {
            push (@list, $1);
        }
    }
    return sort @list;
}
sub list_available_plugins
{
    my @list;

    my $dir = $Bot_Config::plugin_folder;
    opendir(DIR, $dir) or die "can't open dir $dir: $!";
    while (defined (my $file = readdir(DIR))) {
        if ($file =~ /(.*)\.pm/) {
            push (@list, $1);
        }
    }
    closedir(DIR);

    return sort @list;
}

sub load_plugins
{
    # try to load all files in the plugins folder
    push (@INC, $Bot_Config::plugin_folder);

    my $dirname = $Bot_Config::plugin_folder;

    opendir(DIR, $dirname) or die "can't open dir $dirname: $!";
    while (defined (my $file = readdir(DIR))) {
        load_plugin_file ("$dirname$file");
    }
    closedir(DIR);

    push (@cmd_list, "cmds");
    push (@cmd_list, "help");

    push (@admin_cmd_list, "admin_cmds");

    @cmd_list = sort (@cmd_list);
    @undoc_cmd_list = sort (@undoc_cmd_list);
    @admin_cmd_list = sort (@admin_cmd_list);
}

sub unload_plugins
{
    $plugin_lock->down();
    for my $plugin (values %{$plugins})
    {
        $plugin->unload();
    }
    %{$plugins} = ();
    $plugin_lock->up();
}

sub load_plugin
{
    my ($name) = @_;
    say "We shall load $name!";
    my $file = resolve_plugin_name ($name);

    if ($file) {
        load_plugin_file ($file);
    }
    else {
        say "$name isn't a plugin.";
    }
}
sub load_plugin_file
{
    my ($file) = @_;

    if ($file =~ /\/([^\/]*)\.pm$/) {
        my $name = $1;
        if (!defined ($plugins->{$file})) {
            say "Requering $file";
            require $file;

            if ($name->can('new')) {
                my $plugin = $name->new();
                if ($plugin->DOES('Plugin')) {
                    say "Loading $file";

                    $plugin_lock->down();

                    $plugins->{$file} = share($plugin);
                    $plugin->load();

                    my @cmds = $plugin->cmds();
                    for my $cmd (@cmds) {
                        if ($cmd) {
                            push (@cmd_list, $cmd);
                        }
                    }

                    my @undoc_cmds = $plugin->undocumented_cmds();
                    for my $cmd (@undoc_cmds) {
                        if ($cmd) {
                            push (@undoc_cmd_list, $cmd);
                        }
                    }

                    my @admin_cmds = $plugin->admin_cmds();
                    for my $cmd (@admin_cmds) {
                        if ($cmd) {
                            push (@admin_cmd_list, $cmd);
                        }
                    }
                    $plugin_lock->up();
                }
                else {
                    Log::error("$file doesn't do the Plugin role!");
                }
            }
            else {
                say "$name doesn't do new!";
            }
        }
        else {
            say "$file is already loaded.";
        }
    }
}
sub unload_plugin
{
    my ($name) = @_;
    my $file = resolve_plugin_name ($name);

    if (defined ($plugins->{$file})) {
        say "Unloading $file";

        my $plugin = $plugins->{$file};

        my @cmds = $plugin->cmds();
        #$plugin_lock->down();
        @cmd_list = remove_matches(\@cmd_list, \@cmds);
        say join (", ", @cmd_list);
        #$plugin_lock->up();

        $plugin->unload();
        delete $plugins->{$file};
    }
}

sub remove_matches
{
    my ($origin, $remove) = @_;
    say join (", ", @{$origin});
    say join (", ", @{$remove});

    my %seen;
    for (@{$origin}) {
        $seen{$_} = 1;
    }

    for (@{$remove}) {
        delete $seen{$_};
    }
    say join (", ", keys %seen);

    return keys %seen;
}

sub reload_plugin
{

}

sub stdin_listener
{
    while(<STDIN>) {
        chomp $_;
        if (/^\./) {
            # We've recieved a command, it will be parsed in the $in_queue.
            $in_queue->enqueue($_);
        }
        elsif (/^<\s*(.*)/) {
            # Act like we recieve it from the socket
            $in_queue->enqueue("$1\r\n");
        }
        else {
            # If it's not something special we just pipe it to the server
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
    my ($sock) = @_;
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

sub out_redirect
{
    while(my $msg = $out_queue->dequeue()) {
        chomp $msg;
        Log::sent($msg);
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

sub recieve_msg
{
    Log::recieved @_;
}

sub parse_recieved
{
    my ($msg) = @_;

    $plugin_lock->down();
    for my $plugin (values %{$plugins})
    {
        $plugin->process_bare_msg ($msg);
    }
    $plugin_lock->up();

    if ($msg =~ $match_irc_msg) {
        my $prefix;
        if (!defined ($1)) {
            $prefix = "";
        }
        else {
            $prefix = "$1";
        }
        my $code = $2;
        my $param = $3;

        process_irc_msg($prefix, $code, $param);
    }
    else {
        Log::error("Peculiar, we couldn't capture the message: ", $msg);
    }
}

sub parse_pre_login_recieved
{
    my ($input) = @_;

    if ($input =~ $match_irc_msg) {
        my $prefix;
        if (!defined ($1)) {
            $prefix = "";
        }
        else {
            $prefix = "$1";
        }
        my $code = $2;
        my $param = $3;

        # Check the numerical responses from the server.
        if ($code =~ /004/) {
            # We managed to login, yay!
            $has_connected = 1;

            # Actually load all plugins.
            load_plugins();

            # We are now logged in, so join.
            for my $channel (@Bot_Config::channels) {
                irc_join $channel;
            }

            # Register our nick if we're on quakenet
            if ($Bot_Config::server =~ /quakenet/) {
                open my $fh, '<', "Q-pass";
                my $pass = <$fh>;
                chomp $pass;
                send_privmsg
                    'Q@CServe.quakenet.org',
                    "AUTH $Bot_Config::nick $pass";
            }
        }
        # Nickname in use
        elsif ($code =~ /433/) {
            # Instead of death try to force use of some random nickname.
            my $rand_int = int(rand(100));
            send_msg "NICK $Bot_Config::nick$rand_int";
        }
    }
    else {
        Log::error("Peculiar, we couldn't capture the message: ", $input);
    }
}

sub process_irc_msg
{
    my ($prefix, $irc_cmd, $param) = @_;

    $plugin_lock->down();
    for my $plugin (values %{$plugins})
    {
        $plugin->process_irc_msg ($prefix, $irc_cmd, $param);
    }
    $plugin_lock->up();

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
    elsif ($irc_cmd =~ /QUIT|PART/) {
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

        if ($nick eq $Bot_Config::nick) { return };

        # If we have an entry of this fellaw, undef it so we must check it again
        if (exists($authed_nicks{$nick})) {
            $authed_nicks{$nick} = undef;
        }

        # Worker thread so we don't hang up when waiting for end of whois response
        #my $thr = threads->create (\&is_admin, $nick);
        #$thr->detach();
    }
    elsif ($irc_cmd =~ /NICK/) {
        $prefix =~ /^(.+?)!~/;
        my $old_nick = $1;

        $param =~ /^:(.*)/;
        my $new_nick = $1;

        if ($old_nick eq $Bot_Config::nick) { return };

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
            my $arg = $2;

            create_cmd_worker (\&process_cmd, $sender, $target, $cmd, $arg);
        }
        else {
            $plugin_lock->down();
            for my $plugin (values %{$plugins})
            {
                $plugin->process_privmsg ($sender, $target, $msg);
            }
            $plugin_lock->up();
        }
    }
}

sub process_cmd
{
    my ($sender, $target, $cmd, $arg) = @_;

    if ($cmd eq "help") {
        if ($arg =~ /^\s*$/) {
            Irc::send_privmsg ($target, $Bot_Config::help_msg);
        }
        else {
            my $help_sent = 0;
            $plugin_lock->down();
            for my $plugin (values %{$plugins})
            {
                my $help = $plugin->cmd_help ($arg);
                if (defined ($help) && length ($help)) {
                    Irc::send_privmsg ($target, $help);
                    $help_sent = 1;
                }
            }
            $plugin_lock->up();

            if (!$help_sent) {
                Irc::send_privmsg ($target, $Bot_Config::help_missing);
            }
        }
    }
    elsif ($cmd =~ /^cmds|commands$/) {
        my $msg = "Documented commands: " . join(", ", @cmd_list);
        Irc::send_privmsg ($target, $msg);
    }
    elsif ($cmd =~ /undocumented_?cmds/) {
        my $msg = "Undocumented commands: " . join(", ", @undoc_cmd_list);
        Irc::send_privmsg ($target, $msg);
    }
    elsif ($cmd eq "recheck") {
        $authed_nicks{$sender} = undef;
        is_authed $sender;
    }
    else {
        $plugin_lock->down();
        for my $plugin (values %{$plugins})
        {
            $plugin->process_cmd ($sender, $target, $cmd, $arg);
        }
        $plugin_lock->up();
    }

    if (is_admin($sender)) {
        process_admin_cmd ($sender, $target, $cmd, $arg);
    }
}

sub process_admin_cmd
{
    my ($sender, $target, $cmd, $arg) = @_;

    if ($cmd eq "quit") {
        main::quit ($arg);
    }
    elsif ($cmd =~ /^admin_?cmds$/) {
        my $msg = "Admin commands: " . join(", ", @admin_cmd_list);
        send_privmsg ($target, $msg);
    }
    elsif ($cmd eq "load") {
        load_plugin ($arg);
    }
    elsif ($cmd eq "unload") {
        unload_plugin ($arg);
    }
    elsif ($cmd eq "loaded") {
        my @plugins = list_loaded_plugins;
        my $list = join (", ", @plugins);
        send_privmsg $target, $list;
    }
    elsif ($cmd eq "available") {
        my @plugins = list_available_plugins;
        my $list = join (", ", @plugins);
        send_privmsg $target, $list;
    }
    else {
        $plugin_lock->down();
        for my $plugin (values %{$plugins})
        {
            $plugin->process_admin_cmd ($sender, $target, $cmd, $arg);
        }
        $plugin_lock->up();
    }
}

sub start
{
    # If we shall connect with the socket. Used for testing from stdin only
    my ($test_mode) = @_;

    if (!$test_mode) {
        my $attempt = 0;
        while (!$sock) {
            # Connect to the IRC server.
            $sock = new IO::Socket::INET(PeerAddr => $Bot_Config::server,
                                        PeerPort => $Bot_Config::port,
                                        Proto => 'tcp');
            ++$attempt;
            if (!$sock) {
                say "Attempt $attempt failed..";
            }

            if ($attempt > 4) {
                die "Couldn't connect, aborting.";
            }
        }

        # Now the socket is ready for usage.
        $sock_lock->up(2);

        # Log on to the server.
        send_msg "NICK $Bot_Config::nick";
        send_msg "USER $Bot_Config::username 0 * :$Bot_Config::realname";

        # Worker thread so we can handle both socket input
        # and stdin input through queues.
        my $sock_listener = threads->create(\&sock_listener, $sock);

        # Worker who outputs everything from the $out_queue to the socket
        # so we can write to socket from other threads
        my $sock_writer = threads->create(\&socket_writer, $sock);
    }
    else {
        # Worker who outputs everything from the $out_queue to a log
        my $out_redirect = threads->create(\&out_redirect);

        # We have "connected"
        $has_connected = 1;
        load_plugins();
    }

    # Worker thread for listening and parsing stdin cmds
    my $stdin_listener = threads->create(\&stdin_listener);

    while (my $input = $in_queue->dequeue()) {
        chomp $input;

        if ($input =~ /^\\(.*)/) {
            $input = $1;
        }
        elsif ($input =~ $match_cmd) {
            # We've recieved an internal command
            my $cmd = $1;
            my $arg = $2;

            # For now only allow a quit command before connection
            if ($cmd eq "quit") {
                main::quit ($arg);
            }
            # Prevent segfaulting if we're trying to dispatch a command
            # before we've connected and loaded our plugins
            elsif ($has_connected) {
                # Empty sender and target means the command is internal
                create_cmd_worker(\&process_cmd, "", "", $cmd, $arg);
            }
            next;
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
    my ($msg) = @_;
    if (defined ($msg) && $msg !~ /\s*/) {
        send_msg "QUIT :$msg";
    }
    else {
        send_msg "QUIT :$Bot_Config::quit_msg";
    }
}

sub irc_join
{
    for (@_) {
        send_msg "JOIN $_";
    }
}
sub irc_part
{
    my ($channel, $reason) = @_;

    if (defined ($reason) && $reason !~ /\s*/) {
        send_msg "PART $channel :$reason";
    }
    else {
        send_msg "PART $channel";
    }
}
sub irc_kick
{

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
            $whois_sent = 1;
            sleep 1;
        }
        else {
            sleep 1;
        }
    }
}
sub authed_as
{
    my ($nick) = @_;
    return $authed_nicks{$nick};
}

sub is_admin
{
    my ($nick) = @_;

    # If sent from stdin
    if ($nick eq "") { return 1; }

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

