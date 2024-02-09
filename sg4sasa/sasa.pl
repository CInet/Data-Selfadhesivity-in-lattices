#!/usr/bin/env perl

use Modern::Perl 2018;
use Getopt::Long qw(:config no_ignore_case bundling);

use CInet::Base;
use CInet::ManySAT;
use CInet::ManySAT::Incremental;
use CInet::Propositional;

use Path::Tiny;
use Array::Set qw(set_intersect set_diff);
use Algorithm::Combinatorics qw(subsets);

propositional Semigraphoids = cube(ijk|L) ::
    (ij|L)  & (ik|jL) => (ik|L)  & (ij|kL);

# This will only work for semigraphoids on a 4-element ground set.
# We use uppercase letters for the ground set elements and lowercase
# equivalents for their initial copies. For the second level or copies,
# we attach apostrophes.
my $cube = Cube(['A', 'B', 'C', 'D']);
my $N = $cube->set;

# Incremental SAT solvers with the semigraphoid axioms preloaded.
my %SOLVERS;
sub solver {
    my $cube = shift;
    $SOLVERS{join('#', $cube->set->@*)} //=
        CInet::ManySAT::Incremental->new->read(Semigraphoids($cube)->axioms)
}

sub to_assump {
    my $A = shift;
    my $cube = $A->cube;
    [ map { $A->cival($_) eq 0 ?  $cube->pack($_) :
            $A->cival($_) eq 1 ? -$cube->pack($_) : () } $cube->squares ]
}

sub is_semigraphoid {
    my $A = shift;
    defined solver($A->cube)->model(to_assump($A))
}

# For the procedure below, we require selfadhesive semigraphoids
# as input. User can supply the file and otherwise we compute them
# from scratch.
my $sg4sa_file = shift;
my @input;
if (defined $sg4sa_file) {
    warn "The sg4sa/all file name is not as expected."
        unless path($sg4sa_file)->realpath =~ m|sg4sa/all$|;
    print STDERR 'Reducing selfadhesive semigraphoids modulo symmetry... ';
    @input = CInet::Seq::List->new(
        map CInet::Relation->new($cube => $_), path($sg4sa_file)->lines({ chomp => 1 })
    ) -> modulo(SymmetricGroup)
      -> list;
}
else {
    use CInet::Adhesive;
    print STDERR 'Computing selfadhesive semigraphoids up to symmetry... ';
    @input = Semigraphoids($cube)
      -> modulo(SymmetricGroup)
      -> grep(sub{ is_selfadhesive(shift, \&is_semigraphoid) })
      -> list;
}
say STDERR 0+ @input;

# Values of this function are suitable for CInet::Relation->act.
sub lift_permutation {
    my ($cube, $p) = @_;
    [ map { $cube->pack($cube->permute($p => $_)) } $cube->squares ]
}

# Return an involution that maps the first k = |A| elements of N to
# the set A. If the size-k initial segment of N overlaps with A, then
# those elements are fixed. All other elements of N are also fixed.
# The permutation defined in this way is a product of disjoint 2-cycles
# and therefore an involution.
#
# For example, N = [1,2,3,4] and A = [1,2] results in the identity.
# N = [1,2,3,4] and A = [2,3] results in [3,2,1,4].
my %INVOLUTIONS;
sub involution {
    my ($N, $A) = @_;
    $INVOLUTIONS{join('#', sort @$N) . '>' . join('#', sort @$A)} //= do {
        my $B = [ $N->@[0 .. @$A-1] ];
        # The goal is to map $B->[i] to $A->[i] in order, but elements in
        # the intersection should also be fixed points. Since we make all
        # points outside of $B fixed points, we can achieve this by taking
        # the intersection of $A and $B out of both of these sets. After-
        # wards we simply want to map $B->[i] to $A->[i] in order.
        my $C = set_intersect($A, $B);
        $A = set_diff($A, $C);
        $B = set_diff($B, $C);

        my $lut = do {
            my $i = 0;
            +{ map { ($_ => $i++) } @$N }
        };

        my $p = [ @$N ]; # identity permutation
        for my $i (0 .. $B->$#*) {
            # Add a 2-cycle.
            $p->[ $lut->{ $B->[$i] } ] = $A->[$i];
            $p->[ $lut->{ $A->[$i] } ] = $B->[$i];
        }
        lift_permutation(Cube($N) => $p)
    }
}

