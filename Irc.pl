#!/usr/bin/perl -w

use Modern::Perl;
use MooseX::Declare;
use IO::Socket;

use Plugin;

package Irc;

my $sock;
my %plugins;
my @cmd_list;

sub register_plugin
{
    my ($name, $plugin) = @_;

    $plugins{$name} = $plugin;
}

sub load_plugins
{
    for my $plugin (values %plugins)
    {
        $plugin->load();
        my @cmds = $plugin->module_cmds();
        for my $cmd (@cmds) {
            if ($cmd) {
                push(@cmd_list, $cmd);
            }
        }
    }

    push(@cmd_list, "cmds");
    push(@cmd_list, "help");
}

sub unload_plugins
{
    for my $plugin (values %plugins)
    {
        $plugin->unload();
    }
    %plugins = ();
}

sub send_msg
{
    my ($msg) = @_;
    print $sock "$msg\r\n";
    say "> $msg";
}

sub send_privmsg
{
    my ($target, $msg) = @_;

    send_msg ("PRIVMSG $target :$msg");
}

sub recieve_msg
{
    my ($msg) = @_;
    say "< $msg";
}

sub quit
{
    send_msg ("QUIT :$Config::quit_msg");
}

sub parse_msg
{
    my ($msg) = @_;

    for my $plugin (values %plugins)
    {
        $plugin->process_bare_msg ($msg);
    }

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

        process_msg($prefix, $cmd, $param);
    }
    else {
        say "! peculiar, we couldn't capture the message";
        say $msg;
    }
}

sub process_msg
{
    my ($prefix, $irc_cmd, $param) = @_;

    for my $plugin (values %plugins)
    {
        $plugin->process_irc_msg ($prefix, $irc_cmd, $param);
    }

    if( $irc_cmd =~ /PRIVMSG/ ) {
        if( $param =~ /^(\S+)\s:(.*)$/ ) {
            my $target = $1;
            my $msg = $2;

            $prefix =~ /^(.+?)!~/;
            my $sender = $1;

            # if we're the target change target so we don't message ourselves
            # this looks pretty bad really, change?
            if ($target =~ /$Config::nick/) {
                $target = $sender;
            }

            if( $msg =~ /^\Q$Config::cmd_prefix\E(\S*)\s?(.*)$/ ) {
                my $cmd = $1;
                my $args = $2;

                if ($cmd eq "help") {
                    if ($args =~ /^\s*$/) {
                        Irc::send_privmsg ($target, $Config::help_msg);
                    }
                }
                elsif ($cmd eq "cmds") {
                    my $msg = "Documented commands: " . join(", ", @cmd_list);
                    Irc::send_privmsg ($target, $msg);
                }
                else {
                    for my $plugin (values %plugins)
                    {
                        $plugin->process_cmd ($sender, $target, $cmd, $args);
                    }
                }
            }
            else {
                for my $plugin (values %plugins)
                {
                    $plugin->process_privmsg ($sender, $target, $msg);
                }
            }
        }
    }
}

sub start
{
    # Connect to the IRC server.
    $sock = new IO::Socket::INET(PeerAddr => $Config::server,
                                    PeerPort => $Config::port,
                                    Proto => 'tcp') or
                                        die "Can't connect\n";

    # Log on to the server.
    send_msg "NICK $Config::nick";
    send_msg "USER $Config::username 0 * :$Config::realname";

    # Read lines from the server until it tells us we have connected.
    while (my $input = <$sock>) {
        chop $input;

        recieve_msg $input;

        # We must respond to PINGs to avoid being disconnected.
        if ($input =~ /^PING\s(.*)$/i) {
            send_msg "PONG $1";
        }

        # Check the numerical responses from the server.
        if ($input =~ /004/) {
            # We are now logged in.
            last;
        }
        elsif ($input =~ /433/) {
            #die "Nickname is already in use.";

            # Instead of death try to force use of some random nickname
            my $rand_int = int(rand(100));
            send_msg "NICK $Config::nick$rand_int";
        }
    }

    # Join the channel.
    send_msg "JOIN $Config::channel";

    # Actually load all plugins.
    load_plugins();

    # Keep reading lines from the server.
    while (my $input = <$sock>) {
        chop $input;

        recieve_msg $input;

        # We must respond to PINGs to avoid being disconnected.
        if ($input =~ /^PING\s(.*)$/i) {
            send_msg "PONG $1";
        }

        parse_msg $input;
    }
}

1;

