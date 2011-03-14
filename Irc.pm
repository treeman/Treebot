#!/usr/bin/perl -w

package Irc;

use Modern::Perl;

use threads;
use threads::shared;
use Thread::Semaphore;

use MooseX::Declare;
use IO::Socket;
use Carp;
use Test::More;

use Plugin;
use Log;
use Conf;
use Util;
use Tests;

# Create a worker thread and store it in workers
sub create_cmd_worker;

# Thread for listening to stdin and dispatching cmds and stuff
sub stdin_listener;

# Locking down the socket for operations
sub read_sock;
# Our sock listening, should start in it's own thread
sub sock_listener;

# Place message in in_queue
sub push_in;
# Place message in out_queue
sub push_out;

# Sends all messages in out_queue for writing, should be a thread
sub socket_writer;
# Lock down socket and write
sub output_to_sock;
# Log everything from out_queue
sub log_out;
# Redirect from out_queue to Tests::out
sub test_out;

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

# When we get connection confirmed by server we'll set stuff here
sub connection_successful;

# Init the irc connection
sub init;
# Parse events
sub start;
# Will get called when we quit, either by SIGINT or regular quit
sub quit;

# Irc helper functions
sub irc_join;
sub irc_part;
sub irc_kick;

# Helper function to lockdown shared bool
sub has_connected;

# Cannot run in the same thread as a listener, will sleep
sub is_authed;
sub authed_as;
sub is_admin;

# List commands
sub cmds;
sub undoc_cmds;
sub admin_cmds;

# Pull from our origin to update source files and either restart or reload plugins
sub update_src;

# Run tests and exit
sub run_tests;
# Test stuff private to this file
sub run_pre_login_tests;
sub run_post_login_tests;

my $sock;
my $sock_lock = Thread::Semaphore->new(2);

my $has_connected :shared = 0;

my %authed_nicks :shared;
my $nick_lock = Thread::Semaphore->new();

my $in_queue = Thread::Queue->new();
my $out_queue = Thread::Queue->new();

# Command-line flags
my $dry :shared;
my $test :shared;
my $run_tests :shared;

# Commands we can't implement in plugins
my @core_cmds = ('cmds',
                 'help');
my @core_undoc_cmds = ();
my @core_admin_cmds = ('admin_cmds',
                       'available',
                       'load',
                       'load_all',
                       'loaded',
                       'quit',
                       'reload',
                       'reload_all',
                       'restart',
                       'unload',
                       'unload_all',
                       'update',
                      );

# Worker threads dispatched for commands
# Probably should be removed when they're done?
# Dunno what it really does? It does nothing
# But it might become useful if we want to catch runaway threads
# However that would need a different approach where we watch
# runtime and memory usage. How would one go about doing that?
my @workers;

# Regex parsing of useful stuff
my $match_ping = qr/^PING\s(.*)$/i;

my $match_cmd =
    qr/
        ^\Q$Conf::cmd_prefix\E  # cmd prefix
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
        (.+?)           # (3) parameters
        \r?             # irc standard includes carriage return which we don't want
        $
    /x;

## Implementation

sub create_cmd_worker
{
    my $f = shift;
    my $thr = threads->create($f, @_);
    push (@workers, $thr);
}
sub stdin_listener
{
    while(<STDIN>) {
        chomp $_;
        if (/^\./) {
            # We've recieved a command, it will be parsed in the $in_queue.
            push_in ($_);
        }
        elsif (/^<\s*(.*)/) {
            # Act like we recieve it from the socket
            push_in ("$1\r\n");
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
        if ($input =~ /^\Q$Conf::cmd_prefix\E/) {
            $input = "\\$input";
        }
        push_in ($input);
    }
}

sub push_in
{
    for (@_) {
        $in_queue->enqueue ($_);
    }
}

sub push_out
{
    for (@_) {
        $out_queue->enqueue ($_);
    }
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
            Log::sent ($msg);
        $sock_lock->up();
    }
    else {
        Log::error "Trying to write to sock but it's closed: ", $msg;
    }
}

sub log_out
{
    while(my $msg = $out_queue->dequeue()) {
        chomp $msg;
        Log::sent ($msg);
    }
}

sub test_out
{
    while(my $msg = $out_queue->dequeue()) {
        chomp $msg;
        Tests::out ($msg);
    }
}