# Given a CI structure $A over $N and an integer 0 <= $k <= $A->cube->dim,
# let $K = the first $k elements of $N. First compute a cube which contains
# $N and a $K-copy $M of $N. Then define a partial CI structure on the
# larger cube by including $A, its copy on $M and the CI statements for
# [$N _||_ $M | $K].
sub adhesive_extension {
    my ($A, $k) = @_;
    my $Ncube = $A->cube;
    my $N = $Ncube->set;
    my $K = [ $N->@[0 .. $k-1] ];

    # Compute the extended cube.
    my $L = set_diff($N, $K);
    my $NMcube = Cube([ @$N, map { "$_'" } @$L ]);
    my $NM = $NMcube->set;

    my %map = (
        map({ $_ => "$_"  } @$K),
        map({ $_ => "$_'" } @$L),
    );

    my $B = '1' x $NMcube->squares;
    # Restrictions to $N and $M must be $A.
    for my $ijK ($Ncube->squares) {
        my $x = $NMcube->pack($ijK);
        my $y = $NMcube->pack([ map { [ map $map{$_}, @$_ ] } @$ijK ]);
        my $c = $A->cival($ijK);
        substr($B, $x-1, 1, $c);
        substr($B, $y-1, 1, $c);
    }
    # $N and $M must be independent given $K.
    for my $x (@$L) {
        for my $y (@map{@$L}) {
            for my $Z (subsets(set_diff($NM, [ $x, $y, @$K ]))) {
                substr($B, $NMcube->pack([ [$x,$y], [@$Z, @$K] ])-1, 1, 0);
            }
        }
    }
    CInet::Relation->new($NMcube => $B)
}

# Restrict a given CI structure to a subset of its ground set.
# Caches the indices based on the pair of cubes.
my %RESTRICT_INDICES;
sub restrict_indices {
    my ($NMcube, $Ncube) = @_;
    my $key = join('#', $NMcube->set->@*) . '>' . join('#', $Ncube->set);
    $RESTRICT_INDICES{$key} //= [ map { $NMcube->pack($_)-1 } $Ncube->squares ]
}

sub restrict {
    my ($A, $Ncube) = @_;
    my $NMcube = $A->cube;
    my $idx = restrict_indices($NMcube, $Ncube);
    my @s = split //, "$A";
    CInet::Relation->new($Ncube => join('', @s[@$idx]))
}

