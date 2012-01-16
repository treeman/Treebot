#!/usr/local/bin/perl -w

use utf8;
use locale;

use Modern::Perl;
use MooseX::Declare;

# The look of our default plugin, see DefaultPlugin for descriptions
role Plugin
{
    requires qw(
        load
        cmds
        undoc_cmds
        admin_cmds
        process_cmd
        process_admin_cmd
        process_privmsg
        process_irc_msg
        cmd_help);
}

class DefaultPlugin with Plugin
{
    # At startup
    method load () { }

    # Return list of commands the plugin listens to
    method cmds () { return (); }
    method undoc_cmds () { return (); }
    method admin_cmds () { return (); }

    # Capture command
    method process_cmd ($sender, $target, $cmd, $rest) { }
    method process_admin_cmd ($sender, $target, $cmd, $rest) { }

    # Capture regular message
    method process_privmsg ($sender, $target, $msg) { }

    # Caputer standard irc message from server
    method process_irc_msg ($prefix, $cmd, $param) { }

    # Should return a help message for every command the module defines
    method cmd_help ($cmd) { return ""; }
}

package Plugin;

use Carp;

# One instance of every available plugin
my %plugins;

# Lists of all available commands
my %cmds;
my %undoc_cmds;
my %admin_cmds;

# Load all working plugins within plugin folder
sub load_plugins
{
    my $dirname = "plugins/";

    # We can load directly from plugins folder
    push (@INC, $dirname);

    opendir (DIR, $dirname) or croak ("cannot open dir $dirname: $!");
    while (defined (my $file = readdir(DIR)))
    {
        $file = "$dirname$file";

        # Only look at perl module files
        if ($file !~ /\/([^\/]+)\.pm$/) {
            next;
        }
        my $class = $1;

        # Parse the file
        require $file;

        # Check if the class is a Moose class
        if (!$class->can('new')) {
            Log::error ("$class doesn't have a new method, not a valid Moose class?");
            next;
        }

        # Create the class
        my $plugin = $class->new();

        # Check so the class does the Plugin role
        if (!$plugin->DOES('Plugin')) {
            Log::error ("$class doesn't do the Plugin role!");
            next;
        }

        # Let the plugin set itself up, where nice here
        $plugin->load();

        # Update available commands
        map { $cmds{$_} = 1; } $plugin->cmds();
        map { $undoc_cmds{$_} = 1; } $plugin->undoc_cmds();
        map { $admin_cmds{$_} = 1; } $plugin->admin_cmds();

        # Add in our loaded plugin
        $plugins{$class} = $plugin;

        Log::plugin ("$class loaded.");
    }
    closedir (DIR);
}

# Shorthands for calling methods from every plugin
sub process_irc_msg { process ('process_irc_msg', @_); }
sub process_privmsg { process ('process_privmsg', @_); }
sub process_cmd { process ('process_cmd', @_); }
sub process_admin_cmd { process ('process_admin_cmd', @_); }

# Call every plugin with specified command name
sub process
{
    my $sub = shift @_;

    for my $plugin (values %plugins) {
        $plugin->$sub (@_);
    }
}

# Return available commands
sub cmds { return %cmds; }
sub undoc_cmds { return %undoc_cmds; }
sub admin_cmds { return %admin_cmds; }

# Return a list of help messages from specified command
sub get_cmd_help
{
    my @help;

    for my $plugin (values %plugins) {
        my $help = $plugin->cmd_help (@_);
        if ($help) {
            push (@help, $help);
        }
    }

    return @help;
}

1;

