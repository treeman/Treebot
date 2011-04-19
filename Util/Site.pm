#!/usr/bin/perl -w

use Modern::Perl;
use LWP::Simple;

use threads;
use threads::shared;
use Thread::Queue;
use Thread::Semaphore;

package Site;

my %sites :shared;
my %sites_gotten :shared;
my %sites_waiting :shared;
my $site_lock = Thread::Semaphore->new();

my $store_site = 60;

sub get
{
    my ($url) = @_;

    download_site ($url);

    while (1) {
        $site_lock->down();
            my $site = $sites{$url};
        $site_lock->up();

        if (defined ($site)) {
            return $site;
        }
        else {
            threads::yield();
            sleep 1;
        }
    }
}

# Will not block the semaphore while waiting for site to download
# Will return immediately if someone else is fetching or we have a valid site
sub download_site
{
    my ($url) = @_;

    $site_lock->down();
        my $has_site = $sites{$url};
        my $gotten = $sites_gotten{$url};
    $site_lock->up();

    # We have a valid site
    if (defined ($has_site) && time - $gotten <= $store_site) {
        return;
    }

    $site_lock->down();
        my $is_blocking = $sites_waiting{$url};
        $sites_waiting{$url} = 1;
    $site_lock->up();

    # Already someone downloading the site
    return if $is_blocking;

    #say "Nobody is blocking!";
    my $t = time;

    say "Downloading: $url";
    my $site = LWP::Simple::get $url;
    my $time = time;

    my $passed = time - $t;

    my @parts = gmtime($passed);
    my ($d, $h, $m, $s) = @parts[7, 2, 1, 0];

    say "$url downloaded at $s";

    $site_lock->down();
        delete $sites_waiting{$url};
        $sites{$url} = $site;
        $sites_gotten{$url} = $time;
    $site_lock->up();
}

# Download sites in parallell
# Will block until done
sub download_sites
{
    my @threads;

    for my $site (@_) {
        push (@threads, (threads->create(\&Site::download_site, $site)));
    }

    while (scalar @threads) {
        my @not_done;
        for my $thr (@threads) {
            if ($thr->is_joinable) {
                $thr->join();
            }
            else {
                push (@not_done, $thr);
            }
        }
        @threads = @not_done;
    }
}

