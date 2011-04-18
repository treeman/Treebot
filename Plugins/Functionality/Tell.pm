#!/usr/bin/perl -w

use utf8;
use locale;

use Modern::Perl;

use threads;
use threads::shared;
use Thread::Semaphore;

package Tell;

use Irc;

my %nick_tell :shared;
my %auth_tell :shared;
my $lock = Thread::Semaphore->new();

sub shift_tell
{
    my ($nick, $auth_nick) = @_;

    my @msgs;

    $lock->down();

    if ($nick_tell{$nick}) {
        for my $what (@{$nick_tell{$nick}}) {
            push (@msgs, $what);
        }
        delete $nick_tell{$nick};
    }

    if ($auth_nick && $auth_tell{$auth_nick}) {
        for my $what (@{$auth_tell{$auth_nick}}) {
            push (@msgs, $what);
        }
        delete $auth_tell{$auth_nick};
    }

    $lock->up();

    return @msgs;
}

# Actually send irc messages
sub issue_tell
{
    my ($nick) = @_;

    if (Irc::is_online ($nick)) {
        map { Irc::send_privmsg ($nick, $_); }
            Tell::shift_tell ($nick, Irc::authed_as ($nick));
    }
}

sub tell_user_from
{
    my $to = shift;
    my $from = shift;

    if ($from) {
        tell_user ($to, "Message from $from:", @_);
    }
    # Might happen if we tell through stdin
    else {
        tell_user ($to, @_);
    }
}

sub tell_user
{
    my $nick = shift;
    add_in_queue (\%nick_tell, $nick, @_);
}

sub tell_auth_from
{
    my $to = shift;
    my $from = shift;
    tell_auth ($to, "Message from $from:", @_);
}

sub tell_auth
{
    my $auth = shift;
    add_in_queue (\%auth_tell, $auth, @_);
}

sub add_in_queue
{
    my $tells = shift;
    my $nick = shift;
    my @what = (@_);

    $lock->down();

    if ($$tells{$nick}) {
        my @tell :shared;
        @tell = (@{$$tells{$nick}}, @what);
        $$tells{$nick} = \@tell;
    }
    else {
        my @tell :shared;
        @tell = @what;
        $$tells{$nick} = \@tell;
    }

    $lock->up();
}

1;

