// FFTW

/*
  This primer demonstrates the interop between Chapel and
  the distributed FFTW libraries.

 */

/* The MPI module automatically initializes MPI, if it isn't
   already initialized. The C-API to MPI-1 is in the submodule
   C_MPI; we include it here for convenience when making any MPI
   calls.
*/
use MPI;
use C_MPI;

/* We include other modules here. Note that we include the
   single-locale FFTW module to get access to FFTW variable
   definitions, but we also ``require`` the FFTW MPI header.
   The actual extern definitions are at the bottom of this
   file.
*/
use SysCTypes;
use FFTW;
use Random;
use PrivateDist;
use BlockDist;
require "fftw3-mpi.h";


/* Initialize the FFTW library. Note that this is an
   SPMD block.
*/
forall loc in PrivateSpace {
  fftw_mpi_init();
}

/* Get the number of MPI ranks.
   ``commSize`` is a convenience function
   provided by ``mpi``.
*/
const size=commSize();

/* Define the grid dimensions. For simplicity we will assume
   that ``Ng`` is divisble by ``numLocales``.
*/
config const Ng=128; 
const Ng2=Ng+2;
const invNg3 = 1.0/(Ng:real)**3;
if ((Ng%size)!=0) && (Ng%2==0) {
  writeln("mpi size must divide Ng and Ng must be even");
  MPI_Abort(CHPL_COMM_WORLD, 1);
}

writeln("Hello Brad! This is Multilocale Chapel running with MPI");
writef("Chapel is running with %i locales\n",numLocales);

/* Run on each MPI rank/Chapel locale.
   ``Barrier`` is a wrapper around ``MPI_Ibarrier`` and
   ``MPI_Test``, preventing a qthreads deadlock.
   ``CHPL_COMM_WORLD`` is an MPI communicator that ensures that
   the MPI rank and Chapel locale id match.
*/
forall loc in PrivateSpace {
  const rank=commRank();
  for irank in 0.. #size {
    if rank==irank then writef("This is MPI rank %i of size %i \n",rank, size);
    Barrier(CHPL_COMM_WORLD);
  }
}

/* Define an FFTW compatible array distribution.
 */
const DSpace={0..#Ng,0..#Ng,0..#Ng2};
var targets : [0..#numLocales,0..0,0..0] locale;
targets[..,0,0]=Locales;
const D : domain(3) dmapped Block(boundingBox=DSpace, targetLocales=targets) = DSpace;

// Now initialize the arrays and save a copy.
var A, B : [D] real;
fillRandom(A, seed=1234);
B = A;

// Sum the elements of the array. We will use this as a test of the
// FFT calls.
var sum1, sum2 : real;
forall a in A[..,..,0..#Ng] with (+ reduce sum1,
                    + reduce sum2) {
  sum1 += a;
  sum2 += a**2;
}
writef("Total sum A=%er, sum A^2 = %er \n",sum1, sum2);

/* We now call into FFTW.
   Construct the FFTW plan, and then execute this plan.
   Note that this is an MPI blocking call, so we
   protect from deadlocks with a preceding ``Barrier``.
*/
forall loc in PrivateSpace {
  var idx = B.localSubdomain().low;
  Barrier(CHPL_COMM_WORLD);
  {
    // MPI calls
    var fwd = fftw_mpi_plan_dft_r2c_3d(Ng, Ng, Ng, B[idx], B[idx], CHPL_COMM_WORLD, FFTW_ESTIMATE);
    execute(fwd);
    destroy_plan(fwd);
  }
}

/* Now test the sum of the elements, which should be the ``(0,0,0)``
   element of the FFT grid.
*/
writef("Element at k=(0,0,0) = %er \n",B[0,0,0]);
writef("Error = %er \n", B[0,0,0]/sum1 - 1);
writef("Imaginary component (expected=0) : %er \n", B[0,0,1]);

/* Testing the sum of squares uses Parsevals theorem,
   which states that the sum of squares is the same in
   both configuration and Fourier space (normalized by the
   number of grid points) */
var ksum2 : real;
ksum2 = 2*(+ reduce B[..,..,2..(Ng-1)]**2);
ksum2 += (+ reduce B[..,..,0..1]**2);
ksum2 += (+ reduce B[..,..,Ng..(Ng+1)]**2);
ksum2 *= invNg3;
writef("Total sum B^2 = %er , error= %er\n",ksum2, ksum2/sum2 - 1);
 
/* Now reverse transform the grid. Again, this is an MPI blocking call, so
   we protect by a ``Barrier``.
*/
forall loc in PrivateSpace {
  var idx = B.localSubdomain().low;
  Barrier(CHPL_COMM_WORLD);
  {
    // MPI calls
    var rev = fftw_mpi_plan_dft_c2r_3d(Ng, Ng, Ng, B[idx], B[idx], CHPL_COMM_WORLD, FFTW_ESTIMATE);
    execute(rev);
    destroy_plan(rev);
  }
}
B *= invNg3;

/* Let us make sure that we recover the original array. */
var diff = max reduce abs(A[..,..,0..#Ng] - B[..,..,0..#Ng]);
writef("Max diff = %er\n",diff);

/* Cleanup the FFTW library. Note that the MPI library automatically
   cleans itself up.
*/
forall loc in PrivateSpace {
  fftw_mpi_cleanup();
}
writeln("Goodbye, Brad! I hope you enjoyed this distributed FFTW example");

/* The declarations for the FFTW MPI API.*/
extern proc fftw_mpi_init();
extern proc fftw_mpi_cleanup();
extern proc fftw_mpi_plan_dft_r2c_3d(n0 : c_ptrdiff, n1 : c_ptrdiff, n2 : c_ptrdiff,
                                     ref inarr , ref outarr,
                                     comm : MPI_Comm, flags : c_uint) : fftw_plan;
extern proc fftw_mpi_plan_dft_c2r_3d(n0 : c_ptrdiff, n1 : c_ptrdiff, n2 : c_ptrdiff,
                                     ref inarr, ref outarr,
                                     comm : MPI_Comm, flags : c_uint) : fftw_plan;
