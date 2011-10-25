#!/usr/bin/perl -w

use utf8;
use locale;

use Modern::Perl;
use IO::Socket;
use Carp;
use Test::More;

my $server = "irc.quakenet.org";
my $port = 6667;
my $nickname = "treebot";
my $username = "treebot";
my $realname = "I bot ze trees";

my $sock;

sub output
{
    my $msg = join (" ", @_);
    print $sock "$msg\r\n";
    say "> $msg";
}

# Split into irc specific parts
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

    $cmd = "" when (!$cmd);

    return ($prefix, $cmd, $param);
}

my $attempt = 0;
while (!$sock) {
    # Connect to the IRC server
    $sock = new IO::Socket::INET(PeerAddr => $server,
                                 PeerPort => $port,
                                 Proto => 'tcp');
    ++$attempt;
    if (!$sock) {
        #Log::error "Attempt $attempt failed..";
        say "! Attempt $attempt failed..";
    }

    if ($attempt > 4) {
        croak "Couldn't connect, aborting.";
    }
}

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

    my ($prefix, $cmd, $param) = split_irc_msg ($input);

    if ($cmd =~ /004/) {
        output ("JOIN #madeoftree");
    }
}

