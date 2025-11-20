Functional-Level Processor
==========================================================================

In addition to the RTL processor implementations, a functional-level (FL)
processor was developed with RV32IM support. This processor implementation
was aimed towards testing, and served two purposes:

* Verification of tests with specified inputs and outputs (directed
  testing)
* For any given input stream, production of expected outputs to compare
  with RTL model outputs (golden reference model testing)

In addition to testing, the FL processor could run programs as a
standalone ISA simulator, to verify their functionality before being
run on hardward models.

Helper Classes
--------------------------------------------------------------------------

As part of the FL processor implementation, many helper classes were
constructed:

Instructions (``FLInst``)
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

The ``FLInst`` class wraps an instruction, and provides methods for
accessing the instruction's type and fields (using the disassembler
helper functions). This makes using the instruction much easier and
understandable (such as using ``inst.rd()`` instead of bit slicing).
Most methods are also annotated with ``__attribute__( ( const ) )`` to
avoid overhead from multiple calls.

Register File (``FLRegfile``)
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

A functional-level register file was implemented in ``FLRegfile.cpp``, to
store the state of the architectural registers of the FL processor. The
bracket operator was overloaded to provide concise syntax; however, this
meant that all accesses would provide a ``uint32_t&``. To ensure that
``x0`` is always read as ``0``, ``regs[0]`` is assigned to ``0`` on each
access.

Memory (``FLMem``)
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

A functional-level memory array was implemented in
``FLMem.cpp``, to act as the main memory of the FL Processor. The current
implementation stores data as an ``std::map`` mapping of address to data
words; while inefficient for large programs (where a static allocation
of a large buffer might be suitable), it worked well for smaller sparse
programs.

In addition to memory data, the ``FLMem`` stores pointers to
memory-mapped peripherals (see below), and would check each on a memory
access to forward requests appropriately instead of storing data normally.

Peripherals (``FLPeripheral``)
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

In BLIMP, all peripheral devices are memory-mapped. For the FL processor,
these are implemented as derived classes of ``FLPeripheral``. The base
class provides a common interface for for accesses; namely, ``try_read``
and ``try_right`` check whether a request is directed for the peripheral,
and perform the operation if so (returning whether the peripheral was used).

Derived classes must implement three functions:

* ``get_address_ranges`` provides a list of address ranges, where each
  range is comprised of start/end addresses (inclusive) and access types
  that are allowed (``R``, ``W``, or ``RW``). This allows the base class
  to identify whether a particular access is meant for a peripheral or not.
* ``read`` and ``write`` are called with the address and data of a
  transaction meant for the peripheral, and should perform any actions
  appropriately

Currently, two FL peripherals are implemented (in ``fl/peripherals``) and
used as part of the FL processor:

* ``FLTerminal`` acts as the standard input and output streams; it can
  be read from to provide user input, or written to to display character
  output
* ``FLExit`` is our mechanism for exiting a simulation; when written to,
  it will exit a simulation with that exit code.

Instruction Traces (``FLTrace``)
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

When the processor executes a single instruction, having a "snapshot" of
what the instruction did is useful for verification purposes; gaining
visibility as to what the processor did can identify the first
unexpected change to architectural state. Accordingly, when the FL
processor executes an instruction, an ``FLTrace`` object is produced,
which contains:

* The instruction's address in memory (a.k.a. the PC when it executed)
* Whether the instruction wrote to a register (``wen``)
* The register it wrote to, if applicable (``waddr``)
* The data written to a register, if applicable (``wdata``)

These can not only be dumped to a text-based format, but can be used
in Verilog to compare with the operations done by RTL models, checking
that both processors produce the same state changes.

Functional-Level Processor Implementation
--------------------------------------------------------------------------

The functional-level processor's implementation is contained in the 
``step`` function, which implements one execution step (a.k.a. executes
one instruction). This involved:

* Getting the instruction at the current PC, wrapping as an ``FLInst``
* Determining the instruction type using the ``name`` method
* Using a case statement to execute the correct behavior for the
  instruction, returning the appropriate ``FLTrace`` to reflect the
  current PC, the destination, the value of the destination, and
  whether the destination was written

.. code-block:: c++

   switch ( inst_name ) {
       // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
       // add
       // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

     case ADD:
       regs[inst.rd()] = regs[inst.rs1()] + regs[inst.rs2()];
       pc              = pc + 4;
       return FLTrace( inst_pc, inst.rd(), regs[inst.rd()],
                       inst.rd() != 0 );   

       // ...
   }

Interfacing with Verilog Testbenches
--------------------------------------------------------------------------

Running Programs on the Processor
--------------------------------------------------------------------------