#!/usr/bin/perl

use Modern::Perl;
use Test::More;
use MooseX::Declare;
use LWP::Simple;

use Plugin;
use Log;

class Torrent extends DefaultPlugin
{
    override process_admin_cmd ($sender, $target, $cmd, $arg)
    {
        if ($cmd eq "torrent") {

            if ($arg eq "stat") {
                my $output = `btcli stat`;

                if ($output =~ /cannot open connection/) {
                    Irc::send_privmsg ($target, "Daemon not started.");
                }
                else {
                    #$output =~ /\n.*?(.*)/;
                    my @lines = split (/\r\n|\n/, $output);
                    my @info = split (/\s+/, $lines[1]);
                    shift @info; # Remove empty first

                    my ($have, $dload, $rtdown, $uload, $rtup, $ratio, $conn, $avail, $tr) = @info;

                    if ($tr eq "0") {
                        Irc::send_privmsg ($target, "$tr running | down: $dload | up: $uload");
                    }
                    else {

                        my $msg = "$tr at $have | down: $dload";
                        if ($have ne "100.0%") {
                            $msg .= " $rtdown | avail: $avail";
                        }
                        $msg .= " | up: $uload $rtup | ratio: $ratio";

                        Irc::send_privmsg ($target, $msg);
                    }
                }
            }
            elsif ($arg eq "start") {
                my $output = `btpd -p 21143`;

                if ($output =~ /another instance.*running/i) {
                    Irc::send_privmsg ($target, "Already started.");
                }
                else {
                    Irc::send_privmsg ($target, "Daemon started.");
                }
            }
            elsif ($arg eq "kill") {
                my $output = `btcli kill`;

                if ($output =~ /cannot open connection/) {
                    Irc::send_privmsg ($target, "Daemon not started.");
                }
                else {
                    Irc::send_privmsg ($target, "Daemon killed.");
                }
            }
        }
    }
}

1;

