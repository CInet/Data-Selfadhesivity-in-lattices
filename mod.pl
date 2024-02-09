#!/usr/bin/env perl

use Modern::Perl 2018;
use CInet::Base;
use List::Util qw(minstr);

my $cube = Cube(shift // die 'need dimension');
my @rels = map { chomp; CInet::Relation->new($cube => $_) } <<>>;
# We want canonical representatives!
my %seen;
for (@rels) {
    next if $seen{"$_"};
    my @reps = $_->orbit(SymmetricGroup)->list;
    $seen{"$_"}++ for @reps;
    say minstr @reps;
}
