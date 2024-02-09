#!/usr/bin/env perl

use Modern::Perl 2018;
use CInet::Base;

my $cube = Cube(shift // die 'need dimension');
my %seen;
while (<<>>) {
    chomp;
    my $A = CInet::Relation->new($cube => $_);
    next if $seen{"$A"};
    for my $B ($A->orbit(SymmetricGroup)->uniq->list) {
        $seen{"$B"}++;
        say "$B";
    }
}
