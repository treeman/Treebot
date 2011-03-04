#!/usr/bin/perl -w

package PluginHandling;

use Modern::Perl;

use threads;
use threads::shared;
use Thread::Semaphore;

use Plugin;
use Log;
use Bot_Config;

sub load_all;
sub unload_all;
sub reload_all;

sub load;
sub unload;
sub reload;

sub cmds;
sub undocumented_cmds;
sub admin_cmds;

sub traverse_call;

sub process_cmd;
sub process_admin_cmd;

sub process_privmsg;
sub process_irc_msg;
sub process_bare_msg;

sub cmd_help;

# shared reference to our plugins
my $plugins :shared;
my %real_plugins;
$plugins = share(%real_plugins);

my @cmd_list :shared;
my @undoc_cmd_list :shared;
my @admin_cmd_list :shared;

my $lock = Thread::Semaphore->new();

push (@INC, $Bot_Config::plugin_folder);

sub load_all
{
    # try to load all files in the plugins folder
    my $dirname = $Bot_Config::plugin_folder;

    $lock->down();
    opendir(DIR, $dirname) or die "can't open dir $dirname: $!";

    while (defined (my $file = readdir(DIR))) {
        if ($file =~ qr/^([^.]+)\.pm$/) {
            require "$dirname/$file";

            my $name = $1;
            my $plugin = $name->new();
            if ($plugin->DOES('Plugin')) {
                $plugin->load();

                my @cmds = $plugin->cmds();
                for my $cmd (@cmds) {
                    if ($cmd) {
                        push (@cmd_list, $cmd);
                    }
                }

                my @undoc_cmds = $plugin->undocumented_cmds();
                for my $cmd (@undoc_cmds) {
                    if ($cmd) {
                        push (@undoc_cmd_list, $cmd);
                    }
                }

                my @admin_cmds = $plugin->admin_cmds();
                for my $cmd (@admin_cmds) {
                    if ($cmd) {
                        push (@admin_cmd_list, $cmd);
                    }
                }

                $plugins->{$name} = share($plugin);
            }
            else {
                Log::error("$file in $dirname doesn't do the Plugin role!");
            }
        }
    }
    closedir(DIR);
    $lock->up();
}

sub unload_all
{
    $lock->down();
    for my $plugin (values %{$plugins})
    {
        $plugin->unload();
    }
    %{$plugins} = ();
    $lock->up();
}

sub reload_all
{

}

sub load
{

}
sub unload
{

}
sub reload
{

}

sub cmds
{
    return @cmd_list;
}
sub undocumented_cmds
{
    return @undoc_cmd_list;
}
sub admin_cmds
{
    return @admin_cmd_list;
}

sub traverse_call
{
    my ($cmd) = @_;
    my $context = wantarray();

    if (!$cmd) {
        Log::error "Trying to traverse something false";
        return;
    }

    $lock->down();
    # Void context
    if (undef ($context)) {
        for my $plugin (values %{$plugins})
        {
            $plugin->$cmd (@_);
        }
    }
    # Scalar
    elsif (!$context) {
        for my $plugin (values %{$plugins})
        {
            my $ret = $plugin->$cmd (@_);
            if (defined ($ret)) {
                return $ret;
            }
        }
    }
    # List
    elsif ($context) {
        my @res;
        for my $plugin (values %{$plugins})
        {
            my $ret = $plugin->$cmd (@_);
            if (defined ($ret)) {
                push (@res, $ret);
            }
        }
        return @res;
    }
    $lock->up();
}

sub process_cmd
{
    $lock->down();
    for my $plugin (values %{$plugins})
    {
        $plugin->process_cmd (@_);
    }
    $lock->up();
}
sub process_admin_cmd
{
    $lock->down();
    for my $plugin (values %{$plugins})
    {
        $plugin->process_admin_cmd (@_);
    }
    $lock->up();
}

sub process_privmsg
{

}
sub process_irc_msg
{

}
sub process_bare_msg
{

}

sub cmd_help
{

}

1;