# Given a CI structure $A over $N and an integer 0 <= $k <= $A->cube->dim
# with the same interpretation and notation as in adhesive_extension.
# Also compute the extended cube, then a SAT solver preloaded with the
# semigraphoid axioms on the larger cube, the axioms that the restrictions
# of $N and $M should agree and the independences [$N _||_ $M | $K].
# Then compute the closure of $A on its original ground set $N under
# these axioms and return this CI structure.
my %ADHESIVE_SOLVERS;
sub adhesive_closure_at {
    my ($A, $k) = @_;
    my $Ncube = $A->cube;
    my $N = $Ncube->set;
    my $K = [ $N->@[0 .. $k-1] ];

    # Compute the extended cube. Note that unlike adhesive_extension
    # we use the suffix '^' for non-shared elements to keep the two
    # stages of extension apart.
    my $L = set_diff($N, $K);
    my $NMcube = Cube([ @$N, map { "$_^" } @$L ]);
    my $NM = $NMcube->set;

    my %map = (
        map({ $_ => "$_"  } @$K),
        map({ $_ => "$_^" } @$L),
    );

    my $solver = $ADHESIVE_SOLVERS{join('#', @$NM)} //= do {
        # Initialize with semigraphoid axioms.
        my $solver = CInet::ManySAT::Incremental->new->read(Semigraphoids($NMcube)->axioms);
        # Restrictions to $N and $M must coincide.
        for my $ijK ($Ncube->squares) {
            my $x = $NMcube->pack($ijK);
            my $y = $NMcube->pack([ map { [ map $map{$_}, @$_ ] } @$ijK ]);
            $solver->add([ -$x,  $y ]);
            $solver->add([  $x, -$y ]);
        }
        # $N and $M must be independent given $K.
        for my $x (@$L) {
            for my $y (@map{@$L}) {
                for my $Z (subsets(set_diff($NM, [ $x, $y, @$K ]))) {
                    $solver->add([ $NMcube->pack([ [$x,$y], [@$Z, @$K] ]) ]);
                }
            }
        }
        $solver
    };

    # Compute the closure of the extension of $A to $NMcube with the
    # additional adhesion axioms. From the closure, we only need the
    # restriction to $N.
    my @vars = map { $_+1 } restrict_indices($NMcube, $Ncube)->@*;
    # Can't use to_assump($A) because we need the variable ordering
    # from $NMcube. We add an extra 0 which is switched out for all
    # possible closure elements below.
    my $assump = [ map({ +$NMcube->pack($_) } $A->independences) ];
    push @$assump, 0;
    # Compute the closure by repeated SAT solver invocations.
    my $cl = "$A";
    for my $ijK ($A->dependences) {
        my $x = $Ncube->pack($ijK);
        my $y = $vars[$x-1]; # the number of $x relative to $NMcube
        # If non-$ijK is impossible, then it must be in the closure.
        # Otherwise we leave it undefined.
        $assump->[-1] = -$y;
        substr($cl, $x-1, 1, 0) if not defined $solver->model($assump);
    }
    CInet::Relation->new($Ncube => $cl)
}

my @models;
CANDIDATE: for my $A (@input) {
    print STDERR "[@{[ ''. localtime ]}] $A ";
    for my $k (2 .. @$N-1) {
        my %cache; # cache for permuted $Ap
        for my $K (subsets($N, $k)) {
            print STDERR "[@{[ join('', sort @$K) ]}: ";
            my $p = involution($N, $K);
            my $Ap = $A->act($p);
            if ($cache{"$Ap"}++) {
                print STDERR "0] "; # skip
                next;
            }

            my $B = adhesive_extension($Ap, $k);
            my $NM = $B->cube->set;
            # Compute the closure of $B in selfadhesive semigraphoids.
            # If the restriction to $N adds elements to $A at any point,
            # $A is not second-order selfadhesive.
            my $cycles = 0;
            CLOSURE_LOOP: while (1) {
                $cycles++;
                for my $l (2 .. @$NM-2) {
                    for my $L (subsets($NM, $l)) {
                        my $q = involution($NM, $L);
                        my $Bq = $B->act($q);

                        my $C = adhesive_closure_at($Bq, $l)->invact($q);
                        # $C is a superset of $B and therefore restricts
                        # on $N to a superset of $Ap. If it adds new
                        # elements to $Ap, then $A is not closed in the
                        # lattice of second-order selfadhesive semigraphoids.
                        # We fail immediately.
                        my $Cm = restrict($C, $cube);
                        if ("$Ap" ne "$Cm") {
                            say STDERR "$cycles+] FAIL"; # failed
                            next CANDIDATE;
                        }
                        # If $C adds more elements to $B, add them and
                        # restart the closure loop with larger $B.
                        if ("$B" ne "$C") {
                            $B = $C;
                            next CLOSURE_LOOP;
                        }
                    }
                }
                # We escape the "infinite" closure loop as soon as we
                # don't restart it for the first time in the inner loop.
                # In this case, the closure of $B is completely computed
                # and doesn't add elements to $A.
                last;
            }
            print STDERR "$cycles] "; # report closure cycles
        }
    }

    # All tests passed: $A is second-order selfadhesive!
    say STDERR "PASS";
    push @models, $A;
}

say STDERR "Finished! @{[ 0+ @models ]} models passed.";
say "$_" for @models;
