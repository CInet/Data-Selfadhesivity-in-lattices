#!/bin/bash

perl linrays5/linrays5.pl | perl st5/to-relation.pl 5 | perl mod.pl 5 >linrays5/coatoms
cat st5/coatoms-st5sa | perl mod.pl 5 | while read S; do grep -qe "$S" linrays5/coatoms || echo "$S"; done >linrays5/undecided
