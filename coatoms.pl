#!/usr/bin/env perl

use Modern::Perl 2018;

use CInet::Base;
use CInet::ManySAT;

# This program takes a CNF formula describing a Moore family and uses
# SAT solvers to find the coatoms of this lattice. They are precisely
# those sets where adding a single element outside of them causes the
# closure operator to imply all other elements. This is easy to write
# down as SAT clauses.

my $cube = Cube(shift // die 'need dimension');

sub to_binstr   { sprintf("%0*s", 0+ $cube->squares, shift) }
sub to_relation { CInet::Relation->new($cube => to_binstr shift) }

# Wrapper for a CInet::ManySAT::All to work with all the stream processing
# features from CInet.
package CInet::Seq::ManySAT {
    use Role::Tiny::With;
    with 'CInet::Seq';

    sub new {
        my $class = shift;
        bless [ @_ ], $class
    }

    sub next {
        $_[0]->[0]->next
    }
};

my $cnf_file = shift // die 'need cnf file';
my $cnf = CInet::ManySAT->new->read($cnf_file);

sub is_coatom {
    my $A = shift;
    my $solver = CInet::ManySAT->new->read($cnf_file);
    my @indep = map { $cube->pack($_) } $A->independences;
    my @dep =   map { $cube->pack($_) } $A->dependences;
    return 0 unless @dep;

    $solver->add([ $_ ]) for @indep;
    $solver->add([ @dep ]);
    $solver->add([ map { -$_ } @dep ]);
    not defined $solver->model
}

my @reps = CInet::Seq::ManySAT->new($cnf->all)
  -> map(sub{ to_relation(join '', map { $_ < 0 ? '1' : '0' } @$_) })
  -> modulo(SymmetricGroup)
  -> grep(\&is_coatom)
  -> list;

for (@reps) {
    say for $_->orbit(SymmetricGroup)->uniq->list;
}
