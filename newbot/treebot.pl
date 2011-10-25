#!/usr/bin/perl -w

use utf8;
use locale;

use Modern::Perl;
use IO::Socket;
use Carp;
use Test::More;

use Conf;
use Log;

my $sock;

my $botnick;

sub output
{
    my $msg = join (" ", @_);
    print $sock "$msg\r\n";
    Log::sent ($msg);
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
    $sock = new IO::Socket::INET(PeerAddr => $Conf::server,
                                 PeerPort => $Conf::port,
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
irc_nick ($Conf::nick);
output ("USER $Conf::username 0 * :$Conf::realname");

# Parse input
while (my $input = <$sock>) {
    Log::recieved ($input);

    # Handle ping
    if ($input =~ /^PING\s(.*)$/i) {
        output ("PONG $1");
    }

    my ($prefix, $cmd, $param) = split_irc_msg ($input);

    # Login successful
    if ($cmd =~ /004/) {
        output ("JOIN #madeoftree");
    }
    # Nickname in use
    elsif ($cmd =~ /433/) {
        # Try one of our backup nicknames
        if (scalar @Conf::nick_reserves) {
            irc_nick (shift @Conf::nick_reserves);
        }
        # Instead of lying down and dying try a variation
        else {
            irc_nick ($Conf::nick . int(rand(100)));
        }
    }
}

sub irc_nick
{
    my ($nick) = @_;
    output ("NICK $nick");
    $botnick = $nick;
}

