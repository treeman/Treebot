#!/usr/bin/perl -w

use utf8;
use locale;

use Modern::Perl;

package Find;

use Carp;
use LWP::Simple;
use Util;
use Test::More;
use HTML::Entities;

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
        elsif (scalar (@infos = missatsamtal ($num))) {
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

        if (defined ($info{'guess'})) {
            return "I'm guessing: " . $info{'guess'};
        }
        else {
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

# This is small, smart and nice
sub missatsamtal
{
    my ($what) = @_;

    my $site = LWP::Simple::get "http://www.missatsamtal.se/telefonnummer/$what/";

    if ($site =~ /Enligt\sde\sflesta\shör\sdetta\sföretag\still<\/legend>\s*
                   <strong>\s*(.*?)\s*<\/strong>/xsi)
    {
        my @r = split (/<[^>]+>/, decode_entities($1));

        my %info;
        $info{'guess'} = join (", ", @r);
        return (\%info);
    }
    return ();
}

# This is huge, hacky and ugly...
# But their site is a markup mess lacking concistency, and beauty.
# Gotta love their generated html.
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
                    $found = Util::lc_se ($found);

                    if ($found =~ /^Telefon: (.*?)\s*/) {
                        if (defined ($info{'tele'})) {
                            $info{'tele'} .= ", " . $1;
                        }
                        else {
                            $info{'tele'} = $1;
                        }
                    }
                    if ($found =~ /^Mobil: (.*?)\s*/) {
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
        while ($hitta =~ /href="callto:[^"]+">\s*([^<]+)\s*<\/a>/sg) {
            my $mobile = $1;

            if (defined ($info{'mobile'})) {
                $info{'mobile'} .= ", " . $mobile;
            }
            else {
                $info{'mobile'} = $mobile;
            }
        }


        if ($hitta =~ /<strong>\s*Adress\s*<\/strong>(.*?)<\/div>/s) {
            my $a = $1;

            $a =~ /UCDW_RepeaterFixed__ctl0_LabelStreetName">\s*(\S+)\s*<\/span>/s;
            my $street = $1;

            # Sometimes the street and number and zip and city are separated
            # Sometimes they're not...
            my @s = split (/<[^>]+>/, $street);

            # If they're split up
            if (scalar @s > 1) {
                if ($street !~ /Adress saknas/) {
                    my @good;
                    for (@s) {
                        if (/^\s*$/sm) {
                            next;
                        }
                        else {
                            m/^\s*(.*?)\s*$/;
                            push (@good, $1);
                        }
                    }

                    # If the street and city are joined with postnumber and street num
                    if ($#good == 1) {
                        $info{'address1'} = Util::lc_se ($good[0]);
                        $info{'address2'} = Util::lc_se ($good[1]);
                    }
                    # Else they're split up in a set order
                    elsif ($#good > 3) {
                        my ($street, $zip, $post, $city) = @good[0, 1, 2, 3];
                        $street = Util::lc_se ($street);
                        $city = Util::lc_se ($city);
                        $info{'address1'} = "$street $zip";
                        $info{'address2'} = "$post $city";
                    }
                }
            }
            # They're not split up
            else {
                $street =~ s/<[^>]+>/ /g;
                $street =~ s/\s+/ /g;
                $street =~ s/^\s*|\s*$//g;
                $street = Util::lc_se ($street);

                if ($a =~ /UCDW_RepeaterFixed__ctl0_LabelStreetNumber">
                             \s*(\S+)\s*
                           <\/span>/xs)
                {
                    my $number = $1;

                    $info{'address1'} = "$street $number";
                }

                my ($zip, $city);
                if ($a =~ /UCDW_RepeaterFixed__ctl0_LabelZipCode">
                             \s*(.+?)\s*
                           <\/span>/xs)
                {
                    $zip = $1;
                    chomp $zip;
                }

                if ($a =~ /UCDW_RepeaterFixed__ctl0_LabelLocality">
                             \s*(.+?)\s*
                           <\/span>/xs)
                {
                    $city = $1;
                    $city = Util::lc_se($city);
                }

                if ($zip and $city) {
                    $info{'address2'} = "$zip $city";
                }
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
        #$name =~ s/<span [^>]+>(.*?)<\/span>/ $1/g;

        # Some have their job description here
        $name =~ s/<span [^>]+>(.*?)<\/span>//g;
        $name =~ s/\s+/ /g;
        $name =~ s/^\s*|\s*$//g;

        $info{'name'} = $name;

        return (\%info);
    }
}

sub number_tests
{
    # Just some numbers testing stuff.
    like (Find::number("000-000"), qr/nothing found/i, "whois: 000");
    like (Find::number("000-00-00"), qr/bad number/i, "whois: 00-00-00");
    like (Find::number("asdf"), qr/bad number/i, "whois: alpha");

    like (Find::number("0927-10548"), qr/(Eva Huhta|Peter Hietala)+/i, "whois: Home");
    like (Find::number("0706826365"),
        qr/Jonas Hietala: 070-?6826365.*lantmannagatan 126.*583\s?32.*linköping/i,
        "whois: My phone");
    like (Find::number("013-4791100"),
        qr/Opera Software.*013-4791100.*linköping/i, "whois: opera");
    like (Find::number("046-5409600"), qr/enea AB/i, "whois: enea");
    like (Find::number("08-50714000"), qr/08-50714000, 08-50714040/,
        "whois: enea multi");
    like (Find::number("070-8776196"),
        qr/070-8776196, 070-2772847, 070-7779763, 0485-75233/, "whois: many numbers");

    like (Find::number("040175561"),
        qr/hälsokost/i, "whois: missatsamtal");
}

1;

