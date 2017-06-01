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
var myLocaleView = {0..#2, 0..#3};
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