.. Blimp documentation master file, created by
   sphinx-quickstart on Tue Nov 26 23:07:46 2024.
   You can adapt this file completely to your liking, but it should at least
   contain the root `toctree` directive.

Blimp Documentation
==========================================================================

This is the home for Blimp's documentation, including installation, the
overall framework, and how users can use and/or modify implementations.

*Documentation is under construction - stay tuned for blank sections!*

.. toctree::
   :maxdepth: 1
   :caption: Overview

   overview/motivation
   overview/data_flow
   overview/versions
   overview/repository_structure
   overview/build_system
   overview/dependencies
   overview/todo

.. toctree::
   :maxdepth: 2
   :caption: Microarchitectural Units

   units/units

.. toctree::
   :maxdepth: 1
   :caption: Microarchitectural Details

   uarch/seq_nums.rst

.. toctree::
   :maxdepth: 1
   :caption: Functional Level (FL) Utilities

   fl/assembler
   fl/proc

.. toctree::
   :maxdepth: 1
   :caption: FPGA Implementation

   fpga/peripherals
   fpga/network

.. toctree::
   :maxdepth: 1
   :caption: Demonstrations

   demos/sim_demo
   demos/quartus_demo
