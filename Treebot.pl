#!/usr/bin/perl -w

use Modern::Perl;
use MooseX::Declare;
use Test::More;

use threads;
use Thread::Queue;

use Log;
use Bot_Config;
use Irc;
use Getopt::Long;

my $test_mode = 0;
GetOptions('test|t' => \$test_mode);

push (@INC, "plugin/");

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
    for my $thr (threads->list()) {
        $thr->detach();
    }

    Irc::unload_plugins();
    Irc::quit();

    exit;
}

Irc::start($test_mode);

