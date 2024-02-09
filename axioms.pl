#!/usr/bin/env perl

use Modern::Perl 2018;
use bignum lib => 'GMP';

use CInet::Base;
use CInet::ManySAT;

use Getopt::Long;
use Path::Tiny;
use List::Util qw(reduce);

# Given a CNF f defining a Moore family F and a listing of a subfamily
# F' of F, compute the pseudo-closed sets for F' which are closed in F.
# These yield a canonical implication basis for F' with respect to F.
# By default f is empty and F is the set of all CI structures.

GetOptions(
    # The default is to emit axioms. We can also emit pseudo-closed elements.
    'pseudo-closed' => \my $emit_pseudo_closed,
) or die 'failed parsing options';

my $cube = Cube(shift // die 'need dimension');
my $group = SymmetricGroup($cube);

sub to_binary   { 0+ "0b@{[ shift ]}" }
sub to_binstr   { sprintf("%0*s", 0+ $cube->squares, shift) }
sub to_relation { CInet::Relation->new($cube => to_binstr shift) }

# In our bit vector encoding of a CI structure (where a 0 bit means
# that a CI statement is INSIDE the structure), bitwise OR corresponds
# to intersection.
sub intersect { reduce { $a | $b } 0, @_ }
sub is_subset { ($_[0] | $_[1]) == $_[0] }

# Closed sets of F' are given as a list and converted to a pair of
# CInet::Relation and bit vector. The latter is used to compute the
# closure (intersection of all supersets in %closed) of a given
# structure using fast bitwise operations.
my %closed = map { ($_ => [ to_relation($_), to_binary($_) ]) }
    path(shift // die 'need closed sets')->lines({ chomp => 1 });

my $cnf = CInet::ManySAT->new;
my $cnf_file = shift;
$cnf->read($cnf_file) if defined $cnf_file;

# Compute the closure of $A by intersecting all supersets in F'.
sub moore_closure {
    my $s = to_binary(shift);
    my $x = intersect(grep is_subset($s, $_), map $_->[1], values %closed);
    to_relation($x->to_bin)
}

sub to_assump {
    [ map { $cube->pack($_) } shift->independences ]
}

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

# CInet::Seq which enumerates all CI structures by cardinality and up to
# isomorphy.
package CInet::Seq::Relations {
    use Role::Tiny::With;
    with 'CInet::Seq';

    use Algorithm::Combinatorics qw(subsets);

    sub _make_seq {
        my ($cube, $group, $m) = @_;
        CInet::Seq::List->new(my @a = subsets([ 0 .. $cube->squares - 1], $m))
          -> map(sub{
                my $x = '1' x $cube->squares;
                substr($x, $_, 1, '0') for @$_;
                CInet::Relation->new($cube => $x)
          })
          -> modulo($group)
    }

    sub new {
        my $class = shift;
        my ($cube, $group) = @_;
        my $seq = _make_seq($cube, $group, 0);
        bless { cube => $cube, group => $group, m => 0, seq => $seq }, $class
    }

    sub next {
        my $self = shift;
        my $next = $self->{seq}->next;
        return $next if defined $next;
        return undef if ++$self->{m} > $self->{cube}->squares;
        $self->{seq} = _make_seq($self->@{'cube', 'group', 'm'});
        $self->next
    }
};

# Candidates are orbit representatives of the sets satisfying the initial
# formula in $cnf and they must be ordered by cardinality. If a formula is
# given, we assume that it is feasible to enumerate all assignments for
# symmetry reduction and sorting. Otherwise, we lazily generate the sorted
# sequence of all relations by cardinality more directly.
my $candidates = do {
    if (defined $cnf_file) {
        CInet::Seq::ManySAT->new($cnf->all)
          -> map(sub{ to_relation(join '', map { $_ < 0 ? '1' : '0' } @$_) })
          -> modulo(SymmetricGroup)
          -> sort(by => sub{ 0+ $_->independences })
    }
    else {
        CInet::Seq::Relations->new($cube, SymmetricGroup)
    }
};

# Pseudo-closed elements are stored as pairs [ $p, $pcl ] where $p is the
# pseudo-closed element and $pcl its moore_closure. Both are stored as bit
# vectors because the algorithms consuming them work with those.
my %pseudo_closed;

sub is_pseudo_closed {
    my $c = shift;
    return 0 if exists $closed{to_binstr $c->to_bin};
    for (values %pseudo_closed) {
        my ($p, $pcl) = @$_;
        next unless is_subset($p, $c);
        return 0 if not is_subset($pcl, $c);
    }
    return 1;
}

sub add_pseudo_closed {
    my ($C, $Ccl) = @_;
    my $c = to_binary($C);
    $pseudo_closed{to_binstr $c->to_bin} //= [ $c, to_binary($Ccl) ]
}

# This program deals with Moore families, which can be axiomatized by
# closure operators defined by Horn clauses. A closure axiom is thus
# represented as a pair of antecedents and consequences: the antecedents
# imply ALL of the consequences simultaneously. (This is unlike a general
# CNF clause where at least one of the consequences is implied.)
sub closure_axiom {
    my ($C, $Ccl) = @_;
    my @ante = $C->independences;
    my @cons = grep { $C->cival($_) ne 0 } $Ccl->independences;
    [ [ @ante ], [ @cons ] ]
}

sub add_axiom {
    my ($ante, $cons) = shift->@*;
    my $clause = [ map({ -$cube->pack($_) } @$ante), 0 ]; # the 0 is changed in the loop below
    for (@$cons) {
        $clause->[-1] = $cube->pack($_);
        $cnf->add([ @$clause ]);
    }
}

sub fmt_axiom {
    my ($ante, $cons) = shift->@*;
    join(' & ', map FACE, @$ante) . ' => ' . join(' & ', map FACE, @$cons)
}

my $target_count = keys %closed;
while (defined(my $C = $candidates->next)) {
    my $c = to_binary($C);
    next unless is_pseudo_closed($c);

    # We iterate over the orbit of $C and $Ccl below. Since the $candidates
    # are not canonical (->modulo($group) returns the first representative
    # seen in the input list), we use this chance to get canonical axioms
    # printed: we want the smallest $c lexicographically, which corresponds
    # to having as many as possible, as low as possible (12|K) antecedents.
    my ($smallest, $theaxiom) = ("$C", [ [], [] ]);
    my $Ccl = moore_closure($C);
    for (@$group) {
        my $D = $C->act($_);
        my $Dcl = $Ccl->act($_);
        add_pseudo_closed($D => $Dcl);
        add_axiom(my $axiom = closure_axiom($D => $Dcl));
        if ("$D" le $smallest) {
            $smallest = "$D";
            $theaxiom = $axiom;
        }
    }
    say STDERR fmt_axiom($theaxiom)
        unless $emit_pseudo_closed;

    last if $cnf->count == $target_count;
}

if ($emit_pseudo_closed) {
    say for keys %pseudo_closed;
}
else {
    my $dimacs = $cnf->dimacs;
    while (defined(my $line = $dimacs->())) {
        print $line;
    }
}
