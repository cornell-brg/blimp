Memory-Mapped Peripherals
==========================================================================

.. role:: ccode(code)
   :language: c

Blimp has two methods for communicating with functional units:

* For *fine-grain* integration, the unit is integrated in the processor
  as one of the :doc:`../units/execute_units`
* For *course-grain* integration, the unit is memory-mapped in the
  memory subsystem, referred to as a **peripheral**

Any memory address of the form ``0xFXXXXXXX`` is reserved for
memory-mapped peripherals, and must be globally unique across all
peripherals. Currently, three such peripherals exist

+------------+-------------------------+----------------+-----+
| Peripheral | Description             | Addresses      | R/W |
+============+=========================+================+=====+
| Terminal   | Allow reading user      | ``0xF0000000`` | W   |
|            | input or displaying     +----------------+-----+
|            | user output             | ``0xF0000004`` | R   |
+------------+-------------------------+----------------+-----+
| Exit       | Allow exiting from      | ``0xFFFFFFFC`` | W   |
|            | within a program        |                |     |
+------------+-------------------------+----------------+-----+
| Cycle      | Allow access to a cycle | ``0xFFFFFF00`` | R   |
| Counter    | counter for performance |                |     |
|            | profiling               |                |     |
+------------+-------------------------+----------------+-----+

Currently, only word (32b) accesses are supported for peripherals, although
this could be modified.

Peripherals
--------------------------------------------------------------------------

.. admonition:: Peripheral Interface
   :class: note

   Many of these implementations are incomplete; notably, the Exit
   peripheral doesn't have a FPGA implementation, and the cycle counter
   is largely ad-hoc for quick testing. These could be improved, likely
   involving improvements to the ``FLPeripheral`` base class (see below)

Terminal
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

* `FL/Simulation Implementation <https://github.com/cornell-brg/blimp/blob/main/fl/peripherals/FLTerminal.cpp>`__
* FPGA Implementation

  * `PS2 Input <https://github.com/cornell-brg/blimp/tree/main/fpga/ps2>`__
  * `VGA Output <https://github.com/cornell-brg/blimp/blob/main/fpga/vga/CharDisplay.v>`__

The Terminal peripheral provides an interface for the processor to
communicate to a user:

* ``0xF0000000`` represents the standard output; writing an ASCII
  character here will display it the user (via a VGA display for FPGA
  implementations)
* ``0xF0000004`` represents the standard input; reading from here
  will read in an ASCII character that the user presses on a keyboard
  (for FPGA implementations, a PS2 keyboard)


Exit
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

* `FL/Simulation Implementation <https://github.com/cornell-brg/blimp/blob/main/fl/peripherals/FLExit.cpp>`__

The Exit peripheral defines a way for the processor to communicate to
the simulation/surrounding environment that the program is done. It
defines one address ``0xFFFFFFFC``, where storing a value there exits
the program with the value as the exit code.

Cycle Counter
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

* `Simulation Implementation <https://github.com/cornell-brg/blimp/blob/24c9ac6893ceb2c73f792c1c5437446670568403/test/fl/MemIntfTestServer_2Port.v#L54-L63>`__

   * Currently not supported for the FL processor (embedded in RTL memory)

The Cycle Counter was an ad-hoc addition to the simulation memory
subsystem, to allow processors to have a notion of the current cycle
count. By getting the current cycle number before and after a
critical section, processors can report how long the critical section
takes to execute.

FL/Simulation Implementations
--------------------------------------------------------------------------

All FL peripherals inherit from `FLPeripheral <https://github.com/cornell-brg/blimp/blob/main/fl/FLPeripheral.h>`__,
which defines a common interface that peripherals must implement. Child
classes must implement:

* :ccode:`void read( uint32_t addr, uint32_t* data )`: Read data from the
  given address
* :ccode:`void write( uint32_t addr, uint32_t data )`: Write the data to
  the given address
* :ccode:`const std::vector<address_range_t>& get_address_ranges()`: Get
  the address ranges (including a range and ``R/W`` specifier) for the
  peripheral

Calling :ccode:`read` / :ccode:`write` on an address not provided by
:ccode:`get_address_ranges` is undefined.

In turn, the ``FLPeripheral`` class provides the following functions
to the memory subsystem, to determine if a peripheral should be used:

* :ccode:`bool try_read( uint32_t addr, uint32_t* data )`: Read from
  the peripheral, returning if the read was successful (i.e. in the
  peripheral's range)
* :ccode:`bool try_write( uint32_t addr, uint32_t* data )`: Write to
  the peripheral, returning if the write was successful (i.e. in the
  peripheral's range)

The corresponding functions ``try_fl_read`` and ``try_fl_write`` are
provided to RTL across the DPI interface from
`blimp/fl/fl_peripherals.v <https://github.com/cornell-brg/blimp/blob/main/fl/fl_peripherals.v>`__,
defined in `blimp/fl/fl_peripherals.h <https://github.com/cornell-brg/blimp/blob/main/fl/fl_peripherals.h>`__
and implemented in `blimp/fl/fl_peripherals.cpp <https://github.com/cornell-brg/blimp/blob/main/fl/fl_peripherals.cpp>`__.
This way, our RTL simulations can use the functional-level behaviour,
instead of needing to map FPGA behaviour back to simulation actions.

.. admonition:: Improving the Peripheral Interface
   :class: note

   While the interface described above is fairly general, it prohibits
   some behaviour; notably, a cycle counter cannot currently be an
   ``FLPeripheral``, which has no notion of cycle count. To improve
   upon this, the ``FLPeripheral`` base class might be improved to
   include :ccode:`void step()` (called once each cycle) and/or
   :ccode:`void cleanup()` (called when the program/simulation finishes)

FPGA Implementations
--------------------------------------------------------------------------

Currently, only the ``Terminal`` peripheral is implemented for FPGA use:

* For standard input, a PS2 interface is `converted <https://github.com/cornell-brg/blimp/blob/main/fpga/ps2/Keyboard.v>`__
  into scancodes (representing key presses/releases), which are subsequently
  `converted <https://github.com/cornell-brg/blimp/blob/main/fpga/ps2/ScanCodeFilter.v>`__
  into character inputs
* For standard output, characters are sent to a `buffer <https://github.com/cornell-brg/blimp/blob/main/fpga/vga/CharBuf.v>`__,
  which stores all characters on the screen, and determines whether a
  pixel should be lit or not by its index on a screen. Combined with a
  `VGA Driver <https://github.com/cornell-brg/blimp/blob/main/fpga/vga/VGADriver.v>`__,
  the characters are able to be sent to a VGA screen to be displayed.
  Characters are scrolled when a line is completed, with newlines and
  deletes (on a single line) additionally being supported. The escape key
  is used to clear the entire screen.

Both of these functionalities are combined in the FPGA's
`peripheral memory server <https://github.com/cornell-brg/blimp/blob/main/fpga/PeripheralMemServer.v>`__,
which services memory requests from the memory network.
