#!/usr/bin/env perl

use Modern::Perl 2018;
use Getopt::Long qw(:config no_ignore_case bundling);

use CInet::Base;
use CInet::ManySAT;
use CInet::ManySAT::Incremental;
use CInet::Propositional;
use CInet::Semimatroids;
use CInet::Adhesive;

GetOptions(
    "intersection" => \my $intersection,
    "composition"  => \my $composition,
    "structural"   => \my $structural,
    "selfadhesive" => \my $selfadhesive,
) or die 'failed parsing arguments';

propositional Semigraphoids = cube(ijk|L) ::
    (ij|L)  & (ik|jL) => (ik|L)  & (ij|kL);

propositional Intersection = cube(ijk|L) ::
    (ij|kL) & (ik|jL) => (ij|L)  & (ik|L);

propositional Composition = cube(ijk|L) ::
    (ij|L)  & (ik|L)  => (ij|kL) & (ik|jL);

use CInet::Hash::FaceKey;
tie my %SOLVERS, 'CInet::Hash::FaceKey';
sub solver {
    my $cube = shift;
    $SOLVERS{[ $cube->set, [] ]} //=
        CInet::ManySAT::Incremental->new->read([
            Semigraphoids($cube)->axioms->@*,
            $intersection ? Intersection($cube)->axioms->@* : (),
            $composition  ? Composition($cube)->axioms->@*  : (),
        ])
}

sub to_assump {
    my $A = shift;
    my $cube = $A->cube;
    [ map { $A->cival($_) eq 0 ?  $cube->pack($_) :
            $A->cival($_) eq 1 ? -$cube->pack($_) : () } $cube->squares ]
}

sub is_basetype {
    my $A = shift;
    defined solver($A->cube)->model(to_assump($A))
}

my $filter = do {
    my $filter = $structural ? \&is_semimatroid : \&is_basetype;
    $selfadhesive ? sub{ is_selfadhesive(shift, $filter) } : $filter
};

# Applying $filter may be extremely expensive. It is better to reduce
# modulo symmetry and inflate the representatives again afterwards,
# using that all properties checked by $filter are invariant.
my @reps = Semigraphoids(shift // die 'need dimension')
  -> modulo(SymmetricGroup)
  -> grep($filter)
  -> list;

for (@reps) {
    say for $_->orbit(SymmetricGroup)->uniq->list;
}
