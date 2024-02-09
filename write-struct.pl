#!/usr/bin/env perl

use Modern::Perl 2018;
use CInet::Base;

my $n = shift // die 'need dimension';
my $cube = Cube([map { chr(ord("a") + $_) } 0 .. $n-1]);
while (<<>>) {
    chomp;
    my $A = CInet::Relation->new($cube => $_);
    say '{ ', join(', ', map FACE, $A->independences), ' }';
}