sub send_msg
{
    my $msg = join("", @_);

    if (length ($msg) > 0 ) {
        push_out ($msg);
    }
    else {
        Log::error "trying to send an empty message.";
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
        send_msg "PRIVMSG $target :$msg";
    }
}

sub recieve_msg
{
    Log::recieved @_;
}

sub parse_recieved
{
    my ($msg) = @_;

    Plugin::process_bare_msg ($msg);

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
            connection_successful();
        }
        # Nickname in use
        elsif ($code =~ /433/) {
            # Instead of death try to force use of some random nickname.
            my $rand_int = int(rand(100));
            send_msg "NICK $Conf::nick$rand_int";
        }
    }
    else {
        Log::error("Peculiar, we couldn't capture the message: ", $input);
    }
}

sub process_irc_msg
{
    my ($prefix, $irc_cmd, $param) = @_;

    Plugin::process_irc_msg ($prefix, $irc_cmd, $param);

    if ($irc_cmd =~ /PRIVMSG/) {
        process_privmsg ($prefix, $irc_cmd, $param);
    }
    # Nick is authed
    elsif ($irc_cmd =~ /330/) {
        $param =~ /^\S+\s+(\S+)\s+(\S+)/;
        my $nick = $1;
        my $authed_nick = $2;

        $nick_lock->down();

        $authed_nicks{$nick} = $authed_nick;
        $nick_lock->up();
    }
    # End of whois
    elsif ($irc_cmd =~ /318/) {
        $param =~ /^\S+\s+(\S+)/;
        my $nick = $1;

        $nick_lock->down();

        # If no entry, he isn't authed
        if (!defined($authed_nicks{$nick})) {
            $authed_nicks{$nick} = 0;
        }
        $nick_lock->up();
    }
    elsif ($irc_cmd =~ /QUIT|PART/) {
        $prefix =~ /^(.+?)!~/;
        my $nick = $1;

        $nick_lock->down();

        # If entry exists, set it to 0
        if (exists($authed_nicks{$nick})) {
            $authed_nicks{$nick} = 0;
        }
        $nick_lock->up();
    }
    elsif ($irc_cmd =~ /JOIN/) {
        $prefix =~ /^(.+?)!~/;
        my $nick = $1;

        if ($nick eq $Conf::nick) { return };

        $nick_lock->down();

        # If we have an entry of this fellaw, undef it so we must check it again
        if (exists($authed_nicks{$nick})) {
            $authed_nicks{$nick} = undef;
        }
        $nick_lock->up();
    }
    elsif ($irc_cmd =~ /NICK/) {
        $prefix =~ /^(.+?)!~/;
        my $old_nick = $1;

        $param =~ /^:(.*)/;
        my $new_nick = $1;

        if ($old_nick eq $Conf::nick) { return };

        $nick_lock->down();

        if (exists($authed_nicks{$old_nick})) {
            $authed_nicks{$new_nick} = $authed_nicks{$old_nick};
            $authed_nicks{$old_nick} = undef;
        }
        $nick_lock->up();
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
        if ($target =~ /$Conf::nick/) {
            $target = $sender;
        }

        if ($msg =~ $match_cmd) {
            my $cmd = $1;
            my $arg = $2;

            create_cmd_worker (\&process_cmd, $sender, $target, $cmd, $arg);
        }
        else {
            Plugin::process_privmsg ($sender, $target, $msg);
        }
    }
}

