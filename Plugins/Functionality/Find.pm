#!/usr/bin/perl -w

use Modern::Perl;
use Test::More;
use Carp;
use LWP::Simple;

use utf8;
use locale;

use Util;

package Find;

# Working
# 0927-10548
# 040175561
# 0706826365

# Not working
# Spaces after
# 08-50714000
# Middle name is wierd
# 063 38059
# These company links breaks, some strange way of showing address
# 046-5409600
# 08-50714000

sub number
{
    my ($num) = @_;

    if ($num !~ /^\d+-? ?\d+$/) {
        return "Bad number given!";
    }
    else {
        my @infos = Find::hitta ($num);
        if (scalar @infos) {

            return format_info (@infos);
        }
        else {
            return "Nothing found, sorry.";
        }
    }
}

sub format_info
{
    my $num = scalar @_;

    if ($num == 1) {
        my ($ref) = @_;
        my %info = %$ref;

        my $str = "$info{'name'}:";
        if ($info{'tele'}) {
            $str .= " $info{'tele'}";
        }
        if ($info{'mobile'}) {
            $str .= " $info{'mobile'}";
        }
        if ($info{'address1'}) {
            $str .= " | $info{'address1'}";
        }
        if ($info{'address2'}) {
            $str .= " | $info{'address2'}";
        }
        return $str;
    }
    else {
        my $str = "$num matches:";
        my $num = 0;
        for (@_) {
            my %info = %$_;
            if ($num != 0) { $str .= ","; }
            $str .= " $info{'name'}";
            ++$num;
        }
        return $str;
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
            return ();
        }
        else {
            $hitta =~ /UCSRM_LabelSearchResult">(.*?)<\/span>/sxi;
            my $a = $1;

            my @matches;

            while ($a =~ /PersonBackground.*?<b>(.*?)<\/td>/sig) {
                my $person = $1;

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
                        if (defined ($info{'address1'})) {
                            $info{'address2'} = $found;
                        }
                        elsif (defined ($info{'name'})) {
                            $info{'address1'} = $found;
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

        $info{'mobile'} = $mobile;

        $hitta =~ /<strong>\s*Adress\s*<\/strong>(.*?)<\/div>/s;
        my $a = $1;

        $a =~ /UCDW_RepeaterFixed__ctl0_LabelStreetName">\s*(\S+)\s*<\/span>/s;
        my $street = $1;

        # Sometimes the street and number and zip and city are separated
        # Sometimes they're not...
        my @s = split (/<[^>]+>/, $street);

        # If they're split up
        if (scalar @s > 1) {
            my @good;
            for (@s) {
                if (/^\s*$/sm) {
                    next;
                }
                else {
                    push (@good, $_);
                }
            }

            if ($#good == 1) {
                $info{'address1'} = $good[0];
                $info{'address2'} = $good[1];
            }
        }
        # They're not split up
        else {
            $street =~ s/<[^>]+>/ /g;
            $street =~ s/\s+/ /g;
            $street =~ s/^\s*|\s*$//g;

            if ($a =~ /UCDW_RepeaterFixed__ctl0_LabelStreetNumber">\s*(\S+)\s*<\/span>/s)
            {
                my $number = $1;

                $info{'address1'} = "$street $number";
            }

            my ($zip, $city);
            if ($a =~ /UCDW_RepeaterFixed__ctl0_LabelZipCode">\s*(.+?)\s*<\/span>/s)
            {
                $zip = $1;
                chomp $zip;
            }

            if ($a =~ /UCDW_RepeaterFixed__ctl0_LabelLocality">\s*(.+?)\s*<\/span>/s) 
            {
                $city = $1;
                $city = Util::lc_se($city);
            }

            if ($zip and $city) {
                $info{'address2'} = "$zip $city";
            }
        }

        # Name is also a bit distorted
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
        $name =~ s/\s+/ /g;
        $name =~ s/^\s*|\s*$//g;

        $info{'name'} = $name;

        return (\%info);
    }
}

1;

