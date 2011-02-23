#!/usr/bin/perl

use Modern::Perl;

my $curr = time;
my $passed = $curr - time;

my @parts = gmtime($passed);
my ($d, $h, $m, $s) = @parts[7, 2, 1, 0];
my $msg = "Uptime: ${d}d ${h}h ${m}m ${s}s";
say $msg;

my @cmds = qw(hej da prutt);
local $, = ", ";
say @cmds;

my $str = ":(";

$str = join(", ", @cmds);

say $str;

say "hej " . "pew";

use Config;
    $Config{useithreads} or die('Recompile Perl with threads to run this program.');

use threads;
use threads::shared;
use Thread::Queue;

my $queue = Thread::Queue->new();
my $thr = threads->create(sub {
    while (my $e = $queue->dequeue()) {
        say "Popped $e off the queue";
    }
});

$queue->enqueue(12);
$queue->enqueue("A", "B", "C");
#sleep(1);
$queue->enqueue(undef);
$thr->join();

use Thread::Semaphore;

my $semaphore = Thread::Semaphore->new();
my $v :shared = 0;

#my $thr1 = threads->create(\&sample, 1);
#my $thr2 = threads->create(\&sample, 2);
#my $thr3 = threads->create(\&sample, 3);

sub sample {
    my $num = shift(@_);
    my $try = 10;
    my $copy;
    sleep(1);
    while ($try--) {
        $semaphore->down();
        $copy = $v;
        say "$try tries left for $num (\$v is $v)";
        sleep(2);
        $copy++;
        $v = $copy;
        $semaphore->up();
    }
}

#$thr1->join();
#$thr2->join();
#$thr3->join();

my @my_hooks;

sub f1 { say "f1"; }
sub f2 { say "f2"; }
sub f3 { say "f3"; }

push (@my_hooks, 1, \&f1);
push (@my_hooks, 2, \&f2);
push (@my_hooks, 3, \&f3);

sub do_hook
{
    my ($arg) = @_;

    for (my $i = 0; $i < scalar @my_hooks; $i += 2) {
        if ($my_hooks[$i] == $arg) {
            my $id = $my_hooks[$i];
            my $f = $my_hooks[$i + 1];

            $f->();

            @my_hooks = splice( @my_hooks, $i, 2 );
        }
    }
}

do_hook( 2 );
#do_hook();
#do_hook();

length(@my_hooks);

