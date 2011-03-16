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

            if ($arg eq "start") {
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
            elsif ($arg eq "stat") {
                my $output = `btcli stat`;

                if ($output =~ /cannot open connection/) {
                    Irc::send_privmsg ($target, "Daemon not started.");
                }
                else {
                    # Split lines and split into info
                    my @lines = split (/\r\n|\n/, $output);
                    my @info = split (/\s+/, $lines[1]);

                    # Might be different output for different environments. Not really sure why.
                    if ($info[0] =~ /^\s*$/) {
                        shift @info; # Remove empty first
                    }

                    my ($have, $dload, $rtdown, $uload, $rtup, $ratio, $conn, $avail, $tr) = @info;

                    if ($tr eq "0") {
                        Irc::send_privmsg ($target, "$tr running | down: $dload | up: $uload");
                    }
                    else {

                        my $msg = "$tr at $have";

                        if ($have ne "100.0%" and $dload ne "0.00M") {
                            $msg .= " | down:";

                            if ($dload ne "0.00M") {
                                $msg .= " $dload";
                            }
                            if ($have ne "100.0%") {
                                $msg .= " $rtdown | avail: $avail";
                            }
                        }

                        if ($uload eq "0.00M" and $rtup eq "0.00kB/s") {
                            $msg .= " | conn: $conn";
                        }
                        else {
                            $msg .= " | up: $uload $rtup";

                        }

                        $msg .= " | ratio: $ratio";

                        Irc::send_privmsg ($target, $msg);
                    }
                }
            }
            elsif ($arg eq "list") {
                my $output = `btcli list`;

                my @lines = split (/\r\n|\n/, $output);
                shift @lines;

                my $num = 0;
                for (@lines) {
                    last if $num > 4;

                    $_ =~ /(.*?)            # (1) Name, can have spaces..
                           \s+
                           (\d+)            # (2) Torrent id
                           \s+
                           (\S+)            # (3) Status, ie seeding leeching paused
                           \s+
                           (\d+\.\d+%)      # (4) Completion
                           \s+
                           (\d+\.\d+.)      # (5) Size
                           \s+
                           (\d+\.\d+)       # (6) Ratio
                    /xs;

                    my ($name, $id, $status, $compl, $size, $ratio) =
                       ($1,    $2,  $3,      $4,     $5,    $6);

                    $name = Util::post_space_str ($name, 42);
                    $id = Util::pre_space_str ($id, 2);
                    $compl = Util::pre_space_str ($compl, 6);
                    $size = Util::pre_space_str ($size, 8);
                    $ratio = Util::pre_space_str ($ratio, 6);

                    my $msg = "$name $id $compl $size $ratio";
                    Irc::send_privmsg ($sender, $msg);

                    ++$num;
                }
            }
        }
    }
}

1;

