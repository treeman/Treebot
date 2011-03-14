#!/usr/bin/perl -w

use Modern::Perl;

package StoreHash;

use Carp;

sub store
{
    my ($name, %h) = @_;

    my $file = "info/$name";

    open my $fh, '>', $file or croak "Couldn't open file: $file";

    for my $key (sort keys %h) {
        print $fh "$key: $h{$key}\n";
    }

    close $fh;
}

sub retrieve
{
    my ($name) = @_;

    my $file = "info/$name";

    my %h;
    if (-e $file) {
        open my $fh, '<', $file or croak "Couldn't open file: $file";

        while (<$fh>) {
            $_ =~ /^([^:]+):\s*(.*)/;

            $h{$1} = $2;
        }

        close $fh;
    }
    else {
        say "Couldn't find file: $file";
    }

    return %h;
}

1;

