#=========================================================================
# 05-cadence-innovus-pnr/run.tcl
#=========================================================================

#-------------------------------------------------------------------------
# Initial Setup
#-------------------------------------------------------------------------

# Suppress warnings that we have decided are not relevant/waivable

source "warnings.tcl"

# We need to include the lef files for the routing technology,
# standard cells, and any generated SRAMs.

set lef_files [list \
  "$env(TSMC_180NM)/apr-tech.tlef" \
  "$env(TSMC_180NM)/stdcells.lef" \
  {% for sram in srams | default([]) -%}
  "../00-artisan-sramgen/{{sram}}.lef" \
  {% endfor %}
]

set init_mmmc_file "setup-timing.tcl"
set init_verilog   "../03-synopsys-dc-synth/post-synth.v"
set init_top_cell  "{{design_name}}"
set init_lef_file  $lef_files
set init_pwr_net   "VDD"
set init_gnd_net   "VSS"

init_design

# Set the process node to 180nm for technology-specific optimizations

setDesignMode -process 180

# Limit routing and pin placement to be between layers 2 and 5,
# inclusive, metal 1 is reserved for local interconnect within
# standard cells and metal 6 and above are reserved for the power
# grid; this will help reduce congestion and improve routability, but
# may increase the overall area of the design since we are not able to
# use as many routing layers.

setDesignMode -bottomRoutingLayer 2
setDesignMode -topRoutingLayer    5

# Ensure that the constraints applied to VIA generation prevent any
# DRC violations.

setViaGenMode -ignore_viarule_enclosure false
setViaGenMode -optimize_cross_via true
setViaGenMode -ignore_DRC false
setViaGenMode -disable_via_merging true

# Turn off signal integrity analysis (i.e., signal cross-talk)

setDelayCalMode -SIAware false

# Turn off useful clock skew (i.e., the tools will try to reduce the
# clock skew across all flip-flops)

setOptMode -usefulSkew false

# Add in additional hold target slack to force Cadence Innovus to
# work harder; this way if it misses by a little we will still end up
# with positive hold slack.

setOptMode -holdTargetSlack 0.010

# Specify which standard cells to use when fixing hold time violations

setOptMode -holdFixingCells {
  BUFFD0BWP7T BUFFD10BWP7T BUFFD12BWP7T BUFFD1BWP7T BUFFD1P5BWP7T \
  BUFFD2BWP7T BUFFD2P5BWP7T BUFFD3BWP7T BUFFD4BWP7T BUFFD5BWP7T \
  BUFFD6BWP7T BUFFD8BWP7T
}

# Increase the number of significant digits in reports

set report_precision 4

#-------------------------------------------------------------------------
# Floorplanning
#-------------------------------------------------------------------------
# There are two primary floorplanning options: automatic and fixed.
#
# The automatic floorplan option will determine the overall dimensions
# given a target aspect ratio and placement density. Here is an
# example which targets an aspect ratio of 1.0 and placement density
# of 70% with a 10um border around the outside of the core area for the
# power ring.
#
#  floorPlan -r 1.0 0.70 10.0 10.0 10.0 10.0
#
# The fixed floorplan option uses a given width and height. Here is an
# example which targets a width of 200um and height of 100um with a
# 10um border around the outside of the core are for the power ring.
#
#  floorPlan -d 200 100 10.0 10.0 10.0 10.0
#

floorPlan {{ floorplan | default("-r 1.0 0.50 10.0 10.0 10.0 10.0") }}

#-------------------------------------------------------------------------
# Placement
#-------------------------------------------------------------------------

{% if srams is defined %}
# Add a small halo around all SRAMs to help with congestion

addHaloToBlock 4.8 4.8 4.8 4.8 -allMacro

# Preliminary concurrent placement of standard cells and SRAMs

set_macro_place_constraint -pg_resource_model {METAL1 0.2}
place_design -concurrent_macros
refine_macro_place

{% else %}
# Set the well tap standard cell and well tap spacing

set_well_tap_mode -cell TAPCELLBWP7T
addWellTap -cellInterval 29.68
{% endif %}

# Place and optimize the design 

place_opt_design

# Add tiehi/tielo cells which are used to connect constant values to
# either vdd or ground.

addTieHiLo -cell "TIEHBWP7T TIELBWP7T"

# Limit pin placement to be between layers 2 and 5, make depth 0.73um
# to make pin metal at least min area (0.202 um^2) since width is
# 0.28um

setPinConstraint -global -pinTemplate {2 3 4 5} -depth 0.73

# Try to place the input/output pins so they are close to the
# standard-cells they are connected to

assignIoPins -pin *

#-------------------------------------------------------------------------
# Power Routing
#-------------------------------------------------------------------------

globalNetConnect VDD -type pgpin -pin VDD -all -verbose 
globalNetConnect VSS -type pgpin -pin VSS -all -verbose

