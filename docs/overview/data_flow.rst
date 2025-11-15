Data Flow in the Processor
==========================================================================

.. raw:: html

    <style> .blimp-blue {color:#2094F3; font-weight:bold; font-size:16px} </style>
    <style> .blimp-green {color:#97D077; font-weight:bold; font-size:16px} </style>

.. role:: blimp-blue

.. role:: blimp-green

Blimp is composed of many units, and also defines the methods by which
units can communicate. Currently, there are two classes of communication
methods:

 - **Latency-Insensitive** interfaces are used to communicate information
   down the pipeline. These include a ``val`` and a ``rdy`` signal, so
   that units later in the pipeline can back-pressure earlier units when
   they aren't ready. Because of this, latency-insensitive interfaces can
   *only* proceed down the pipeline, never from later units to earlier
   units (which could cause circular deadlock). Instructions will follow
   these paths along their lifetime as they're propagated between units.
   In Blimp's diagrams, you'll see these as :blimp-blue:`blue arrows`.

 - **Latency-Sensitive** interfaces (also known as **notifications**)
   are used to propagate information anywhere in the pipeline. These
   are for signals which cannot be backpressured (and must be acted on
   in the same cycle), and therefore only have a ``val`` signal (no
   ``rdy``). However, this lack of backpressure means that units can
   notify other units throughout the processor (although they're
   typically used to communicate to earlier units). Notifications are
   used to communicate information which must be acted on immediately,
   such as writebacks, commits, and squashes. In Blimp's diagrams,
   you'll see these as :blimp-green:`green arrows`.

Latency-Insensitive interfaces are named as ``<src>__<dest>Intf``, to
indicate what units they're communicating between. For example, the
``F__DIntf`` is used to communicate instructions from the FU to the DIU.

Notifications don't require a single source and/or
destination, and are therefore named according to their semantics.
Currently, Blimp uses three types of notifications:

 - **Complete** notifications (single source, single destination, named
   ``CompleteNotif``) are used to communicate when an instruction is
   done executing, writing back the value to the register file if needed.
   This notification starts at the WCU, and notifies the DIU.
 - **Commit** notifications (single source, multiple destinations, named
   ``CommitNotif``) are used to communicate when an instruction commits,
   allowing the physical register and sequence number to be freed. This
   notification starts at the WCU, and can notify both the DIU (when
   renaming registers) and the FU (when using sequence numbers)
 - **Squash** notifications (multiple sources, multiple destinations,
   named ``SquashNotif``) are used to communicate when an instruction
   wants to squash all later instructions in the pipeline. Squashes can
   originate at multiple units (namely the DIU for jumps, as well as
   a control flow execute unit for branches), and need to notify
   multiple units, depending on where instructions may need to
   be squashed:

   - Version 5 only notifies the FU, since squashes can only originate
     in the DIU
   - Versions 6+ notify both the FU and DIU, since squashes can now
     originate from an execute unit (needing to squash the DIU)
   - Later versions may need to propagate squash notifications to
     execute units and the WCU, depending on where instructions that
     need to be squashed could be (see :doc:`todo`)

   When squash notifications can come from multiple places, a
   :doc:`../units/squash_unit` is needed to arbitrate and select the
   oldest squash.

Lastly, the ``InstTraceNotif`` notification also exists, using signals
also sent from the ``CommitNotif``. This notification doesn't provide
any additional processor functionality, but rather communicates
information about committing instructions outside of the processor. It
is used for processor verification to make sure that the results of
instructions are what we expect, as well as to compare them to the
results from the functional-level processor.
 