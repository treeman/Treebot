#!/usr/bin/perl

use Modern::Perl;
use Test::More;

use MooseX::Declare;
use Plugin;

class ac extends DefaultPlugin
{
    has 'name', is => 'ro', default => 'ac';
}

1;

