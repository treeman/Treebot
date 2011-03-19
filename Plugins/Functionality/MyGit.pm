#!/usr/bin/perl -w

use Modern::Perl;

package Git;

use Test::More;

my $head :shared;
$head = `git rev-parse HEAD`;
$head =~ s/^\s*|\s*$//g;

my @files_changed :shared;

sub head
{
    return $head;
}

sub files_changed
{
    return @files_changed;
}

sub needs_restart
{
    my @core;
    my %harmless = %Conf::ignore_on_update;

    for (@files_changed) {
        if (!$harmless{$_}) {
            push (@core, $1);
        }
    }
    return scalar @core;
}

sub update_src
{
    # Need to set in config instead
    my $remote = "origin";
    my $branch = "master";

    my $response = `git pull $remote $branch`;

    update_from_git_pull ($response);
}

sub update_from_git_pull
{
    my ($response) = @_;

    if ($response =~ /Already up-to-date\./) {
        return;
    }
    else {
        my @lines = split(/\r\n|\r|\n/, $response);

        # Skip to files changed
        while (defined (my $line = shift @lines)) {
            if ($line =~ /fast.forward/i) {
                last;
            }
        }

        while (defined (my $line = shift @lines)) {
            if ($line =~ /(\S+)\s+\|/) {
                push (@files_changed, $1);
            }
            else {
                last;
            }
        }
    }
}

sub test_update_src
{
    update_from_git_pull(
        "From forest:treebot
        * branch            master     -> FETCH_HEAD
        Already up-to-date.",
    );
    ok( !needs_restart(), "Update nothing");

    @files_changed = ();
    update_from_git_pull(
        "Fast-forward
        plugin/Insults/Admin.pm |  183 -----------------------------------------------
        plugin/Admin.pm |  183 ---------------------------------------------------
        plugin/Down.pm |  183 ---------------------------------------------------
        readme | pew
        ideas | ladida
        3 files changed, 108 insertions(+), 206 deletions(-)
        delete mode 100644 test_cube_match.adb",
    );
    ok( needs_restart(), "Update regular");

    @files_changed = ();
    update_from_git_pull(
        "Fast-forward
        readme |  183 ---------------------------------------------------
        ideas |  183 ---------------------------------------------------
        .gitignore |  183 ---------------------------------------------------
        3 files changed, 108 insertions(+), 206 deletions(-)
        delete mode 100644 test_cube_match.adb"
    );
    ok( !needs_restart(), "Update ignore dumb files");
    @files_changed = ();

# These tests are more for testing plugin reload than anything else.
    my @tests = (
        "Fast-forward
        plugin/Insults/Admin.pm |  183 -----------------------------------------------
        plugin/Admin.pm |  183 ---------------------------------------------------
        plugin/Down.pm |  183 ---------------------------------------------------
        readme | pew
        ideas | ladida
        3 files changed, 108 insertions(+), 206 deletions(-)
        delete mode 100644 test_cube_match.adb",

        "Fast-forward
        plugin/crap/crap |  183 ---------------------------------------------------
        plugin/Admin.pm |  183 ---------------------------------------------------
        plugin/Down.pm |  183 ---------------------------------------------------
        3 files changed, 108 insertions(+), 206 deletions(-)
        delete mode 100644 test_cube_match.adb",

        "Fast-forward
        plugin/Insults/Admin.pm |  183 -----------------------------------------------
        plugin/Admin.pm |  183 ---------------------------------------------------
        core |  183 ---------------------------------------------------
        3 files changed, 108 insertions(+), 206 deletions(-)
        delete mode 100644 test_cube_match.adb",

        "Fast-forward
        plugin/douche |  183 ---------------------------------------------------
        core |  183 ---------------------------------------------------
        3 files changed, 108 insertions(+), 206 deletions(-)
        delete mode 100644 test_cube_match.adb",

        "Fast-forward
        plugin/douche |  183 ---------------------------------------------------
        3 files changed, 108 insertions(+), 206 deletions(-)
        delete mode 100644 test_cube_match.adb",

        "From forest:treebot
        * branch            master     -> FETCH_HEAD
        Already up-to-date.",

        "Fast-forward
        readme |  183 ---------------------------------------------------
        ideas |  183 ---------------------------------------------------
        .gitignore |  183 ---------------------------------------------------
        3 files changed, 108 insertions(+), 206 deletions(-)
        delete mode 100644 test_cube_match.adb",
    );

#    for (@tests) {
#        update_from_git_pull ($_);
#        say "Files changed: " . join (", ", @files_changed);
#        if (needs_restart()) {
#            say "Need restart.";
#        }
#        else {
#            say "Don't need";
#        }
#        @files_changed = ();
#    }
}

1;

