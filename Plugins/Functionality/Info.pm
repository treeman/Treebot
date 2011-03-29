#!/usr/bin/perl -w

use Modern::Perl;
use Test::More;

package Info;

use LWP::Simple;
use LWP::UserAgent;
use HTML::Entities;
use Util;

sub train
{
    my $ua = new LWP::UserAgent;
    my $obj = $ua->get ('http://www6.trafikverket.se/trafikinformation');

    $obj->base =~ /information\/([^\/]+)\//;
    my $id = $1;

    my $content = LWP::Simple::get
        #"http://www6.trafikverket.se/trafikinformation/$id/WebPage/TrafficSituationTrain.aspx?JF=7&train=20110329,8769";
        #"http://www6.trafikverket.se/trafikinformation/$id/WebPage/TrafficSituationTrain.aspx?JF=7&train=20110329,8706";
        "http://www6.trafikverket.se/trafikinformation/$id/WebPage/TrafficSituationTrain.aspx?JF=7&train=20110329,10543";

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
                   <a.*?>
                     (.*?)                      # (1) Station
                   <\/a>
                   (.*)
                /xs;

        my $station = $1;
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

        say format_station_time(%info);
    }
}

sub format_station_time
{
    my %i = @_;
    say join(", ", @_);

    my $msg = "$i{'station'}: ";

    return $msg;
}

1;

