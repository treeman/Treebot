#!/usr/bin/perl -w

use utf8;
use locale;

use Modern::Perl;
use Test::More;
use LWP::Simple;

use Util;

package HN;

use JSON;
use Encode;

sub retrieve_frontpage
{
    my $txt = LWP::Simple::get
        "http://api.ihackernews.com/page";

    if ($txt) {
        my $json = decode_json $txt;
        return @{$json->{"items"}};
    }

    return ();
}

sub short_frontpage
{
    return (map { format_article_short($_); } retrieve_frontpage())[0 .. 4];
}

sub format_article
{
    my ($item) = @_;

    my $url = "";
    if ($item->{"url"} =~ /^http:\/\/(?:www\.)?([^\/]+)/) {
        $url = "($1)";
    }

    my $title = $item->{"title"};
    $title =~ s/\s{2,}/ /g;
    $title =~ s/^\s*|\s*$//g;

    my $points = $item->{"points"};
    my $comments = $item->{"commentCount"};
    my $time =  $item->{"postedAgo"};
    my $by =  $item->{"postedBy"};

    return "$title $url\n$points points by $by $time $comments comments";
}

sub format_article_short
{
    my ($item) = @_;

    my $url = "";
    if ($item->{"url"} =~ /^http:\/\/(?:www\.)?([^\/]+)/) {
        $url = " ($1)";
    }

    my $title = $item->{"title"};
    $title =~ s/\s{2,}/ /g;
    $title =~ s/^\s*|\s*$//g;

    my $points = $item->{"points"};
    my $comments = $item->{"commentCount"};

    return "$title$url | ${points}p ${comments}c";
}

1;

