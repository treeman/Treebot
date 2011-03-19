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

sub changes_this_week
{
    my $curr = time;
    my $last_week = $curr - 60 * 60 * 24 * 7;

    my @parts = localtime ($last_week);
    my ($y, $m, $d) = @parts[5, 4, 3];
    $y += 1900;
    $m += 1;
    if ($m < 10) { $m = "0$m"; }
    if ($d < 10) { $d = "0$d"; }

    my $nice = "$y-$m-$d";

    return changes_since ($nice) . " last 7 days.";
}

sub changes_since
{
    my ($latest) = @_;

    my $txt = `git log --shortstat --date=short`;

    my $added = 0;
    my $deleted = 0;

    while ($txt =~ /commit\s*.*\n
                Author:\s*.*\n
                Date:\s*(.*)\n                  # (1) Date
                \s*
                .*\n
                \s*
                  \d+\sfiles\schanged,
                  \s(\d+)\sinsertions\Q(+)\E,   # (2) Lines added
                  \s(\d+)\sdeletions\Q(-)\E     # (3) Lines deleted
                \s*
            /xig)
    {
        my $date = $1;
        if ($date lt $latest) { last; }

        $added += $2;
        $deleted += $3;
    }

    return "$added lines added and $deleted deleted";
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

    update_from_git_pull(
        "remote: Counting objects: 17, done.
        remote: Compressing objects: 100% (10/10), done.
        remote: Total 10 (delta 7), reused 0 (delta 0)
        Unpacking objects: 100% (10/10), done.
        From /home/git/repositories/treebot
        * branch            master     -> FETCH_HEAD
        Updating 3a831aa..2dc703f
        Fast-forward
        Irc.pm                                |  198 +++------------------------------
        Plugins/Admin.pm                      |    3 +
        Plugins/Functionality/MonkeyIsland.pm |    2 +-
        Plugins/Functionality/MyGit.pm        |  173 ++++++++++++++++++++++++++++
        Plugins/{Git.pm => GitHandling.pm}    |   18 +--
        readme                                |    7 +-
        6 files changed, 204 insertions(+), 197 deletions(-)
        create mode 100644 Plugins/Functionality/MyGit.pm
        rename Plugins/{Git.pm => GitHandling.pm} (64%)"
    );
    ok( needs_restart(), "Big updates");
    @files_changed = ();
}

1;

