#!/usr/bin/env perl

use v5.10;

while (<>) {
    chomp;
    if (/^\d+ extreme rays:/ .. /^$/) {
        next unless (state $skip)++ && length;
        say s/^\s+|\s+$//r;
    }
}
