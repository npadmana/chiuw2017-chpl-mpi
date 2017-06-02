use BlockCycDist;
use SysCTypes;

config const debug=true;

if numLocales!=6 {
  writeln("This example requires numLocales==6");
  exit(1);
}

config const n=9;
const Space = {1..n, 1..n};
const blockFactor=(2,2);
const blockSize=4;
var myLocaleView = {0..#3, 0..#2};
var myLocales : [myLocaleView] locale = reshape(Locales, myLocaleView);

if debug {
  writeln("Locale Grid :\n",myLocales);
  writeln();
}

const BlkCycSpace = Space dmapped BlockCyclic(startIdx=Space.low,
                                              blocksize=blockFactor,
                                              targetLocales=myLocales);

if debug {
  var BCA : [BlkCycSpace] int;
  forall bca in BCA do bca=here.id;
  writeln("ID map on matrix");
  writeln(BCA);
  writeln();
}

/* Define the A matrix */
const vals=(19.0, 3.0, 1.0, 12.0, 1.0, 16.0, 1.0, 3.0, 11.0);
var A : [BlkCycSpace] real;
forall (a, (ix, iy))  in zip(A, A.domain) {
  a = vals(ix);
  if (iy > ix) then a=-a;
}

if debug {
  writeln("Amat:");
  writeln(A);
  writeln();

  writeln("Printing elements stored on locales");
  writeln("Make sure we are filling the array correctly");
  for loc in Locales do on loc {
      write(loc.id,":");
      var (elt, cnt) = getLocalElts(A);
      for ii in 0..#cnt do write(" ",elt[ii]);
      writeln();
    }
}







/* Get the local elements.

   Unfortunately, the current implementation of BlockCyclicDist
   does not ensure a packed array */
proc getLocalElts(A) {
  var doms = A.localSubdomains();
  var cnt = blockSize*doms.size;
  // First domain
  ref dom1 = doms[doms.domain.low];
  var elt = c_ptrTo(A[dom1.low]);
  return (elt, cnt);
}