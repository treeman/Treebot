#!/usr/bin/perl -w

use utf8;
use locale;

package Irc;

use Modern::Perl;

use threads;
use threads::shared;
use Thread::Semaphore;
use Thread::Queue;

use IO::Socket;
use Carp;
use Test::More;

use Log;
use Conf;
use Msgs;

# Thread safe queues for writing to our socket and reading from it
my $in_queue = Thread::Queue->new();
my $out_queue = Thread::Queue->new();

# Handles input output in a multithreaded fashion
sub push_in { map { $in_queue->enqueue ($_); } @_; }
sub push_out { map { $out_queue->enqueue ($_); } @_; }

my $sock;
my $sock_lock = Thread::Semaphore->new(2);

# Our current name
my $botnick;

# Commands visible in listings
my @cmds = qw(cmds help);
my @undoc_cmds = qw(undoc);
my @admin_cmds = qw(admin_cmds
                    kick
                    msg
                    op
                    out
                    quit
                    recheck
                    is_admin
                    topic);

# Who are auth?
my %authed_nicks;

# Am I op in what channels?
my %my_op_channels;

# Read the socket in a thread safe manner
sub read_socket
{
    my $sock = shift;

    if (defined ($sock)) {
        $sock_lock->down();
            my $input = <$sock>;
        $sock_lock->up();
        return $input;
    }
    else {
        Log::error ("Trying to read sock but it's cloased.");
        return 0;
    }
}

# Launch this in a new thread and it will push all input from the socket to our in queue
sub socket_listener
{
    my ($sock) = @_;

    while (my $input = read_socket ($sock)) {
        push_in ($input);
    }
}

# Launch in a new thread and it will write everything from out queue to the socket
sub socket_writer
{
    my $sock = shift;

    while (my $msg = $out_queue->dequeue()) {
        chomp $msg;

        if (defined ($sock)) {
            $sock_lock->down();
                print $sock "$msg\r\n";
                Log::sent ($msg);
            $sock_lock->up();
        }
        else {
            Log::error ("Trying to write to sock but it's closed: ", $msg);
        }
    }
}

# Launch in a new thread and it will log everything from the out queue
sub log_out
{
    while (my $msg = $out_queue->dequeue()) {
        chomp $msg;
        Log::sent ($msg);
    }
}

# Flag is set when we're connected and we can recieve commands
my $has_connected = 0;

# Setup and connect to irc
sub init
{
    my ($dry, $test) = @_;

    # Setup available commands
    my %available;

    # Remove duplicates and sort commands
    %available = Plugin::cmds();
    map { $available{$_} = 1; } @cmds;
    @cmds = sort keys %available;

    %available = Plugin::undoc_cmds();
    map { $available{$_} = 1; } @undoc_cmds;
    @undoc_cmds = sort keys %available;

    %available = Plugin::admin_cmds();
    map { $available{$_} = 1; } @admin_cmds;
    @admin_cmds = sort keys %available;

    # Pretend to log in to the server, but don't
    # Still wait for commands from the in queue
    if ($dry) {
        Log::exe ("Dry connecting to irc");

        # Register user and nickname and login to server
        irc_nick ($Conf::nick);
        output ("USER $Conf::username 0 * :$Conf::realname");

        # Worker thread who logs everything in $out_queue
        my $out_logger = threads->create(\&log_out);
    }
    # Run in test mode, don't care about things as logging in and such
    # So we can test commands from the command line
    elsif ($test) {
        Log::exe ("Irc is in test mode");

        $has_connected = 1;

        # Worker thread who logs everything in $out_queue
        my $out_logger = threads->create(\&log_out);
    }
    else {
        Log::exe ("Connecting to irc");

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
                Log::error "Couldn't connect, aborting.";
            }
        }

        # Now we can use the socket
        $sock_lock->up(2);

        # Register user and nickname and login to server
        irc_nick ($Conf::nick);
        output ("USER $Conf::username 0 * :$Conf::realname");

        # Worker thread to listen to socket input and place it in $in_queue
        my $socket_listener = threads->create(\&socket_listener, $sock);

        # Worker thread who output everything in $out_queue to socket
        my $socket_writer = threads->create(\&socket_writer, $sock);
    }
}