sub process_cmd
{
    my ($sender, $target, $cmd, $arg) = @_;

    if ($cmd eq "help") {
        if ($arg =~ /^\s*$/) {
            Irc::send_privmsg ($target, $Conf::help_msg);
        }
        else {
            my $help_sent = 0;

            my @help = Plugin::get_cmd_help ($arg);
            for (@help) {
                Irc::send_privmsg ($target, $_);
                $help_sent = 1;
            }

            if (!$help_sent) {
                Irc::send_privmsg ($target, $Conf::help_missing);
            }
        }
    }
    elsif ($cmd =~ /^cmds|commands$/) {
        my $msg = "Documented commands: " . join(", ", cmds());
        Irc::send_privmsg ($target, $msg);
    }
    elsif ($cmd =~ /undocumented_?cmds|undoc/) {
        my $msg = "Undocumented commands: " . join(", ", undoc_cmds());
        Irc::send_privmsg ($target, $msg);
    }
    elsif ($cmd eq "recheck") {
        $nick_lock->down();

        $authed_nicks{$sender} = undef;
        $nick_lock->up();

        is_authed $sender;
    }
    else {
        Plugin::process_cmd ($sender, $target, $cmd, $arg);
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
    elsif ($cmd eq "restart") {
        main::restart ();
    }
    elsif ($cmd =~ /^admin_?cmds$/) {
        my $msg = "Admin commands: " . join(", ", admin_cmds());
        send_privmsg ($target, $msg);
    }
    elsif ($cmd eq "update") {
        update_src ($target);
    }
    elsif ($cmd eq "load") {
        my @list = split (/ /, $arg);
        for my $plugin (@list) {
            my $msg = Plugin::load ($plugin);
            send_privmsg ($target, $msg);
        }
    }
    elsif ($cmd eq "unload") {
        my @list = split (/ /, $arg);
        for my $plugin (@list) {
            my $msg = Plugin::unload ($plugin);
            send_privmsg ($target, $msg);
        }
    }
    elsif ($cmd eq "load_all") {
        Plugin::load_all();
        send_privmsg ($target, "Loading all not loaded.");
    }
    elsif ($cmd eq "reload_all") {
        Plugin::reload_all();
        send_privmsg ($target, "Reloading all.");
    }
    elsif ($cmd eq "unload_all") {
        Plugin::unload_all();
        send_privmsg ($target, "Unloading all.");
    }
    elsif ($cmd eq "reload") {
        my @list = split (/ /, $arg);

        for my $plugin (@list) {
            my $msg = Plugin::reload ($plugin);
            send_privmsg ($target, $msg);
        }
    }
    elsif ($cmd eq "loaded") {
        my @plugins = Plugin::loaded();
        my $list = join (", ", @plugins);
        send_privmsg ($target, $list);
    }
    elsif ($cmd eq "available") {
        my @plugins = Plugin::available();
        my $list = join (", ", @plugins);
        send_privmsg ($target, $list);
    }
    else {
        Plugin::process_admin_cmd ($sender, $target, $cmd, $arg);
    }
}

sub connection_successful
{
    # We managed to login, yay!
    has_connected(1);

    Plugin::load_all();

    if (!$test) {
        # We are now logged in, so join.
        irc_join @Conf::channels;

        # Register our nick if we're on quakenet
        if ($Conf::server =~ /quakenet/) {
            if (-r "Q-pass") {
                open my $fh, '<', "Q-pass";
                my $pass = <$fh>;
                chomp $pass;
                send_privmsg
                    'Q@CServe.quakenet.org',
                    "AUTH $Conf::nick $pass";
            }
            else {
                Log::error ("No Q-pass file found.");
            }
        }
    }

    if($run_tests) {
        run_post_login_tests();
    }
}

sub init
{
    ($dry, $test, $run_tests) = @_;

    if ($dry) {
        # Pretend to log on to the server
        send_msg "NICK $Conf::nick";
        send_msg "USER $Conf::username 0 * :$Conf::realname";

        if ($run_tests) {
            # Worker who outputs everything from the out_queue to a testing function
            my $test_out = threads->create(\&Tests::out);
        }
        else {
            # Worker who outputs everything from the out_queue to a log
            my $log_out = threads->create(\&log_out);
        }
    }
    elsif ($test) {
        if ($run_tests) {
            # Worker who outputs everything from the out_queue to a testing function
            my $test_out = threads->create(\&Tests::out);
        }
        else {
            # Worker who outputs everything from the out_queue to a log
            my $log_out = threads->create(\&log_out);
        }

        # We have "connected"
        connection_successful;
    }
    else {
        my $attempt = 0;
        while (!$sock) {
            # Connect to the IRC server
            $sock = new IO::Socket::INET(PeerAddr => $Conf::server,
                                         PeerPort => $Conf::port,
                                         Proto => 'tcp');
            ++$attempt;
            if (!$sock) {
                Log::error "Attempt $attempt failed..";
            }

            if ($attempt > 4) {
                croak "Couldn't connect, aborting.";
            }
        }

        # Now the socket is ready for usage.
        $sock_lock->up(2);

        # Log on to the server.
        send_msg "NICK $Conf::nick";
        send_msg "USER $Conf::username 0 * :$Conf::realname";

        # Worker thread so we can handle both socket input
        # and stdin input through queues.
        my $sock_listener = threads->create(\&sock_listener, $sock);

        # Worker who outputs everything from the $out_queue to the socket
        # so we can write to socket from other threads
        my $sock_writer = threads->create(\&socket_writer, $sock);
    }

    # Worker thread for listening and parsing stdin cmds
    my $stdin_listener = threads->create(\&stdin_listener);
}

sub start
{
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
            #elsif ($has_connected) {
            elsif (has_connected()) {
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

        if (has_connected()) {
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

    if ($msg) {
        send_msg "QUIT :$msg";
    }
    else {
        send_msg "QUIT :$Conf::quit_msg";
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

    if ($reason) {
        send_msg "PART $channel :$reason";
    }
    else {
        send_msg "PART $channel";
    }
}
sub irc_kick
{

}

sub has_connected
{
    my ($new_val) = @_;

    if (defined ($new_val)) {
        lock($has_connected);
        $has_connected = $new_val;
    }
    return $has_connected;
}

sub is_authed
{
    my ($nick) = @_;
    my $whois_sent = 0;

    while (1) {
        my $defined;

        $nick_lock->down();
        $defined = defined ($authed_nicks{$nick});
        $nick_lock->up();

        if ($defined) {
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

    $nick_lock->down();
    my $auth = $authed_nicks{$nick};
    $nick_lock->up();

    return $auth;
}

sub is_admin
{
    my ($nick) = @_;

    # If sent from stdin
    if ($nick eq "") { return 1; }

    if (is_authed ($nick)) {
        $nick_lock->down();

        my $authed_nick = $authed_nicks{$nick};
        for my $admin (@Conf::admins) {
            if ($admin eq $authed_nick) {
                $nick_lock->up();
                return 1;
            }
        }
        $nick_lock->up();
    }
    return 0;
}

sub cmds
{
    my %cmds = Plugin::cmds();
    for (@core_cmds) {
        $cmds{$_} = 1;
    }
    return sort keys %cmds;
}
sub undoc_cmds
{
    my %cmds = Plugin::undoc_cmds();
    for (@core_undoc_cmds) {
        $cmds{$_} = 1;
    }
    return sort keys %cmds;
}
sub admin_cmds
{
    my %cmds = Plugin::admin_cmds();
    for (@core_admin_cmds) {
        $cmds{$_} = 1;
    }
    return sort keys %cmds;
}

sub update_src
{
    my ($target) = @_;

    # Need to set in config instead
    my $remote = "origin";
    # This too ;)
    my $branch = "master";

    my $response = `git pull $remote $branch`;

    say $response;

    update_from_git_pull ($response, $target);
}

sub update_from_git_pull
{
    my ($response, $target) = @_;

    if ($response =~ /Already up-to-date\./) {
        send_privmsg ($target, "Already up to date.");
    }
    else {
        my @lines = split(/\r\n|\r|\n/, $response);

        # Skip to files changed
        while (defined (my $line = shift @lines)) {
            if ($line =~ /fast.forward/i) {
                last;
            }
        }

        my @files_changed;

        while (defined (my $line = shift @lines)) {
            if ($line =~ /(\S+)\s+\|/) {
                push (@files_changed, $1);
            }
            else {
                last;
            }
        }

        my $msg =  "Files changed: " . join (", ", @files_changed);
        send_privmsg ($target, $msg);

#        my $total_restart = 0;
#        my $reload_all = 0;
        my $mostly_harmless = 1;

#        my @plugins_affected;
#        my @subfolders;

#        my $pf = $Conf::plugin_folder;
        my %harmless = %Conf::ignore_on_update;

        for (@files_changed) {
            if ($harmless{$_}) {
                next;
            }
#            elsif (!/^$pf/) {
            else {
#                $total_restart = 1;
                $mostly_harmless = 0;
                last;
            }
#            elsif (/^$pf([^\/]+)\.pm$/) {
#                push (@plugins_affected, $1);
#            }
#            elsif (/^$pf([^\/]+)\/.+/) {
#                push (@subfolders, $1);
#            }
#            else {
#                # Random file in plugin directory
#                $reload_all = 1;
#            }
        }

#        if ($total_restart) {
        if (!$mostly_harmless) {
#            send_privmsg ($target, "We need a total restart here.");
            send_privmsg ($target, "We're looking like Windows updating here, brb.");
            if (!$run_tests) {
                say "Restart needed!";
                main::restart();
            }
#            return;
        }

#        if ($reload_all) {
#            send_privmsg ($target, "We need to reload all plugins.");
#            if (!$run_tests) {
#                Plugin::reload_all();
#            }
#            return;
#        }
#
#        if (scalar @subfolders) {
#            my @plugins = Plugin::available();
#
#            for my $sub (@subfolders) {
#                my $match_found = 0;
#                for my $p (@plugins) {
#                    if ($sub =~ /\E$p\Q/i) {
#                        push (@plugins_affected, $p);
#                        $match_found = 1;
#                    }
#                }
#
#                if (!$match_found) {
#                    send_privmsg ($target, "We need to reload all plugins.");
#                    if (!$run_tests) {
#                        Plugin::reload_all();
#                    }
#                    return;
#                }
#            }
#        }
#
#        for (@plugins_affected) {
#            if (!$run_tests) {
#                my $msg = Plugin::reload ($_);
#                send_privmsg ($target, $msg);
#            }
#            else {
#                send_privmsg ($target, "Reloading '$_'");
#            }
#        }
    }
}

sub run_tests
{
    # We want it to behave as normal, but without redirecting the output
    # so we can parse out_queue in our testing function ourselves
    my ($dry, $test, $run_tests) = (1, 1, 1);

    # Redirect output to a testing function
    threads->create(\&test_out);

    init ($dry, $test, $run_tests);

    run_pre_login_tests();

    # Tests thread
    threads->create(\&Tests::run_tests);

    # Start our parsing
    start;
}

sub run_pre_login_tests
{
    # Run plugin tests in main thread
    if ($run_tests) {
        Plugin::run_tests();
    }

    like(".cmd", $match_cmd, "simple command");
    like(".cmd arg", $match_cmd, "arg command");
    like(".cmd arg1 arg2", $match_cmd, "args command");
    unlike("cmd", $match_cmd, "bare command");

    like(":ser12_232:d2 CODEZ0R #pe arg1 arg2 :last", $match_irc_msg, "irc msg args");
    like(":server IPP treebot :l", $match_irc_msg, "simple");
    like("PING :pew", $match_irc_msg, "ping");
    like("NOTICE banener :äter oss", $match_irc_msg, "notice");
    unlike("err", $match_irc_msg, "juse one thingie");

    like("PING :pew", $match_ping, "match ping");
}

sub run_post_login_tests
{
    test_update_src();
}

sub test_update_src
{
    my @tests = (
        "Fast-forward
        plugin/Insults/Admin.pm |  183 -----------------------------------------------
        plugin/Admin.pm |  183 ---------------------------------------------------
        plugin/Down.pm |  183 ---------------------------------------------------
        readme | pew
        ideas | ladida
        3 files changed, 108 insertions(+), 206 deletions(-)
        delete mode 100644 test_cube_match.adb",

        "Fast-forward
        plugin/bajs/crap |  183 ---------------------------------------------------
        plugin/Admin.pm |  183 ---------------------------------------------------
        plugin/Down.pm |  183 ---------------------------------------------------
        3 files changed, 108 insertions(+), 206 deletions(-)
        delete mode 100644 test_cube_match.adb",

        "Fast-forward
        plugin/Insults/Admin.pm |  183 -----------------------------------------------
        plugin/Admin.pm |  183 ---------------------------------------------------
        core |  183 ---------------------------------------------------
        3 files changed, 108 insertions(+), 206 deletions(-)
        delete mode 100644 test_cube_match.adb",

        "Fast-forward
        plugin/douche |  183 ---------------------------------------------------
        core |  183 ---------------------------------------------------
        3 files changed, 108 insertions(+), 206 deletions(-)
        delete mode 100644 test_cube_match.adb",

        "Fast-forward
        plugin/douche |  183 ---------------------------------------------------
        3 files changed, 108 insertions(+), 206 deletions(-)
        delete mode 100644 test_cube_match.adb",

        "From forest:treebot
        * branch            master     -> FETCH_HEAD
        Already up-to-date.",
    );

    for (@tests) {
        update_from_git_pull ($_, "");
    }
}

1;

