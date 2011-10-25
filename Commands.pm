#!/usr/bin/perl -w

use utf8;
use locale;

package Commands;

use Modern::Perl;

use Irc;
use Msgs;

sub process_cmd
{
    my ($sender, $target, $cmd, $arg) = @_;

    if ($cmd eq "help") {
        if ($arg =~ /^\s*$/) {
            Irc::send_privmsg ($target, $Msgs::help_msg);
        }
        elsif ($arg eq "help") {
            Irc::send_privmsg ($target, "A friendly help message for my commands.");
        }
        else {
            my $help_sent = 0;

            #my @help = Plugin::get_cmd_help ($arg);
            my @help = "No help 4 u.";
            for (@help) {
                Irc::send_privmsg ($target, $_);
                $help_sent = 1;
            }

            if (!$help_sent) {
                Irc::send_privmsg ($target, $Msgs::help_missing);
            }
        }
    }
    elsif ($cmd =~ /^cmds|commands$/) {
        my $msg = "Documented commands: " . join(", ", cmds());
        Irc::send_privmsg ($target, $msg);
    }
    elsif ($cmd =~ /undocumented_?cmds|undoc/) {
        my $msg = "Undocumented commands: " . join(", ", undoc_cmds());
        Irc::send_privmsg ($target, $msg);
    }
    elsif ($cmd eq "recheck") {
        Irc::recheck ($sender);
    }
    else {
        Log::debug "Before process_cmd";

        Irc::recheck_nick ($sender);
        #Plugin::process_cmd ($sender, $target, $cmd, $arg);
        Log::debug "After process_cmd";
    }

    if (Irc::is_admin($sender)) {
        process_admin_cmd ($sender, $target, $cmd, $arg);
    }
}

sub process_admin_cmd
{
    my ($sender, $target, $cmd, $arg) = @_;

    if ($cmd eq "quit") {
        main::quit ($arg);
    }
    elsif ($cmd eq "restart") {
        main::restart ();
    }
    elsif ($cmd =~ /^admin_?cmds$/) {
        my $msg = "Admin commands: " . join(", ", admin_cmds());
        Irc::send_privmsg ($target, $msg);
    }
    elsif ($cmd eq "update") {
        Git::update_src ($target);

        if (Git::needs_restart()) {
            my $msg = "Files changed: " . join(", ", Git::files_changed());
            Irc::send_privmsg ($target, $msg);
            Irc::send_privmsg ($target, "We're looking like Windows update here, brb.");
            main::restart ("Updating...");
        }
        else {
            if (scalar Git::files_changed()) {
                Irc::send_privmsg ($target, "Nothing of vital importance changed.");
            }
            else {
                Irc::send_privmsg ($target, "Already up to date.");
            }
        }
    }
    else {
        #Plugin::process_admin_cmd ($sender, $target, $cmd, $arg);
    }
}

1;

