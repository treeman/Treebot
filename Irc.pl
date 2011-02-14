#!/usr/bin/perl -w

use Modern::Perl;
use MooseX::Declare;
use IO::Socket;

#package Irc;

my $sock;

sub send_msg
{
    my ($msg) = @_;
    print $sock "$msg\r\n";
    say "> $msg";
}

sub recieve_msg
{
    my ($msg) = @_;
    say "< $msg";
}

sub quit_irc
{
    send_msg("QUIT :$Config::quit_msg");
}

sub start
{
    # Connect to the IRC server.
    $sock = new IO::Socket::INET(PeerAddr => $Config::server,
                                    PeerPort => $Config::port,
                                    Proto => 'tcp') or
                                        die "Can't connect\n";

    # Log on to the server.
    send_msg "NICK $Config::nick";
    send_msg "USER $Config::username 0 * :$Config::realname";

    # Read lines from the server until it tells us we have connected.
    while (my $input = <$sock>) {
        chop $input;

        recieve_msg $input;

        # We must respond to PINGs to avoid being disconnected.
        if ($input =~ /^PING\s(.*)$/i) {
            send_msg "PONG $1";
        }

        # Check the numerical responses from the server.
        if ($input =~ /004/) {
            # We are now logged in.
            last;
        }
        elsif ($input =~ /433/) {
            die "Nickname is already in use.";
        }
    }

    # Join the channel.
    send_msg "JOIN $Config::channel";

    # Keep reading lines from the server.
    while (my $input = <$sock>) {
        chop $input;

        recieve_msg $input;

        # We must respond to PINGs to avoid being disconnected.
        if ($input =~ /^PING\s(.*)$/i) {
            send_msg "PONG $1";
        }

        parse_msg $input;
    }
}

1;

