#!/bin/bash

echo "Lattice data:"
echo "Family All Types Coatoms Types Irreducibles Types Axioms" >>table.in
for fam in sg4 sg4sa csg4 csg4sa gr4 gr4sa cgr4 cgr4sa st4 st4sa;
do echo $fam $(cat $fam/all | wc -l) $(perl mod.pl 4 $fam/all | wc -l) $(cat $fam/coatoms | wc -l) $(perl mod.pl 4 $fam/coatoms | wc -l) $(cat $fam/irred | wc -l) $(perl mod.pl 4 $fam/irred | wc -l) $(head -1 $fam/cnf | cut -d' ' -f4) >>table.in
done
column -t table.in && rm table.in
echo

echo "Coatoms of st(5) which are sg^\\sa(5) or st^\\sa(5):"
echo "Coatoms Types sg^\\sa(5) Types st^\\sa(5) Types" >>table.in
echo $(cat st5/coatoms | wc -l) $(perl mod.pl 5 st5/coatoms | wc -l) $(cat st5/coatoms-sg5sa | wc -l) $(perl mod.pl 5 st5/coatoms-sg5sa | wc -l) $(cat st5/coatoms-st5sa | wc -l) $(perl mod.pl 5 st5/coatoms-st5sa | wc -l) >>table.in
column -t table.in && rm table.in
echo

echo "Second-order selfadhesion of sg(4):"
echo "pr(4) sg^\\sa\\sa(4) sg^\\sa(4) sg(4)" >>table.in
echo $(cat pr4/all | wc -l) $(cat sg4sasa/all | wc -l) $(cat sg4sa/all | wc -l) $(cat sg4/all | wc -l) >>table.in
column -t table.in && rm table.in
echo

echo "Dual types not contained in family:"
echo "Family Types Non-dual" >>table.in
for fam in sg4 sg4sa csg4 csg4sa gr4 gr4sa cgr4 cgr4sa st4 st4sa pr4;
do echo $fam $(perl mod.pl 4 $fam/all | wc -l) $(perl check-duals.pl 4 $fam/all | wc -l) >>table.in
done
column -t table.in && rm table.in
echo
