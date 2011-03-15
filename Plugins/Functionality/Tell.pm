#!/usr/bin/perl -w

use Modern::Perl;

use threads;
use threads::shared;
use Thread::Semaphore;

package Tell;

use Irc;

my %nick_tell :shared;
my %auth_tell :shared;
my $lock = Thread::Semaphore->new();

sub issue_tell
{
    my ($nick) = @_;

    $lock->down();

    #if (Irc::is_authed ($nick)) {
    if (1) {
        #my $auth_nick = Irc::authed_as ($nick);
        my $auth_nick = 'Mowah';

        if ($auth_tell{$auth_nick}) {
            for my $what (@{$auth_tell{$auth_nick}}) {
                #Irc::send_privmsg ($nick, $what);
                say $what;
            }

            delete $auth_tell{$auth_nick};
        }
    }

    if ($nick_tell{$nick}) {
        for my $what (@{$nick_tell{$nick}}) {
            #Irc::send_privmsg ($nick, $what);
            say $what;
        }

        delete $nick_tell{$nick};
    }

    $lock->up();
}

sub tell_user
{
    my $to = shift;
    my $from = shift;

    if ($from) {
        add_in_queue ($to, ("Message from $from:", @_));
    }

    # No from message is from the bot itself
    else {
        add_in_queue ($to, @_);
    }
}

sub add_in_queue
{
    my $nick = shift;
    my @what = (@_);

    $lock->down();

    #if (Irc::is_authed ($nick)) {
    if (1) {
        #my ($auth_nick) = Irc::authed_as ($nick);
        my $auth_nick = 'Mowah';

        if ($auth_tell{$auth_nick}) {
            my @tell :shared;
            @tell = (@{$auth_tell{$auth_nick}}, @what);
            $auth_tell{$auth_nick} = \@tell;
        }
        else {
            my @tell :shared;
            @tell = @what;
            $auth_tell{$auth_nick} = \@tell;
        }
    }
    else {
        if ($nick_tell{$nick}) {
            my @tell :shared;
            @tell = (@{$nick_tell{$nick}}, @what);
            $nick_tell{$nick} = \@tell;
        }
        else {
            my @tell :shared;
            @tell = @what;
            $nick_tell{$nick} = \@tell;
        }
    }

    $lock->up();
}

1;

