#!/usr/bin/perl -w

use utf8;
use locale;

use Modern::Perl;
use MooseX::Declare;

role Plugin
{
    requires qw(
        load
        unload
        cmds
        undocumented_cmds
        admin_cmds
        process_cmd
        process_admin_cmd
        process_privmsg
        process_irc_msg
        process_bare_msg
        cmd_help
        run_tests);
}

class DefaultPlugin with Plugin
{
    method load { }
    method unload { }

    # Return list of commands the plugin listens to
    method cmds { return (); }
    method undocumented_cmds { return (); }
    method admin_cmds { return (); }

    # Sender, target, cmd, args
    method process_cmd { }
    method process_admin_cmd { }

    # Sender, target, msg
    method process_privmsg { }

    # A standard irc message
    # Prefix, command, parameters (the rest)
    method process_irc_msg { }

    # Whole recieved irc message
    method process_bare_msg { }

    # Should return a help message for every command the module defines
    method cmd_help { return ""; }

    # Place your tests here
    method run_tests { }
}

package Plugin;

use threads;
use threads::shared;
use Thread::Semaphore;

use Test::More;

sub resolve_filepath;

sub loaded;
sub available;

sub load_all;
sub unload_all;
sub reload_all;

sub kill_all;

sub load;
sub load_file;
sub unload;
sub reload;

sub cmds;
sub undoc_cmds;
sub admin_cmds;

# Bad name?
#sub process_msg;

sub process_cmd;
sub process_admin_cmd;

sub process_privmsg;
sub process_irc_msg;
sub process_bare_msg;

sub get_cmd_help;

sub run_tests;

# shared reference to our plugins
my $plugins :shared;
my %real_plugins;
$plugins = share(%real_plugins);

my %cmd_list :shared;
my %undoc_cmd_list :shared;
my %admin_cmd_list :shared;

my $lock = Thread::Semaphore->new();

sub resolve_filepath
{
    my ($name) = @_;
    my $dir = qr/\E$Conf::plugin_folder\Q/;
    my $file = $name;

    if ($file !~ /^.*\.pm$/) {
        $file = $file . ".pm";
    }
    if ($file !~ /^$dir/) {
        $file = $dir . $file;
    }

    if (-e $file) {
        return $file;
    }
    else {
        return "";
    }
}

sub loaded
{
    my @list;

    for my $path (keys %{$plugins}) {
        if ($path =~ /\/([^\/]*)\.pm$/) {
            push (@list, $1);
        }
    }
    return sort @list;
}
sub available
{
    my @list;

    my $dir = $Conf::plugin_folder;
    opendir(DIR, $dir) or die "can't open dir $dir: $!";
    while (defined (my $file = readdir(DIR))) {
        if ($file =~ /(.*)\.pm/) {
            push (@list, $1);
        }
    }
    closedir(DIR);

    return sort @list;
}

sub load_all
{
    my $dirname = $Conf::plugin_folder;

    # Add plugin dir and a subfolder so they won't have to specify them specially
    push (@INC, $dirname);
    push (@INC, "${dirname}Functionality");

    # try to load all files in the plugins folder
    opendir(DIR, $dirname) or die "can't open dir $dirname: $!";
    while (defined (my $file = readdir(DIR))) {
        load_file ("$dirname$file");
    }
    closedir(DIR);

    $lock->down();

    $lock->up();
}

sub unload_all
{
    $lock->down();

    while (my ($name, $plugin) = (each %{$plugins}))
    {
        my $file = resolve_filepath ($name);
        Log::plugin "Unloading $file";

        my @cmds = $plugin->cmds();
        %cmd_list = Util::remove_matches(\%cmd_list, \@cmds);

        my @undoc_cmds = $plugin->cmds();
        %undoc_cmd_list = Util::remove_matches(\%undoc_cmd_list, \@undoc_cmds);

        my @admin_cmds = $plugin->cmds();
        %admin_cmd_list = Util::remove_matches(\%admin_cmd_list, \@admin_cmds);

        $plugin->unload();
        delete $plugins->{$name};
    }
    $lock->up();
}

sub kill_all
{
    while (my ($name, $plugin) = (each %{$plugins}))
    {
        my $file = resolve_filepath ($name);
        Log::plugin ("Unloading $file without mercy!");

        $plugin->unload();
    }
}

sub reload_all
{
    unload_all();
    load_all();
}

