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

my $output = "NAME                                      NUM ST   HAVE    SIZE   RATIO
Avatar.2009.1080p.BluRay.X264-AMIABLE       6 S. 100.0%  10.99G    0.73
Black.Swan.2010.720p.BRRip.x264.AC3-SliN   12 S. 100.0%   2.82G    1.73
Californication.S04E03.720p.HDTV.x264-IM   22 S. 100.0% 768.99M    2.88
Californication.S04E04.720p.HDTV.x264-IM    3 S. 100.0% 769.76M    1.59
Californication.S04E05.720p.HDTV.x264-IM   18 S. 100.0% 770.07M    1.11
Californication.S04E06.720p.HDTV.X264-DI   29 S. 100.0% 745.52M    3.47
Californication.S04E07.720p.HDTV.X264-DI    5 S. 100.0% 768.13M    3.29
Californication.S04E08.720p.HDTV.X264-DI   15 S. 100.0% 771.45M    0.48
Californication.S04E09.720p.HDTV.X264-DI   19 S. 100.0% 764.75M    1.19
Californication.S04E10.720p.HDTV.X264-DI   26 S. 100.0% 761.26M    1.82
Casino.Jack.2010.720p.BluRay.x264-iMSORN    2 S. 100.0%   4.45G    0.40
I.Rymden.Finns.Inga.Känslor.2010.SWEDIS    7 S. 100.0% 698.44M    3.13
Kick-Ass.2010.1080p.BluRay.X264-LCHD       20 S. 100.0%   7.94G    0.00
Machete 2010 720p BRRip x264-HDLiTE        21 S. 100.0%   2.28G   18.15
Mad.Men.S01.DVDRip.XviD-TB                 23 S. 100.0%   4.44G    1.56
Megamind.2010.720p.BluRay.x264-Felony       4 S. 100.0%   2.22G    0.65
Nikita.S01E12.720p.HDTV.x264-CTU            8 S. 100.0%   1.11G    2.35
Nikita.S01E13.720p.HDTV.x264-CTU            9 S. 100.0%   1.12G    2.97
Nikita.S01E14.720p.HDTV.x264-IMMERSE       24 S. 100.0%   1.12G    0.86
Nikita.S01E15.720p.HDTV.x264-CTU           28 S. 100.0%   1.12G    1.36
Nikita.S01E16.720p.HDTV.x264-CTU           17 S. 100.0%   1.12G    0.62
Ondskan.2003.NORDIC.PROPER.PAL.DVDr-JAGA   14 S. 100.0%   4.23G    4.72
Red.2010.720p.BluRay.x264-SiNNERS          13 S. 100.0%   4.43G    0.60
Stargate.1994.THEATRICAL.720p.BluRay.x26   16 S. 100.0%   5.51G    1.42
TRON.Legacy.2010.BluRay.720p.x264-Noir      1 S. 100.0%   7.81G    4.92
Tangled.2010.720p.BluRay.x264-AVS720       11 S. 100.0%   4.40G    1.98
The.Fighter.2010.720p.BluRay.x264-REFiNE   10 S. 100.0%   6.63G    3.05
The.Lovely.Bones.2009.720p.BluRay.x264-F    0 S. 100.0%   6.50G    1.42
The.Rock.1996.1080p.DTS.dxva.x264-FLAWL3   25 S. 100.0%  13.31G    0.91
Valkyrie.720p.BluRay.x264-REFiNED          27 S. 100.0%   6.58G    0.28";

                my @lines = split (/\r\n|\n/, $output);
                shift @lines;

                for (@lines) {
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
                    #say "$name $id $status $compl $size $ratio";
                    my $msg = "$name $id $compl $size $ratio";
                    Irc::send_privmsg ($target, $msg);
                }
            }
        }
    }
}

1;

