#!/usr/bin/perl -w

use Modern::Perl;
use LWP::Simple;

use threads;
use threads::shared;
use Thread::Queue;
use Thread::Semaphore;

package Manga;

use Util::Site;
use Util::StoreHash;

# Save latest state, so we can notify of updates
sub load_from_disk;
sub store_to_disk;

# Retrieve cached manga info
sub get_info;
# Get formated manga info
sub get_manga;
# Recheck all manga
sub check_latest_manga;
# Get hash with info about a specific manga
sub fetch_info;

# We have some info about a manga, let's try to add it
sub add_info;
sub update_info;

sub is_useful;
sub is_better;
sub format_manga;
sub convert_url;

# Our supported sites
sub get_mangastream_info;
sub get_mangable_info;

sub get_month_num;

# Debug
sub print_manga;

# Info about all manga we're tracking
my $manga_info :shared = &share({});
my $lock = Thread::Semaphore->new();

sub load_from_disk
{
    my $in_store = StoreHash::retrieve_hash_hash ("manga");
    if (defined ($in_store)) {
        $manga_info = shared_clone($in_store);
    }
}

sub store_to_disk
{
    StoreHash::store_hash_hash ("manga", $manga_info);
}

sub get_info
{
    my ($manga) = @_;

    $lock->down();
    my $info = $manga_info->{$manga};
    $lock->up();

    return $info;
}

sub get_manga
{
    my ($manga) = @_;

    return format_manga (get_info ($manga));
}

sub check_latest_manga
{
    my @manga = @_;
    my @threads;

    # Parallell fetch and update mangas
    for my $manga (@manga) {
        push (@threads, (threads->create(\&fetch_info, $manga)));
    }

    while (scalar @threads) {
        my @not_done;
        for my $thr (@threads) {
            if ($thr->is_joinable) {
                my $info = $thr->join();
                if (is_useful ($info)) {
                    add_info ($info);
                }
            }
            else {
                push (@not_done, $thr);
            }
        }
        @threads = @not_done;
    }
}

sub fetch_info
{
    my ($manga) = @_;

    my $info = {};

    # Parallell manga fetching
    # This way we don't need parallell pre download sites
    my @threads;

    push (@threads, (threads->create(\&get_mangastream_info, $manga)));
    push (@threads, (threads->create(\&get_mangable_info, $manga)));

    while (scalar @threads) {
        my @not_done;
        for my $thr (@threads) {
            if ($thr->is_joinable) {
                update_info ($info, $thr->join());
            }
            else {
                push (@not_done, $thr);
            }
        }
        @threads = @not_done;
    }

    return $info;
}

sub add_info
{
    my ($info) = @_;
    my $manga = $$info{"manga"};

    $lock->down();

    # If we already have a manga checked in and we now have a newer
    if (exists ($manga_info->{$manga}) &&
        is_useful ($manga_info->{$manga}) &&
        is_useful ($info) &&
        is_newer ($manga_info->{$manga}, $info))
    {
        say "Omg $manga is newer!";
    }

    # If we need to update
    if (!exists ($manga_info->{$manga}) ||
        is_better ($manga_info->{$manga}, $info))
    {
        $manga_info->{$manga} = shared_clone($info);
    }
    $lock->up();
}

sub update_info
{
    my ($old, $new) = @_;

    if (is_better ($old, $new)) {
        %$old = %$new;
    }
}

sub is_useful
{
    my ($info) = @_;
    return defined($$info{"manga"}) &&
           defined($$info{"link"}) &&
           defined($$info{"chapter"});
}

sub is_newer
{
    my ($old, $new) = @_;

    return $$new{"chapter"} > $$old{"chapter"};
}

sub is_better
{
    my ($old, $new) = @_;

    if (!is_useful ($old)) {
        return 1;
    }
    elsif (!is_useful ($new)) {
        return 0;
    }
    else {
        return is_newer ($old, $new);
    }
}

sub format_manga
{
    my ($info) = @_;

    my $txt = $info->{"manga"}." ".$info->{"chapter"};
#    if ($info->{"title"}) {
#        $txt .= ": ".$info->{"title"};
#    }

    $info->{"link"} =~ /^http:\/\/(?:www\.)?([^\/]+)/;
    $txt .= " ($1)";
    return $txt;
}

sub convert_url
{
    my ($url) = @_;
    $url = lc ($url);
    $url =~ s/\s/_/g;
    return $url;
}

sub get_mangastream_info
{
    my ($manga) = @_;

    my $site = Site::get "http://mangastream.com/manga";

    my $info = {};

    my $manga_url = convert_url ($manga);
    if ($site =~ /<a\shref="
                    (\/read\/$manga_url\/[^"]+) # (1) Link
                  ">
                    (\d+)                       # (2) Chapter
                    \s-\s
                    (.+?)                       # (3) Chapter title
                  <\/a>
                 /xsi)
    {
        my $link = "http://mangastream.com$1";
        my $chapter = $2;
        my $title = $3;

        $$info{"link"} = $link;
        $$info{"manga"} = $manga;
        $$info{"chapter"} = $chapter;
        $$info{"title"} = $title;
    }

    return $info;
}

sub get_mangable_info
{
    my ($manga) = @_;
    my $manga_url = convert_url ($manga);

    my $site = Site::get "http://mangable.com/manga-list/";

    my $info = {};

    if ($site =~ /<a\s
                    href="
                       ([^"]+\/$manga_url\/[^"]+) # (1) Link
                    "\s+
                    title="
                       .*?
                       \s
                       (\d+)                    # (2) Chapter
                    "\s*
                  >
                 /xsi)
    {
        my $link = $1;
        my $chapter = $2;

        $$info{"link"} = $link;
        $$info{"manga"} = $manga;
        $$info{"chapter"} = $chapter;
        $$info{"title"} = "";
    }

    return $info;
}

sub get_month_num {
    my %months = (
        Jan => "01",
        Feb => "02",
        Mar => "03",
        Apr => "04",
        May => "05",
        Jun => "06",
        Jul => "07",
        Aug => "08",
        Sep => "09",
        Okt => "10",
        Nov => "11",
        Dec => "12",
    );
    return $months{$_[0]};
}

sub print_manga
{
    my (%info) = @_;

    say "----------------------------------------------------------------";
    say $info{"manga"}, " ", $info{"chapter"}, " - ", $info{"title"};
    say $info{"link"};
    #say $info{"manga"};
    #say $info{"chapter"};
    #say $info{"title"};
    #say $info{"date"};
}

sub print_stored_manga
{
    for my $manga (values %$manga_info) {
        print_manga %$manga;
    }
}

