#!/bin/bash

normaliz st5/nsupmod
perl st5/extreme-rays.pl st5/nsupmod.out | perl st5/to-relation.pl 5 >st5/coatoms
perl mod.pl 5 <st5/coatoms | perl test.pl 5 --selfadhesive | perl unmod.pl 5 >st5/coatoms-sg5sa
