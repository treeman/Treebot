#!/usr/bin/perl -w

use Modern::Perl;
use MooseX::Declare;
use Test::More;

use threads;
use Thread::Queue;

use Log;
use Bot_Config;
use Irc;


my $in_queue = Thread::Queue->new();

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

sub in
{
    while(<STDIN>) {
        chomp $_;
        if (/^\./) {
            # If it's the command it will be taken care of
            #$in_queue->enqueue($_);
            Irc::process_admin_cmd ($_);
        }
        elsif (/^<\s*(.*)/) {
            # Act like we recieve it from the socket
            say "~ $1";
            $in_queue->enqueue("$1\r\n");
        }
        else {
            # If it's not a command we just pipe it to the server
            Irc::send_msg ($_);
        }
    }
}

my $in = threads->create(\&in);

Irc::start($in_queue);

