# Self-adhesivity in lattices of abstract conditional independence models

This page contains the source code and explanations related to the computational
results presented in the paper:

> Tobias Boege, Janneke H. Bolt, Milan Studený: *Self-adhesivity in lattices of abstract conditional independence models*.

- arXiv preprint: [`cs.IT/XXX.YYY`](https://arxiv.org/abs/XXX.YYY)
- Files directory: [`selfadhe-lattices`](./?dir) with container sources: [`selfadhe-lattices/container`](container?dir)
- Container image:
  [`selfadhe-lattices.tar.zst`](/images/cinet-selfadhe-v1.0.0-20240208.tar.zst)
  <small style="line-break: anywhere">(SHA256: <code>29a0cd3f7ef7d018d7ff7a31fdea5dac1c8a4636a566e6e51c8aaa5cccae488f</code>)</small>
- Repository: <code>git clone <https://git.cinet.link/selfadhe-lattices></code>

Notation and terminology follows the paper. All computations are performed
in the provided container. Download the container image and `podman load` it
or create it yourself (see the [installation instructions](/install) for
details on containers). Then login via

``` console
$ podman run -w /selfadhe -it cinet/selfadhe bash -l
```

A summary table of numerical data for all computations is available in the
[`summary.txt`](summary.txt) file. Timings for all computations performed
in the above container on the author's laptop (single-thread performance,
Thinkpad T14 with Intel i7-1365U) can be found in [`timing.log`](timing.log).

$\newcommand{\sg}{\mathfrak{sg}}$
$\newcommand{\gr}{\mathfrak{gr}}$
$\newcommand{\cgr}{\mathfrak{cgr}}$
$\newcommand{\st}{\mathfrak{st}}$
$\newcommand{\pr}{\mathfrak{pr}}$
$\newcommand{\dual}{\star}$
$\newcommand{\sa}{\diamond}$

## Generating lattice data

