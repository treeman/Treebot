#!/usr/bin/perl -w

use utf8;
use locale;

use Modern::Perl;
use Test::More;

package Info;

use LWP::Simple;
use LWP::UserAgent;
use HTML::Entities;
use Util;
use Log;

sub down
{
    my ($url) = @_;

    my $site = LWP::Simple::get "http://www.isup.me/$url";

    if ($site =~ /<div\sid="container">\s*?
                    (.+)?
                    \s*<p>
                    /xs)
    {
        my $isup = $1;
        $isup =~ s/<[^>]*>//g;
        $isup =~ s/\n//g;
        $isup =~ s/\r//g;
        $isup =~ s/ +/ /g;
        $isup =~ s/^ +//g;

        return $isup;
    }
    else {
        Log::error "Couldn't match down? response!";
        return "";
    }
}

sub train
{
    my ($date, $train) = @_;

    if (!defined ($date)) {
        $date = Util::make_date (time);
    }

    my $ua = new LWP::UserAgent;
    my $obj = $ua->get ('http://www6.trafikverket.se/trafikinformation');

    $obj->base =~ /information\/([^\/]+)\//;
    my $id = $1;

    my $content = LWP::Simple::get
        "http://www6.trafikverket.se/trafikinformation/$id/WebPage/TrafficSituationTrain.aspx?JF=7&train=$date,$train";

    my @results;

    if ($content =~ /<title>Felmeddelande<\/title>/xi) {
        #say "Couldn't find anything.";
        return @results;
    }
    else {
        $content =~ /<table[^>]+>(.*?)<\/table>/xs;
        my $times = $1;

        for my $res ($times =~
                /<tr\sclass="FavouriteDataGridItem[^"]*">
                    (.+?)
                <\/tr>
                /gsx)
        {
            $res =~ /
                    <td\svalign="top"
                    .*?
                    <div\sclass="textLinks">
                        (.*?)                      # (1) Station
                    <\/div>
                    (.*)
                    /xs;

            my $station = Util::crude_remove_html ($1);
            my $rest = $2;

            # The rest of info is in multiple td tags
            my @split = $rest =~ /<td.*?>(.*?)<\/td>/gs;

            my $arrival = $split[0];
            my $departure = $split[1];
            my $track = $split[2];

            #say $station;
            #say $arrival;
            #say $departure;
            #say $track;

            my %info;

            $info{'station'} = $station;

            @split = $arrival =~/<div.*?>(.*?)<\/div>/gs;

            if (scalar @split > 0) {
                $info{'calc_arrival'} = $split[0];
            }
            if (scalar @split > 2) {
                $split[2] = Util::crude_remove_html ($split[2]);
                if ($split[1] =~ /Ankom/i) {
                    $info{'arrived'} = $split[2];
                }
                elsif ($split[1] =~ /Ber.knas/i) {
                    $info{'est_arrival'} = $split[2];
                }
            }

            @split = $departure =~/<div.*?>(.*?)<\/div>/gs;

            if (scalar @split > 0) {
                $info{'calc_depart'} = $split[0];
            }
            if (scalar @split > 2) {
                $split[2] = Util::crude_remove_html ($split[2]);
                if ($split[1] =~ /Avgick/i) {
                    $info{'departed'} = $split[2];
                }
                elsif ($split[1] =~ /Ber.knas/i) {
                    $info{'est_depart'} = $split[2];
                }
            }

            push (@results, format_station_time(%info));
        }
    }

    return @results;
}

sub format_station_time
{
    my %i = @_;
    #say join(", ", @_);

    my $msg = "$i{'station'}: ";

    if ($i{'arrived'}) {
        $msg .= "$i{'arrived'}";
    }
    elsif ($i{'est_arrival'}) {
        $msg .= "$i{'est_arrival'}";
    }
    elsif ($i{'calc_arrival'}) {
        $msg .= "$i{'calc_arrival'}";
    }
    else {
        $msg .= "--:--";
    }

    $msg .= ", ";

    if ($i{'departed'}) {
        $msg .= "$i{'departed'}";
    }
    elsif ($i{'est_depart'}) {
        $msg .= "$i{'est_depart'}";
    }
    elsif ($i{'calc_depart'}) {
        $msg .= "$i{'calc_depart'}";
    }
    else {
        $msg .= "--:--";
    }

    return $msg;
}

1;

