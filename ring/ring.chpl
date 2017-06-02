/* Example of mixed Chapel + MPI code. This implements
   a simple ring communication. The communications here
   are handled with MPI calls, running in two separate
   Chapel tasks.

   Note that while the calls appear to be blocking, they
   are implemented as non-blocking calls which appropriately
   yield tasks.
*/

/* Import and initialize MPI, and pull in the
   C-API into the scope for convenience.
*/
use MPI;
use C_MPI;

/* The main program. */
proc main() {
  writeln("This is the main program");

  /* Implement the send and receive as concurrent tasks */
  cobegin {
    send();
    recv();
  }

  writeln("The main program ends here...");
}

/* The send function */
proc send() {
  /* Switch to SPMD mode and run a task on all locales */
  coforall loc in Locales do on loc {

    /* Based on my rank, work out whom I need to send to. */
    var rank = commRank(CHPL_COMM_WORLD) : c_int,
        size = commSize(CHPL_COMM_WORLD) : c_int;
    var dest : c_int;
    dest = (rank + 1)%size;

    /* Send some information. Note that we use the
       ``Send`` function which is provided by the Chapel
       module. This has exactly the same calling convention
       as ``MPI_Send``, but is implemented with non-blocking
       calls.  Also, note the use of ``CHPL_COMM_WORLD``*/
    writef("Rank %i sending to %i \n",rank, dest);
    Send(rank, 1, MPI_INT, dest, 0, CHPL_COMM_WORLD);
    writef("Rank %i done sending...\n",rank);
  }
}

/* The receive function */
proc recv() {
  /* Switch to SPMD mode and run a task on all locales */
  coforall loc in Locales do on loc {

    /* Based on my rank, work out whom I need to receive from. */
    var rank = commRank(CHPL_COMM_WORLD) : c_int,
        size = commSize(CHPL_COMM_WORLD) : c_int;
    var src, val : c_int;
    src = mod(rank-1,size);

    /* Receive some information. Note that we use the
       ``Recv`` function which is provided by the Chapel
       module. This has exactly the same calling convention
       as ``MPI_Send``, but is implemented with non-blocking
       calls.  Also, note the use of ``CHPL_COMM_WORLD``*/
    writef("Rank %i receiving from %i \n",rank, src);
    var status : MPI_Status;
    Recv(val, 1, MPI_INT, src, 0, CHPL_COMM_WORLD, status);
    writef("Rank %i received %i from the left.\n", rank, val);
  }
}

