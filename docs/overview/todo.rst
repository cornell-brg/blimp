Further Work
==========================================================================

While Blimp has made lots of progress as both a processor and framework
for processor development, there are still improvements that could be
made

Fixes
--------------------------------------------------------------------------

These improvements seek to address issues or shortcomings in the current
design, and should be prioritized over enhancements

Simplify Sequence Number Generation
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

Currently, the sequence generation units (``hw/fetch/SeqNumGen*``)
maintain a vector representing which sequence numbers are in-flight
(``seq_num_list``). This approach was taken when the exact semantics of
sequence numbers were being defined, and allows for sequence numbers to
be freed in any order. However, since sequence numbers are freed upon a
commit (occuring in-order with respect to sequence numbers), this
vector could be removed, with in-flight sequence numbers only needing
a head and tail pointer to be represented. This would not only result
in area savings, as well as a one-cycle saving by directly updating the
tail pointer on a commit (instead of later reclaiming entries), but would
cause the area associated with :math:`N` sequence numbers to scale overall
as :math:`\log(N)`.

Fix Memory Network Dependence
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

With the current memory network, there exists a possibility for deadlock
due to a dependency chain between ``imem`` and ``dmem``:

 - A stalled fetch unit leads to a stalled ``FPGAMem``, since the response
   cannot be taken
 - A stalled ``FPGAMem`` leads to a stalled memory XU, since the request
   cannot be taken
 - A stalled memory XU (in the case of another memory transaction) leads
   to a stalled pipeline, stalling the fetch unit

Currently, this is resolved by placing FIFOs in the processor at the
``imem`` and ``dmem`` ports to buffer responses. If these FIFOs are sized
to the pipeline depth of the memory network (and assuming fair
arbitration), the memory network won't stall; however, this approach isn't
very modular and doesn't scale well.

Instead, the dependency between ``imem`` and ``dmem`` in the memory
network should be broken. Some ways to do this include:

 - Having separate pipelines for both channels in the memory (requiring
   a dual-ported memory)
 - Having separate credits for both channels in the memory network, with
   memory able to service the other channel if one is stalled

Enhancements
--------------------------------------------------------------------------

These improvements seek to expand the functionality of Blimp's processor
models

Privileged ISA Support
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

While the current ISA can support many programs, it lacks the support for
operating system-level control. For this, the privileged RISCV ISA would
need to be implemented, with support for CSRs (and their effects) as well
as exceptions and interrupts. The basic CSRs needed for this would be
``mtvec``, ``mepc``, ``mcause``, and ``mstatus`` (for interrupts);
however, many more may wish to be implemented for various operating
systems, such as hardware privilege modes. A good reference/goal for
minimal support would be those necessary to run `EGOS 2000 <https://github.com/yhzhang0128/egos-2000>`_,
also developed at Cornell.

.. admonition:: Squashing Locations in the Processor
   :class: note

   Recall from the Version 6 processor that currently, we can limit
   the scope of squashing by handling all control flow instruction
   in one cycle, ensuring that no potentially-squashed instructions make
   it past the DIU. However, interrupt/exception handling breaks this
   assumption (particularly exceptions, which would be handled in the
   WCU).

   Before implementing the privileged ISA, Blimp will need to support
   squashing of instructions *anywhere* in the pipeline, including
   in XUs and the WCU (specifically the ROB) through squash notifications.
   While this requires many additional modules to be implemented, many
   should require minimal changes compared to existing versions, with
   a notable exception being the memory XU (to keep track of in-flight
   requests to determine which should be squashed, likely using an LSQ
   in an out-of-order architecture). However, it would also have the
   benefit of making the system more modular by removing the assumption
   on control flow resolution time.

Full Out-Of-Order Execution
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

Currently, Blimp only implements an out-of-order backend; this feature
would extend out-of-order processing to include the DIU, making the
processor fully out-of-order. This would require the addition of an issue
queue in the DIU, which would likely tightly couple with the rename table
to determine which registers have pending writes. The rename table would
also have to be able to free specific pending writes based on their
sequence number on a squash. Additionally, the memory XU would now
require a load-store queue (LSQ) to resolve potential RAW hazards through
memory (after some discussion, we determined that the best place for the
LSQ to live is in an execute unit).

This change would also imply that instructions could be squashed anywhere
in the pipeline; see the note above.

Superscalar Pipeline Support
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

Blimp currently only supports a single-issue pipeline; however, the
methodology supports a superscalar pipeline. For this, the best way to
modify the pipeline (ensuring backwards compatibility) would be to have
units take a parametrized array of interfaces (ex. for multiple
instructions being fetched at once, the FU would drive an array of ``F__D``
interfaces).

The easiest path to implementation would be to start from the back of
the processor, and gradually replace each interface with a parametrized
array, modifying all of the units that it touches (i.e. support an
array of ``Commit`` notifications before worrying about multiple issue).

This change would also imply that instructions could make it into the
pipeline at the same time as control flow instructions that would want
to squash them; see the note on squashing above.

Formal Verification
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

While Blimp is extensively verified through unit and integration testing,
both the directed and golden tests are user-specified. An ongoing effort
has been to create formal models of each instruction, such that processors
can be `formally verified <https://github.com/SymbioticEDA/riscv-formal>`_.
For this, the existing ``InstTraceNotif`` interface (for producing an
instruction trace and verifying against the FL model) would need to be
replaced with the `RVFI Interface <https://github.com/SymbioticEDA/riscv-formal/blob/master/docs/rvfi.md>`_,
to hook into RISCV's formal verification framework.

