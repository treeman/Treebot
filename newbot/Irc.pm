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

# Thread safe queues for writing to our socket and reading from it
my $in_queue = Thread::Queue->new();
my $out_queue = Thread::Queue->new();

sub push_in { map { $in_queue->enqueue ($_); } @_; }
sub push_out { map { $out_queue->enqueue ($_); } @_; }

my $sock;
my $sock_lock = Thread::Semaphore->new(2);

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

# Our current name
my $botnick;

# Startup irc
# Will run until we get called quits
sub start
{
    my ($dry, $test) = @_;


    # Flag is set when we're connected and we can recieve commands
    my $has_connected = 0;

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

        # Only do these after we're connected
        if ($has_connected)
        {
            # Check plugin actions for irc message
            Plugin::process_irc_msg ($prefix, $cmd, $param);

            # Handle privmsg
            if ($cmd =~ /PRIVMSG/) {
                my $nick = (split /!/, $prefix)[0];

                my ($target, $what) = split_privmsg ($param);

                Log::debug ("Privmsg: $nick $target $what");

                Plugin::process_privmsg ($nick, $target, $what);

                # If someone did type help
                if ($what eq "help") {
                    irc_privmsg ($target, "If you want my help try ${Conf::cmd_prefix}help");
                }

                # If we have a command
                if ($what =~ /^\Q$Conf::cmd_prefix\E(\S+)\s*(.*)/) {
                    my ($cmd, $rest) = ($1, $2);

                    if ($cmd eq "help") {
                        if ($rest eq "") {
                            irc_privmsg ($target, "I'm just a simple bot. Prefix commands with a $Conf::cmd_prefix to issue a command, ex `.mi_insult`. Type `${Conf::cmd_prefix}cmds for a list of commands.");
                        }
                        elsif ($rest eq "help") {
                            irc_privmsg ($target, "Find out how I can service you.");
                        }
                        else {
                            my $help_sent = 0;

                            my @help = Plugin::get_cmd_help ($rest);
                            for my $msg (@help) {
                                irc_privmsg ($target, $msg);
                                $help_sent = 1;
                            }

                            if (!$help_sent) {
                                irc_privmsg ($target, "Sorry you're on your own!");
                            }
                        }
                    }

                    process_cmd ($nick, $target, $cmd, $rest);
                }
            }
        }
    }
}

sub process_cmd
{
    my ($nick, $target, $cmd, $rest) = @_;

    Log::debug ("cmd recieved: $cmd $rest");

    Plugin::process_cmd ($nick, $target, $cmd, $rest);
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
        output ("QUIT :Time for my beauty sleep.");
    }
}

# Output to socket
sub output
{
    my $msg = join (" ", @_);
    chomp $msg;

    # Place in out queue for processing
    if (length ($msg) > 0) {
        push_out ($msg);
    }
    else {
        Log::error ("Trying to output an empty message.");
    }
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

    my ($prefix, $cmd, $param) = ($1, $2, $3);

    $prefix = "" if (!$prefix);

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
}

1;

