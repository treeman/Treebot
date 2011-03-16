#!/usr/bin/perl -w

use Modern::Perl;
use Test::More;
use Carp;
use LWP::Simple;

use utf8;
use locale;

use Util;

package Find;

#my $num = "040175561";
#my $num = "0706826365";

sub number
{
    my ($num) = @_;

    if ($num !~ /^\d+-? ?\d+$/) {
        say "Bad number given!";
    }
    else {
        my @infos = Find::hitta ($num);
        if (scalar @infos) {
            my $num = scalar @infos;
            say "Found $num matches:";
            for my $r (@infos) {
                say $r->{'name'};
            }
        }
        else {
            say "No info.";
        }
    }
}

sub hitta
{
    my ($what) = @_;

    my $hitta = LWP::Simple::get "http://www.hitta.se/SearchMixed.aspx?vad=$what";

    my %info;

    if ($hitta =~ /<a\s+id="UCSRM_HyperlinkViewAllWhite"\s+class="NoLinkResults">
                    \s*(\d+)\s*<\/a>/sxi) {

        if ($1 == 0) {
            say "Nothing found";
            return ();
        }
        else {
            $hitta =~ /UCSRM_LabelSearchResult">(.*?)<\/span>/sxi;
            my $a = $1;

            my @matches;

            while ($a =~ /PersonBackground.*?<b>(.*?)<\/td>/sig) {
                #say $1;
                my $person = $1;
                $person =~ /<b>\s*(.*?)\s*<\/b>/s;
                #say $1;
                $person =~ /Telefon:\s*(.*?)<br/s;
                #say $1;
                $person =~ /Mobil:\s*(.*?)<br/s;
                #say $1;

                my %info;

                while ($person =~ /(.+?)<br\/>/gs) {
                    my $found = $1;
                    $found =~ s/<\/?[^>]+>//g;
                    $found =~ s/\s+/ /g;
                    #say "uno";
                    #say $found;

                    if ($found =~ /^Telefon: (.*?)\s*/) {
                        $info{'tele'} = $1;
                    }
                    elsif ($found =~ /^Mobil: (.*?)\s*/) {
                        $info{'mobile'} = $1;
                    }
                    else {
                        # Find out what's unused
                        if (defined ($info{'adress1'})) {
                            $info{'adress2'} = $found;
                        }
                        elsif (defined ($info{'name'})) {
                            $info{'adress1'} = $found;
                        }
                        else {
                            $info{'name'} = $found;
                        }
                    }

                }

                push (@matches, \%info);
            }

            return @matches;
        }
    }
    else {
        $hitta =~ /href="callto:[^"]+">\s*([^<]+)\s*<\/a>/s;
        my $mobile = $1;

        $hitta =~ /<strong>\s*Adress\s*<\/strong>(.*?)<\/div>/s;
        my $a = $1;

        $a =~ /UCDW_RepeaterFixed__ctl0_LabelStreetName">\s*(\S+)\s*<\/span>/s;
        my $street = $1;

        $a =~ /UCDW_RepeaterFixed__ctl0_LabelStreetNumber">\s*(\S+)\s*<\/span>/s;
        my $number = $1;

        $a =~ /UCDW_RepeaterFixed__ctl0_LabelZipCode">\s*(.+?)\s*<\/span>/s;
        my $zip = $1;
        chomp $zip;

        $a =~ /UCDW_RepeaterFixed__ctl0_LabelLocality">\s*(.+?)\s*<\/span>/s;
        my $city = $1;
        $city = Util::lc_se($city);

        $hitta =~ /class="LeftHeader">
                    \s*
                    <h1>
                    \s*
                    (.*?)
                    \s*
                    <\/h1>
                    \s*
                <\/td>
                /xs;
        my $name = $1;
        $name =~ s/<span [^>]+>(.*?)<\/span>/ $1/g;
        $name =~ s/\s{2,}/ /g;
        $name =~ s/^\s*|\s*$//g;

        $info{'name'} = $name;
        $info{'mobile'} = $mobile;
        $info{'adress1'} = "$street $number";
        $info{'adress2'} = "$zip $city";

        return (\%info);
    }
}

1;

