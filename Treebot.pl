#!/usr/bin/perl -w

use Modern::Perl;
use MooseX::Declare;
use Test::More;

push( @INC, '.' );

require "Config.pl";
require "Irc.pl";

# try to load all files in the plugins folder
my $dirname = "plugin";

opendir(DIR, $dirname) or die "can't open dir $dirname: $!";
while (defined (my $file = readdir(DIR))) {
    if ($file =~ qr/^([^.]+)\.pm$/) {
        require "$dirname/$file";

        my $name = $1;
        my $plugin = $name->new();

        Irc::register_plugin($name, $plugin);
    }
}
closedir(DIR);

# register SIGINT failure for cleanup
$SIG{INT} = \&quit;

sub quit
{
    print "\n"; # pretty when we ^C
    Irc::unload_plugins();
    Irc::quit();
    exit;
}

Irc::start();

