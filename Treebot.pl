#!/usr/bin/perl -w

use Modern::Perl;
use MooseX::Declare;
use Test::More;

push( @INC, '.' );

require "Config.pl";
require "Irc.pl";

my $plugindir = "plugin";

my %plugins;

opendir(DIR, $plugindir) or die "can't open dir $plugindir: $!";
while (defined (my $file = readdir(DIR))) {
    if ($file =~ qr/^([^.]+)\.pm$/) {
        require "$plugindir/$file";

        my $name = $1;
        my $obj = $name->new();

        $obj->load();
        $plugins{$name} = $obj;
    }
}
closedir(DIR);

# catch interrupt
$SIG{INT} = \&quit;

sub quit
{
    print "\n"; # pretty output if we ^C out
    quit_irc();
    exit;
}

start();

sub parse_msg
{
    my ($msg) = @_;

    if( $msg =~ /
            ^
            (?:
               :(\S+) # (1) prefix
               \s
            )?        # prefix isn't mandatory
            (\S+)     # (2) cmd
            \s
            (.+)      # (3) parameters
            $
        /x )
    {
        my $prefix;
        if (!defined ($1)) {
            $prefix = "";
        }
        else {
            $prefix = "$1";
        }
        my $cmd = $2;
        my $param = $3;

        process_irc_msg($prefix, $cmd, $param);
    }
    else {
        say "! peculiar, we couldn't capture the message";
        say $msg;
    }
}

sub process_irc_msg
{
    my ($prefix, $irc_cmd, $param) = @_;

    if( $irc_cmd =~ /PRIVMSG/ ) {
        if( $param =~ /^(\S+)\s:(.*)$/ ) {
            my $target = $1;
            my $msg = $2;

            say "msg sent to ", $target;

            if( $msg =~ /^\.(\S*)\s?(.*)$/ ) {
                my $cmd = $1;
                my $args = $2;

                say "it's a command: ", $cmd, " with params: ", $args;
            }
        }
    }
}

for my $plugin (values %plugins)
{
    my @cmds = $plugin->module_cmds();
    say "cmds it listens to: ", @cmds;

    if( grep /^pew$/, @cmds ) {
        say "listens to pew!";
    }
}

#parse_msg(":underworld2.no.quakenet.org 372 treebot2 :- This network has channel services. Consult the webpage above");

#parse_msg("PING :12341332");