globalNetConnect VDD -type tiehi -pin VDD -all -verbose
globalNetConnect VSS -type tielo -pin VSS -all -verbose

# Route a power ring on M5 and M6 around the outside of the core area

addRing \
  -nets {VDD VSS} -width 2.6 -spacing 2.5 \
  -layer [list top 5 bottom 5 left 6 right 6] \
  -extend_corner {tl tr bl br lt lb rt rb}

# Route horizontal stripes on M6 for the power grid

addStripe \
  -nets {VSS VDD} -layer 5 -direction horizontal \
  -width 5.52 -spacing 16.88 \
  -set_to_set_distance 44.8 -start_offset 22.4

# Route vertical stripes on M5 for the power grid

addStripe \
  -nets {VSS VDD} -layer 6 -direction vertical \
  -width 5.52 -spacing 16.88 \
  -set_to_set_distance 44.8 -start_offset 22.4

# Route power and ground nets

sroute -nets {VDD VSS}

#-------------------------------------------------------------------------
# Clock-Tree Synthesis
#-------------------------------------------------------------------------

# Create the clock tree specification from the timing constraints

create_ccopt_clock_tree_spec

# Set max transition time for clock nets to help control the clock
# tree synthesis; this may help with timing closure, but may increase
# the area of the clock tree

foreach nt {trunk leaf} {
  set_ccopt_property target_max_trans 0.25ns \
                       -clock_tree ideal_clock1 -net_type $nt
}

# Control an optimization that allows Cadence Innovus to decide to add
# non-zero clock insertion source latency. Turning this on will
# complicate back-annotated gate-level simulation, but may enable
# closing timing for larger blocks.

set_ccopt_property update_io_latency {{ update_io_latency | default("false") }}

# Synthesize the clock tree

clock_opt_design

# Fix setup time violations by reducing the delay of the slow paths

optDesign -postCTS -setup

# Fix hold time violations by increasing the delay of the fast paths

optDesign -postCTS -hold

#-------------------------------------------------------------------------
# Routing
#-------------------------------------------------------------------------

# Fix antenna violations by adding antenna diodes

setNanoRouteMode -route_detail_fix_antenna true 
setNanoRouteMode -route_antenna_cell_name "ANTENNABWP7T" 
setNanoRouteMode -route_antenna_diode_insertion true

# Route the design

routeDesign

# Fix setup time violations by reducing the delay of the slow paths

optDesign -postRoute -setup

# Fix hold time violations by increasing the delay of the fast paths

optDesign -postRoute -hold

# Fix design rule violations

optDesign -postRoute -drv

# Extract the interconnect parasitics

extractRC

#-------------------------------------------------------------------------
# Finishing
#-------------------------------------------------------------------------

# Report the area broken down by module pre-filler

echo "Area pre-filler" > area.rpt
checkPlace >> area.rpt
report_area >> area.rpt

# Add filler cells to complete each row of standard cells

setFillerMode -core {FILL1BWP7T FILL2BWP7T FILL4BWP7T FILL8BWP7T \
  FILL16BWP7T FILL32BWP7T FILL64BWP7T}
addFiller

# Check the final physical design

verify_connectivity > connectivity.rpt
verify_drc          > drc.rpt
verify_antenna      > antenna.rpt

#-------------------------------------------------------------------------
# Outputs
#-------------------------------------------------------------------------

# Output design which can be loaded into Cadence Innovus later

saveDesign post-pnr.enc

# Output post-pnr gate-level netlist

saveNetlist post-pnr.v

# Output interconnect parasitics in SPEF format for power analsys

rcOut -rc_corner typical -spef post-pnr.spef

# Output timing delays in SDF format for back-annotated gate-level sim

write_sdf \
  -interconn nooutport \
  -recompute_delay_calc \
  post-pnr.sdf

# Output SDC file so we can check for clock source insertion latency

write_sdc -strict post-pnr.sdc

# Merge the standard-cell layout with the place and routed design to
# stream out the final layout for the block; note that we need to
# include the gds files for the standard cells. We currently are only
# using the front-end views for the SRAMs so we do not include the GDS
# for these macros.

streamOut post-pnr.gds \
  -units 1000 \
  -merge "$env(TSMC_180NM)/stdcells.gds" \
  -mapFile "$env(TSMC_180NM)/gds_out.map"

# Report the critical path (i.e., setup-time constraint)

report_timing -late  -path_type full_clock -net > timing-setup.rpt

# Report the short path (i.e., hold-time constraint)

report_timing -early -path_type full_clock -net > timing-hold.rpt

# Report the area broken down by module post-filler

echo "\nArea post-filler" >> area.rpt
checkPlace >> area.rpt
report_area -include_physical >> area.rpt

exit
