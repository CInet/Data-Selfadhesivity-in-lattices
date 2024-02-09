#!/usr/bin/env perl

use Modern::Perl 2018;
use CInet::Base;

sub rep { CInet::Relation->new(@_)->representative(SymmetricGroup) }

my $cube = Cube(shift // die 'need dimension');
my %reps = map { ("$_" => $_) } map rep($cube => $_), <<>>;

# Report all orbit representatives whose dual is not in the set.
for (sort keys %reps) {
    my $A = $reps{$_};
    my $B = $A->dual->representative(SymmetricGroup);
    say "$A" if not exists $reps{"$B"};
}