The core technology of our computations is SAT solving. Every family of CI
models we consider is a lattice and can therefore be axiomatized using Horn
clauses. The frames of semigraphoids $\sg$, graphoids $\gr$ and compositional
graphoids $\cgr$ are known to have a finite axiomatization. The structural
semigraphoids $\st$ are known not to have a finite axiomatization as a whole
frame [[Mat97]](#Mat97); nevertheless each family in this frame can be
axiomatized by a boolean formula. For $\st(4)$ the axioms have been derived
in early work by Studený [[Stu94]](#Stu94) and we will derive them from
scratch below using only an exhaustive list of the members and the lattice
structure of the family.

The first program to discuss is [`gen.pl`](gen.pl) which enumerates various
families of CI models. By default it enumerates semigraphoids over a given
ground set:

``` console
$ perl gen.pl 4 >sg4/all
$ wc -l sg4/all # count semigraphoids
26424 sg4/all
$ perl mod.pl 4 sg4/all | wc -l # count permutational types
1512
```

Combining the switches `--composition` and `--intersection`, one can enumerate
graphoids, compositional semigraphoids or compositional graphoids. The switch
`--structural` allows to enumerate structural semigraphoids. Finally, the
option `--selfadhesive` can be combined with any of the previous switches to
produce the selfadhesion of the indicated family. Note that `--selfadhesive`
*cannot* be used multiple times to compute iterated selfadhesion.

There is also a subdirectory [`pr4`](pr4?dir) which contains the probabilistically
representable CI models on a 4-element ground set. The file [`pr4/all`](pr4/all)
was generated using [`simecek-tools`](https://github.com/taboege/simecek-tools)
from files originally produced by Petr Šimeček [[Šim06]](#Šim06). This website
disappeared but the data is still available from the [Internet Archive](http://web.archive.org/web/20190516145904/http://atrey.karlin.mff.cuni.cz/~simecek/skola/models/).

### Pseudo-closed elements and axioms

The program [`axioms.pl`](axioms.pl) takes a list of models in a CI family
as input, assuming that they form a lattice, and executes the algorithm
described in Appendix A to compute a canonical implicational basis.
It converts this into a boolean formula in conjunctive normal form (CNF).
It does this once in human-readable form on stderr and in machine-readable
form on stdout.

``` console
$ perl axioms.pl 4 sg4/all >sg4/cnf
12| & 13|2 => 12|3 & 13|
12|3 & 14|23 => 12|34 & 14|3
```

The pseudo-closed elements of the lattice which give rise to these axioms
can also be printed:

``` console
$ perl axioms.pl --pseudo-closed 4 sg4/all | perl mod.pl 4 | perl write-struct.pl 4
{ ab|c, ad|bc }
{ ab|, ac|b }
```

### Coatoms and irreducibles

Given the axioms of a family of CI models in CNF, it is easy to enumerate
the coatoms and irreducible elements using their definitions:

- A CI model $\mathcal{M}$ is a *coatom* in $\mathfrak{f}(N)$ if the only
  strict superset in $\mathfrak{f}(N)$ is the full CI model $\mathcal{K}(N)$.
  By adding the following clauses to the axioms of $\mathfrak{f}(N)$,

  $$
    \bigwedge_{a \in \mathcal{M}} a \wedge
    \bigvee_{b \in \mathcal{K}(N) \setminus \mathcal{M}} b \wedge
    \bigvee_{b \in \mathcal{K}(N) \setminus \mathcal{M}} \neg b,
  $$

  we obtain a formula which describes all strict supersets of $\mathcal{M}$
  in the family which are not the full CI model. Hence it is satisfiable if
  and only if $\mathcal{M}$ is *not* a coatom. This is a single SAT solver
  invocation and usually very fast.

- A CI model $\mathcal{M}$ is *irreducible* in its family $\mathfrak{f}(N)$
  if it is not equal to the intersection of all its strict supersets in the
  family. But the intersection of all strict supersets is a superset of
  $\mathcal{M}$ and hence the only way in which this intersection is not
  equal to $\mathcal{M}$ is if there exists some $b^* \not\in \mathcal{M}$
  such that the $\mathfrak{f}$-closure of every set $\mathcal{M} \cup b$,
  for any $b \in \mathcal{K}(N) \setminus \mathcal{M}$, contains $b^*$.
  This can be tested as well using multiple SAT solver invocations, one for
  each candidate $b^*$.

The two programs [`coatoms.pl`](coatoms.pl) and [`irred.pl`](irred.pl)
implement these algorithms.

``` console
$ perl coatoms.pl 4 sg4/cnf >sg4/coatoms
$ perl mod.pl 4 sg4/coatoms | wc -l
10
$ perl irred.pl 4 sg4/cnf >sg4/irred
$ perl mod.pl 4 sg4/irred | wc -l
20
```

### About duals

The script [`check-duals.pl`](check-duals.pl) takes a list of CI models and
outputs one representative for each permutational type inside the family
whose dual is outside the family. The 48 types of selfadhesive semigraphoids
whose dual is not a selfadhesive semigraphoid can be determined as follows
(after `sg4sa/all` has been computed using `gen.pl`):

``` console
$ perl check-duals.pl 4 sg4sa/all
```

## The coatoms of structural 5-semigraphoids which are also selfadhesive 5-semigraphoids

The second thread of computations concerns the containment of coatoms of
$\st(5)$ in the family $\sg^{\sa}(5)$. The coatoms of $\st(5)$ are known:
they correspond to the extreme rays of normalized supermodular functions.
We include a description of this polyhedral cone in the source file
[`nsupmod.in`](st5/nsupmod.in) and use [`normaliz`](https://www.normaliz.uni-osnabrueck.de)
to enumerate extreme rays which we then convert to structural semigraphoids:

``` console
$ cd st5
$ normaliz nsupmod
$ perl extreme-rays.pl nsupmod.out | perl to-relation.pl 5 >coatoms
```

The script [`test.pl`](test.pl) is very similar to `gen.pl` except that it
does not enumerate a family but tests if input CI models belong to the
family. The coatoms computed in the previous step can thus be checked
for containment in $\sg^\sa(5)$:

``` console
$ cd ..
$ perl mod.pl 5 <st5/coatoms | perl test.pl 5 --selfadhesive | perl unmod.pl 5 >st5/coatoms-sg5sa
$ perl mod.pl 5 st5/coatoms | wc -l
1319
$ perl mod.pl 5 st5/coatoms-sg5sa | wc -l
154
```

This shows that out of all 1319 permutational types of extreme normalized
supermodular functions, at most 154 can be entropic due to conditional
independence obstructions.

## Computing the second-order selfadhesive semigraphoids

The last major computation in the paper is the determination of $\sg^{\sa\sa}(4)$.
This is accomplished by a dedicated script [`sasa.pl`](sg4sasa/sasa.pl).
The implementation differs from the algorithm presented in Appendix C of the
paper in technical details which are intended to reduce computation time.
Still, with over 6 hours of computation time, this is by far the
longest-running task.

First note that since $\sg^{\sa\sa}(4)$ is a superset of $\pr(4)$, we only
need to test second-order selfadhesivity for elements in the difference set
$\sg^{\sa}(4) \setminus \pr(4)$:

``` console
$ perl mod.pl 4 sg4sa/all | while read G
> do grep -q "$G" pr4/all || echo "$G"
> done >sg4sasa/sg4sa-minus-pr4
```

This results in 254 models to be tested, all of which pass all the tests
of second-order selfadhesivity:

``` console
$ perl sasa.pl sg4sa-minus-pr4 >/dev/null
The sg4sa/all file name is not as expected. at sg4sasa/sasa.pl line 51.
Reducing selfadhesive semigraphoids modulo symmetry... 254
[Thu Feb  8 05:55:53 2024] 000011111111111111110001 [AB: 1] [AC: 2] [AD: 2] [BC: 2] [BD: 2] [CD: 2] [ABC: 1] [ABD: 0] [ACD: 2] [BCD: 2] PASS
[Thu Feb  8 05:57:22 2024] 000011111111111111110010 [AB: 2] [AC: 2] [AD: 2] [BC: 2] [BD: 2] [CD: 2] [ABC: 2] [ABD: 0] [ACD: 2] [BCD: 2] PASS
…
[Thu Feb  8 12:05:34 2024] 101111011111111111011110 [AB: 2] [AC: 2] [AD: 2] [BC: 2] [BD: 2] [CD: 2] [ABC: 2] [ABD: 2] [ACD: 1] [BCD: 1] PASS
Finished! 254 models passed.
```

The program is long and uses a number of tricks, so some remarks are in
order:

- The computation is organized into a sequence of "tests" for the model
  $\mathcal{M} \in \sg^\sa(4)$ under consideration. There is one test for
  each $L \subseteq N = \\{1,2,3,4\\}$ of size $|L| \in \\{2,3\\}$. The test
  consists of computing $\sg^{\sa\sa}(\mathcal{M}|L)$ and making sure that
  it is not a strict superset of $\mathcal{M}$. All of these tests must
  pass before we can conclude $\mathcal{M} \in \sg^{\sa\sa}(4)$.

- Instead of performing tests at a given set $L$ verbatim, we compute an
  involution of $N$ which transfers $L$ to an initial segment $A = \\{1, \dots, |L|\\}$
  of $N$. Applying the same involution, say $\sigma_L$ to $\mathcal{M}$, we
  can then execute the test of $\mathcal{M}$ at $L$ by equivalently testing
  $\sigma_L(\mathcal{M})$ at $A$.
  This has two advantages: (1) We can detect permutational symmetries of
  $\mathcal{M}$ and skip redundant computations; and (2) the boolean formulas for
  adhesive extensions given initial segments can be cached and reused instead
  of being computed for every $L$. In general, we cache and reuse as much as
  possible. This saves time **and** memory compared to the naïve implementation.

- The computation of $\sg^{\sa\sa}(\mathcal{M}|L)$ is performed using a
  *closure loop*, in which multiple $\sg(M)$-closures for ground sets $M$
  of size up to 10 have to be computed. On a 10-element ground set, there
  are $\binom{10}{2} 2^8 = 11\,520$ CI statements which makes closure
  computations quite expensive. In addition, only a restriction of these
  closures to 5- or 6-element sub-ground sets are needed. The SAT solver-based
  closure algorithm can be modified to test only for implications on the
  relevant sub-ground sets. This gives another considerable speed-up.

## References

<dl class="references">
<dt><a name="Mat97">[Mat97]</a></dt>
<dd>
F. Matúš: Conditional independence structures examined via minors. Ann. Math. Artif. Intell. 21 (1997).
</dd>
<dt><a name="Stu94">[Stu94]</a></dt>
<dd>
M. Studený: Structural semigraphoids. Int. J. Gen. Syst. 22(2) (1994).
</dd>
<dt><a name="Šim06">[Šim06]</a></dt>
<dd>
P. Šimeček: A short note on discrete representability of independence models. PGM workshop, Prague (2006).
</dd>
</dl>

# Colophon

- This document describes version `v1.0.0` of the data.
- Author: Tobias Boege `post@taboege.de`.
- Last modified: 12 February 2024.
- License: <a href="http://creativecommons.org/licenses/by/4.0/?ref=chooser-v1" target="_blank" rel="license noopener noreferrer" style="display:inline-block;">CC BY 4.0<img style="height:22px!important;margin-left:3px;vertical-align:text-bottom;" src="https://mirrors.creativecommons.org/presskit/icons/cc.svg?ref=chooser-v1"><img style="height:22px!important;margin-left:3px;vertical-align:text-bottom;" src="https://mirrors.creativecommons.org/presskit/icons/by.svg?ref=chooser-v1"></a>
