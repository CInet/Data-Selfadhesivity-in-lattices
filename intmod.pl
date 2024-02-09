#!/usr/bin/env perl

use Modern::Perl 2018;
use CInet::Base;
use Path::Tiny qw(path);
use List::Util qw(uniqstr);
use Array::Set qw(set_intersect);

sub rep { CInet::Relation->new(@_)->representative(SymmetricGroup) }

my $cube = Cube(shift // die 'need dimension');
my @models1 = uniqstr map "". rep($cube => $_), path(shift // die 'need file 1')->lines({ chomp => 1 });
my @models2 = uniqstr map "". rep($cube => $_), path(shift // die 'need file 2')->lines({ chomp => 1 });
say for set_intersect(\@models1, \@models2)->@*;
