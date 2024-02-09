#!/usr/bin/env perl

use Modern::Perl 2018;
use CInet::Base;

my $cube = Cube(shift // die 'need dimension');
while (defined($_ = <<>>)) {
    my @ranks = m/(\d+)/g;
    warn 'dimension mismatch' unless @ranks == $cube->vertices;
    unshift @ranks, '?'; # make 1-based indices work.
    say join '', map {
        my ($ij, $K) = @$_;
        my $ik  = $cube->pack([ [], [$ij->[0], @$K] ]);
        my $jk  = $cube->pack([ [], [$ij->[1], @$K] ]);
        my $k   = $cube->pack([ [], [          @$K] ]);
        my $ijk = $cube->pack([ [], [@$ij,     @$K] ]);
        $ranks[$ik] + $ranks[$jk] - $ranks[$k] - $ranks[$ijk] == 0 ? '0' : '1'
    } $cube->squares;
}