# Flag to end loop
my $has_quit = 0;

# Startup irc
# Will run until we get called quits
sub start
{
    my ($dry, $test) = @_;

    # Setup and connect to irc
    init ($dry, $test);

    # Parse input
    while (my $input = $in_queue->dequeue())
    {
        # Handle command from commandline, don't log it
        if ($input =~ /^\Q$Conf::cmd_prefix\E(\S+)\s*(.*)/) {
            my ($cmd, $rest) = ($1, $2);

            # Only allow quit before we're connected for now
            if ($cmd eq "quit") {
                quit ($rest);
                last;
            }

            # If we're all setup check other commands
            if ($has_connected) {
                process_cmd ("", "", $cmd, $rest);
            }
            next;
        }

        Log::recieved ($input);

        # Handle ping
        if ($input =~ /^PING\s(.*)$/i) {
            output ("PONG $1");
            next;
        }

        my ($prefix, $cmd, $param) = split_irc_msg ($input);

        Log::debug ("Irc: $prefix $cmd $param");

        # Login successful
        if ($cmd =~ /004/) {
            output ("JOIN #madeoftree");
            $has_connected = 1;
        }
        # Nickname in use
        elsif ($cmd =~ /433/) {
            # Try one of our backup nicknames
            if (scalar @Conf::nick_reserves) {
                irc_nick (shift @Conf::nick_reserves);
            }
            # Instead of lying down and die try a variation
            else {
                irc_nick ($Conf::nick . int(rand(100)));
            }
        }

        # Handle more complex tasks only after we're connected
        process_post_login ($prefix, $cmd, $param) if ($has_connected);

        # End loop if we want to quit
        last if ($has_quit);
    }
}

# Handle tasks
sub process_post_login
{
    my ($prefix, $cmd, $param) = @_;

    # Check plugin actions for irc message
    Plugin::process_irc_msg ($prefix, $cmd, $param);

    # Handle privmsg
    if ($cmd =~ /PRIVMSG/) {
        my $nick = (split /!/, $prefix)[0];

        my ($target, $what) = split_privmsg ($param);

        Log::debug ("Privmsg: $nick $target $what");

        Plugin::process_privmsg ($nick, $target, $what);

        # If someone did type help
        if ($what =~ /help.?/i) {
            irc_privmsg ($target, $Msgs::want_help);
        }

        # If we have a command
        if ($what =~ /^\Q$Conf::cmd_prefix\E(\S+)\s*(.*)/) {
            my ($cmd, $rest) = ($1, $2);

            process_cmd ($nick, $target, $cmd, $rest);
        }
    }
    # Nick is auth
    elsif ($cmd eq "330") {
        my ($nick, $authed_nick) = (split /\s+/, $param)[1,2];

        nick_is_auth ($nick, $authed_nick );

        check_op ($nick);
    }
    # End of whois
    elsif ($cmd eq "318") {
        my $nick = (split /\s+/, $param)[1];

        nick_not_auth ($nick);
    }
    # Nick change
    elsif ($cmd eq "NICK") {
        my $old_nick = (split /!/, $prefix)[0];

        $param =~ /^:(.+)/;
        my $new_nick = $1;

        if (my $auth = authed_nick ($old_nick)) {
            nick_is_auth ($new_nick, $auth);
        }
        else {
            nick_not_auth ($new_nick);
        }
        nick_not_auth ($old_nick);
    }
    elsif ($cmd eq "JOIN") {
        my $nick = (split /!/, $prefix)[0];

        nick_not_auth ($nick);

        # Recheck on join
        irc_whois ($nick);
    }
    # User quit channel
    elsif ($cmd =~ /QUIT|PART/) {
        my $nick = (split /!/, $prefix)[0];

        nick_not_auth ($nick);
    }
    # Mode changes for users
    elsif ($cmd eq "MODE") {
        my ($channel, $mode, $nick) = split (/ /, $param);

        # Set where the bot is op
        if ($nick && $nick eq $botnick) {
            if ($mode =~ /\+o/) {
                $my_op_channels{$channel} = 1;
            }
            elsif ($mode =~ /-o/) {
                $my_op_channels{$channel} = 0;
            }
        }
    }
}

