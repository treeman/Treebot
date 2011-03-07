#!/usr/bin/perl

use Modern::Perl;
use Test::More;

use MooseX::Declare;
use Plugin;

class Git extends DefaultPlugin
{
    override load
    {
        $self->head(`git rev-parse HEAD`);
    }
    override cmds
    {
        return qw(git);
    }

    override process_cmd ($sender, $target, $cmd, $arg)
    {
        if ($cmd eq "git") {
            if ($arg =~ /^commit$/) {
                my $head = $self->head();
                chomp $head;
                Irc::send_privmsg ($target, "Latest commit: $head");
            }
        }
    }

    override process_admin_cmd ($sender, $target, $cmd, $arg)
    {
        if ($cmd ne "git") { return; }

        if ($arg =~ /^pull\s+(\S+)\s+(\S+)/) {
            my $remote = $1;
            my $branch = $2;

            #my $output = `git pull $remote $branch`;
            my $output = "
remote: Counting objects: 10, done.
remote: Compressing objects: 100% (6/6), done.
remote: Total 6 (delta 4), reused 0 (delta 0)
Unpacking objects: 100% (6/6), done.
From forest:soma-cube
 * branch            master     -> FETCH_HEAD
Updating 2d5ee99..a6f932f
Fast-forward
 test_cube_match.adb |  183 ---------------------------------------------------
 tester              |  Bin 644840 -> 644884 bytes
 tester.adb          |  131 ++++++++++++++++++++++++++++++-------
 3 files changed, 108 insertions(+), 206 deletions(-)
 delete mode 100644 test_cube_match.adb";

            my $output = "
From forest:treebot
 * branch            master     -> FETCH_HEAD
Already up-to-date.";

            if ($output =~ /up.to.date/) {
                say "Already up to date.";
            }
            else {
                my @lines = split(/\r\n|\r|\n/, $output);

                # Skip to files changed
                while (defined (my $line = shift @lines)) {
                    if ($line =~ /fast.forward/i) {
                        last;
                    }
                }

                my @files_changed;

                #while (defined (my $line = <$output>)) {
                while (defined (my $line = shift @lines)) {
                    if ($line =~ /(\S+)\s+\|/) {
                        push (@files_changed, $1);
                    }
                    else {
                        last;
                    }
                }

                say "Files changed: " . join (", ", @files_changed);
            }
        }
    }

    override cmd_help ($cmd)
    {
        if ($cmd eq "git commit") {
            return "Show current commit.";
        }
    }

    has 'head', is => 'rw';
}

1;

