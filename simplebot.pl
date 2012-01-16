#!/usr/bin/perl -w

use Modern::Perl;
use IO::Socket;

# Configs
my $server = "irc.quakenet.org";
my $port = 6667;
my $nickname = "simplebot";
my $username = "simplebot";
my $realname = "I'm very simple minded oh yeah";

# Our socket we use to communicate with
my $sock;

# Output something to the socket and to stdout
sub output
{
    my $msg = join (" ", @_);
    print $sock "$msg\r\n";
    say "> $msg";
}

# Connect to the IRC server
$sock = new IO::Socket::INET(PeerAddr => $server,
                             PeerPort => $port,
                             Proto => 'tcp');

# Register user and nickname
output ("NICK $nickname");
output ("USER $username 0 * :$realname");

# Parse input
while (my $input = <$sock>) {
    print "< $input";

    # Handle ping
    if ($input =~ /^PING\s(.*)$/i) {
        output ("PONG $1");
    }

    # Split irc message into parts
    if ($input =~ /^
        (?:
            :(\S+)      # (1) prefix
            \s
        )?              # prefix isn't mandatory
        (\S+)           # (2) cmd
        \s
        (.+?)           # (3) parameters
        \r?             # irc standard includes carriage return which we don't want
        $
        /x) {

        my ($prefix, $cmd, $param) = ($1 || "", $2, $3);

        # Join channel when connected
        if ($cmd =~ /004/) {
            output ("JOIN #madeoftree");
        }
        # Handle a privmsg and if someone says hello, respond
        elsif ($cmd eq "PRIVMSG" && $param =~ /^(#.+) :.*hello/) {
            my $channel = $1;
            output ("PRIVMSG $channel :hello there!");
        }
    }
}