sub process_cmd
{
    my ($nick, $target, $cmd, $rest) = @_;

    Log::debug ("cmd recieved: $cmd $rest");

    if ($cmd eq "help") {
        if ($rest eq "") {
            irc_privmsg ($target, $Msgs::help);
        }
        elsif ($rest eq "help") {
            irc_privmsg ($target, $Msgs::help_help);
        }
        else {
            my $help_sent = 0;

            my @help = Plugin::get_cmd_help ($rest);
            for my $msg (@help) {
                irc_privmsg ($target, $msg);
                $help_sent = 1;
            }

            if (!$help_sent) {
                irc_privmsg ($target, $Msgs::help_missing);
            }
        }
    }
    elsif ($cmd =~ /^cmds|commands$/) {
        my $msg = "Documented commads: " . join (", ", @cmds);
        irc_privmsg ($target, $msg);
    }
    elsif ($cmd =~ /^undocumented_?cmds|undoc$/) {
        my $msg = "Documented commads: " . join (", ", @undoc_cmds);
        irc_privmsg ($target, $msg);
    }
    # Command for rechecking admin status
    elsif ($cmd eq "recheck") {
        recheck ($nick);
    }

    Plugin::process_cmd ($nick, $target, $cmd, $rest);

    # Process admin command
    if (is_admin ($nick)) {
        process_admin_cmd ($nick, $target, $cmd, $rest);
    }
}

