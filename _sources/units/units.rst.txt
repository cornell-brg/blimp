Microarchitectural Units
==========================================================================

Blimp outlines the following units as first-class microarchitectural
blocks in the processor:

.. toctree::
   :maxdepth: 1

   Fetch Unit (FU) <fetch_unit>
   Decode Issue Unit (DIU) <decode_issue_unit>
   Execute Units (XU) <execute_units>
   Writeback Commit Unit (WCU) <writeback_commit_unit>
   Sequencing Unit (SQU) <sequencing_unit>
   Squash Unit (SU) <squash_unit>

Each of these units have different levels at which they are implemented,
to be composed in processors of varying complexity.