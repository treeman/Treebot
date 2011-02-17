#!/usr/bin/perl -w

use Modern::Perl;
use MooseX::Declare;
use Test::More;

use threads;
use Thread::Queue;

use Log;
use Bot_Config;
use Irc;

# try to load all files in the plugins folder
my $dirname = "plugin";

opendir(DIR, $dirname) or die "can't open dir $dirname: $!";
while (defined (my $file = readdir(DIR))) {
    if ($file =~ qr/^([^.]+)\.pm$/) {
        require "$dirname/$file";

        my $name = $1;
        my $plugin = $name->new();
        if ($plugin->DOES('Plugin')) {
            Irc::register_plugin($name, $plugin);
        }
        else {
            Log::error("$file in $dirname doesn't do the Plugin role!");
        }
    }
}
closedir(DIR);

# register SIGINT failure for cleanup
$SIG{INT} = \&quit;

sub quit
{
    say "Quitting!";
    for my $thr (threads->list()) {
        $thr->detach();
    }

    print "\n"; # pretty when we ^C
    Irc::unload_plugins();
    Irc::quit();

    exit;
}

#my $irc_start = threads->create(\&Irc::start);

my $queue = Thread::Queue->new();

sub in
{
    while(<STDIN>) {
        chomp $_;
        $queue->enqueue($_);
    }
}

my $in = threads->create(\&in);

Irc::start($queue);