sub load
{
    my ($name) = @_;
    my $file = resolve_filepath ($name);

    if ($file) {
        return load_file ($file);
    }
    else {
        Log::error "$name isn't a plugin.";
        return "$name isn't a plugin.";
    }
}
sub load_file
{
    my ($file) = @_;

    if ($file !~ /\/([^\/]*)\.pm$/) {
        return "We couldn't find anything loadable.";
    }
    my $name = $1;

    if (exists ($plugins->{$file})) {
        Log::error "$file already loaded";
        return "Plugin already loaded, try to reload instead.";
    }

    if (!-e $file) {
        Log::error "$file doesn't exist!";
        return "Oops $file seems to have some errors in it.";
    }

    # This reparses the file
    # do $file;
    require $file;

    if (!$name->can('new')){
        Log::error "$name doesn't have a new method, not a valid Moose class.";
        return "Oops $file seems to have some errors in it.";
    }
    my $plugin = $name->new();

    if (!$plugin->DOES('Plugin')) {
        Log::error "$file doesn't do the Plugin role!";
        return "Oops $file seems to have some errors in it.";
    }

    Log::plugin "Loading $file";

    $lock->down();

    $plugins->{$file} = share($plugin);
    $plugin->load();

    #my @cmds = $plugin->cmds();
    #for my $cmd (@cmds) {
        #if ($cmd) {
            #$cmd_list{$cmd} = 1;
        #}
    #}

    #my @undoc_cmds = $plugin->undocumented_cmds();
    #for my $cmd (@undoc_cmds) {
        #if ($cmd) {
            #$undoc_cmd_list{$cmd} = 1;
        #}
    #}

    #my @admin_cmds = $plugin->admin_cmds();
    #for my $cmd (@admin_cmds) {
        #if ($cmd) {
            #$admin_cmd_list{$cmd} = 1;
        #}
    #}

    $lock->up();

    return "$name loaded.";
}
sub unload
{
    my ($name) = @_;
    my $file = resolve_filepath ($name);

    $lock->down();
    if (defined ($plugins->{$file})) {
        Log::plugin "Unloading $file";

        my $plugin = $plugins->{$file};

        my @cmds = $plugin->cmds();
        %cmd_list = Util::remove_matches(\%cmd_list, \@cmds);

        my @undoc_cmds = $plugin->cmds();
        %undoc_cmd_list = Util::remove_matches(\%undoc_cmd_list, \@undoc_cmds);

        my @admin_cmds = $plugin->cmds();
        %admin_cmd_list = Util::remove_matches(\%admin_cmd_list, \@admin_cmds);

        $plugin->unload();
        delete $plugins->{$file};

        $lock->up();

        return "$name unloaded.";
    }

    return "Not loaded.";
}

sub reload
{
    my ($name) = @_;

    unload ($name);
    load ($name);

    return "$name reloaded.";
}

sub cmds
{
    $lock->down();
    my %l = %cmd_list;
    $lock->up();
    return %l;
}

sub undoc_cmds
{
    $lock->down();
    my %l = %undoc_cmd_list;
    $lock->up();
    return %l;
}

sub admin_cmds
{
    $lock->down();
    my %l = %admin_cmd_list;
    $lock->up();
    return %l;
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
    my ($sender, $target, $cmd, $arg) = @_;

    $lock->down();
    for my $plugin (values %{$plugins})
    {
        $plugin->process_admin_cmd ($sender, $target, $cmd, $arg);
    }
    $lock->up();
}

sub process_privmsg
{
    $lock->down();
    for my $plugin (values %{$plugins})
    {
        $plugin->process_privmsg (@_);
    }
    $lock->up();
}

sub process_irc_msg
{
    $lock->down();
    for my $plugin (values %{$plugins})
    {
        $plugin->process_irc_msg (@_);
    }
    $lock->up();
}

sub process_bare_msg
{
    $lock->down();
    for my $plugin (values %{$plugins})
    {
        $plugin->process_bare_msg (@_);
    }
    $lock->up();
}

sub get_cmd_help
{
    my @help;

    $lock->down();
    for my $plugin (values %{$plugins})
    {
        my $help = $plugin->cmd_help (@_);
        if ($help) {
            push (@help, $help);
        }
    }
    $lock->up();

    return @help;
}

sub run_tests
{
    say "Testing plugins:";

    $lock->down();
    for my $plugin (values %{$plugins})
    {
        $plugin->run_tests (@_);
    }
    $lock->up();
}

1;

