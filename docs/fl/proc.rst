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

The interface to the functional-level processor from Verilog is
contained in ``fl/fl_vtrace.v``, which exposes functions declared in
``fl/fl_vtrace.h`` and defined in ``fl/fl_vtrace.cpp``. These include:

* ``fl_reset()`` resets the processor state
* ``fl_init( addr, data )`` initializes the processor's memory at the
  address ``addr`` with ``data`` (both 32 bits)
* ``fl_trace( *trace )`` steps the processor one execution cycle,
  producing a ``FLTrace`` that shows what happened. From Verilog, this
  looks like a function output (i.e. pass in the signal that you want
  to modify), with the corresponding C++ acting on a pointer
* ``fl_trace_str( trace )`` produces the string representation of a trace

For testing RTL processors, ``fl_reset`` is used at the beginning of each
test case (when the RTL processor is reset). Additionally, when the
processor's memory is initialized in a test case, we also initialize the
functional-level memory with ``fl_init`` (note that the ``asm`` function
in test harnesses initializes both the RTL and FL memory the same).
``fl_trace`` is used when testing the FL processor in directed testing
(to ensure the expected result), but also to generate the expected result
for golden-reference testing. Finally, ``fl_trace_str`` is used to
generate an execution trace for the FL processor.

Running Programs on the Processor
--------------------------------------------------------------------------

To run programs on the functional-level processor, we first need a way
to interpret RISCV binary programs. This is done by ``parse_elf``, the
name of both a C++ function and the corresponding ``.h/.cpp`` files in
the ``fl`` directory. This function takes in a binary program and a
call back function (of the signature ``callback( addr, data )``), and
interprets the binary while calling the callback to store data at
the addresses specified in the program. By operating on a generic function,
this utility can be re-used across a variety of applications, including
FL simulations, RTL simulations (see ``hw/top/sim/utils/load_elf.cpp`` and
its use inside simulators in ``hw/top/sim``), and dumping address-data
mappings (see ``tools/rvelfdump.cpp``).

For functional-level simulations, the top-level file is ``fl/fl_sim.cpp``.
This instantiates the functional-level processor, loads a binary using
``parse_elf``, and steps the execution of the processor until it fails
(usually exiting first with the ``FLExit`` peripheral - see
:doc:`../fpga/peripherals`). This enables us to cross-compile programs
to RISCV and run them on the standalone ``fl-sim`` program, verifying
the program's functionality before running it on an RTL processor.