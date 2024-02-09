#!/bin/bash

outdir="$1"
if [[ -z "$outdir" ]]
then echo "need output directory name" >&2 && exit
fi

# Derive switches for gen.pl from the directory name.
if [[ "$outdir" =~ ^c ]]
then flags="$flags --composition"
fi

if [[ "$outdir" =~ .*gr.* ]]
then flags="$flags --intersection"
fi

if [[ "$outdir" =~ ^st ]]
then flags="$flags --structural"
fi

if [[ "$outdir" =~ sa$ ]]
then flags="$flags --selfadhesive"
fi

# If this is the selfadhesion of a property that was already computed,
# use its CNF in the axioms.pl invocation below.
basedir=${outdir%sa}
if [[ "$outdir" =~ sa$ && -f "$basedir/cnf" ]]
then cnfarg="$basedir/cnf"
else cnfarg=""
fi

echo "Working on $outdir..."
mkdir -p "$outdir"

echo -n "Enumerating family... "
perl gen.pl $flags 4 | sort >"$outdir/all" && echo "OK"

echo -n "Deriving axioms... "
perl axioms.pl 4 "$outdir/all" $cnfarg >"$outdir/cnf" 2>/dev/null && echo "OK"

echo -n "Computing coatoms... "
perl coatoms.pl 4 "$outdir/cnf" | sort >"$outdir/coatoms" && echo "OK"

echo -n "Computing irreducibles... "
perl irred.pl 4 "$outdir/cnf" | sort >"$outdir/irred" && echo "OK"

echo "Done"
echo ""