sub process_admin_cmd
{
    my ($nick, $target, $cmd, $rest) = @_;

    if ($cmd eq "admin_cmds") {
        my $msg = "Admin commads: " . join (", ", @admin_cmds);
        irc_privmsg ($target, $msg);
    }
    elsif ($cmd eq "kick") {
        if ($rest =~ /(\S+)         # Nick
                      \s*
                      ([#&]\S+)?    # Channel
                      \s*
                      (.*)          # Reason
                     /xsi)
        {
            my ($nick, $channel, $reason) = ($1, $2, $3);

            $channel = $target if (!$channel);
            $reason = "" if (!$reason);

            irc_kick ($channel, $nick, $reason);
        }
    }
    elsif ($cmd eq "msg") {
        my @arg = split (/ /, $rest);

        if (scalar @arg == 1) {
            irc_privmsg ($target, $rest);
        }
        else {
            irc_privmsg ($arg[0], $arg[1]);
        }
    }
    elsif ($cmd eq "op") {
        my ($nick, $channel) = split (/ /, $rest);

        $channel = $target if (!$channel);

        irc_op ($channel, $nick);
    }
    elsif ($cmd eq "out") {
        output ($rest);
    }
    elsif ($cmd eq "quit") {
        quit ($rest);
    }
    elsif ($cmd eq "recheck") {
        if ($rest) {
            recheck ($rest);
        }
        else {
            recheck ($nick);
        }
    }
    elsif ($cmd eq "is_admin") {
        $nick = $rest if ($rest);

        if (is_admin ($nick)) {
            irc_privmsg ($target, "$nick is admin");
        }
        else {
            irc_privmsg ($target, "$nick is not admin");
        }
    }
    elsif ($cmd eq "topic") {
        if ($rest =~ /([#&]\S+)?    # Channel
                      \s*
                      (.*)          # Topic
                     /xsi)
        {
            my ($channel, $topic) = ($1, $2);

            $channel = $target if (!$channel);

            irc_topic ($channel, $topic);
        }
    }

    Plugin::process_admin_cmd ($nick, $target, $cmd, $rest);
}

# Send irc specific stuff
sub irc_nick
{
    my ($nick) = @_;
    output ("NICK $nick");
    $botnick = $nick;
}

sub irc_privmsg
{
    my ($target, $what) = @_;

    # If target is empty output should go to the commandline
    if ($target eq "") {
        Log::out ($what);
    }
    else {
        output ("PRIVMSG $target :$what");
    }
}

sub irc_quit
{
    my ($msg) = @_;

    if ($msg) {
        output ("QUIT :$msg");
    }
    else {
        output ("QUIT :$Msgs::quit");
    }
}

sub irc_whois
{
    my ($nick) = @_;

    output ("WHOIS $nick");
}

sub irc_op
{
    my ($channel, $nick) = @_;

    output ("MODE $channel +o $nick");
}

sub irc_kick
{
    my ($channel, $nick, $reason) = @_;

    $reason = $Msgs::kick if (!$reason);

    output ("KICK $channel $nick :$reason");
}

sub irc_part
{
    output ("PART " . join (",", @_));
}

sub irc_topic
{
    my ($channel, $new_topic) = @_;

    # If we should only check the topic
    if (!$new_topic) {
        output ("TOPIC $channel");
    }
    else {
        output ("TOPIC $channel :$new_topic");
    }
}

# Output to socket
sub output
{
    my $msg = join (" ", @_);
    chomp $msg;

    # Place in out queue for processing if not empty
    if ($msg !~ /^\s*$/) {
        push_out ($msg);
    }
    else {
        Log::error ("Trying to output an empty message.");
    }
}

# Recheck a nick for auth
sub recheck
{
    my ($nick) = @_;

    $authed_nicks{$nick} = undef if (exists ($authed_nicks{$nick}));

    irc_whois ($nick);
}

sub is_treebot_op
{
    my ($channel) = @_;

    return $my_op_channels{$channel};
}

# Check nick if we should make op, and then do it
sub check_op
{
    my ($nick) = @_;

    # Grab authed as nick
    my $authed_nick = authed_nick ($nick);

    # If is auth
    if ($authed_nick) {
        # Check if we should auto op him
        for (@Conf::admins, @Conf::auto_op) {
            if ($authed_nick eq $_) {
                # Op where we can
                map { irc_op ($_, $nick); } (keys %my_op_channels);
            }
        }
    }
}

# Check if a nick is admin
sub is_admin
{
    my ($nick) = @_;

    # Sent from stdin
    if (!$nick) {
        return 1;
    }
    elsif (my $authed_nick = $authed_nicks{$nick}) {
        for my $admin (@Conf::admins) {
            if ($admin eq $authed_nick) {
                return 1;
            }
        }
    }
    else {
        return 0;
    }
}

# Return authed as nick (valuates to false if not auth)
sub authed_nick
{
    my ($nick) = @_;

    return $authed_nicks{$nick};
}

sub nick_is_auth
{
    my ($nick, $authed_nick) = @_;

    $authed_nicks{$nick} = $authed_nick;
}

sub nick_not_auth
{
    my ($nick) = @_;

    # If we don't have a record of the nick, mark as not authed
    $authed_nicks{$nick} = 0 if (!defined ($authed_nicks{$nick}));
}

# Split into irc specific parts prefix, cmd and the rest
sub split_irc_msg
{
    my ($msg) = @_;

    $msg =~ /^
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

    my ($prefix, $cmd, $param) = ($1 || "", $2 || "", $3 || "");

    return ($prefix, $cmd, $param);
}

# Split destination and the message
sub split_privmsg
{
    my ($msg) = @_;

    $msg =~ /^(\S+)\s:(.*)$/;
    return ($1, $2);
}

sub quit
{
    Log::exe ("Quitting irc");
    irc_quit (@_);
    $has_quit = 1;
}

1;

