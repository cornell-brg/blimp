#=========================================================================
# 03-synopsys-dc-synth/run.tcl
#=========================================================================

#-------------------------------------------------------------------------
# Initial setup
#-------------------------------------------------------------------------

# Suppress warnings that we have decided are not relevant/waivable
source "warnings.tcl"

# We need to include the db files for the standard cells and any
# generated SRAMs.

set_app_var target_library [list \
  "$env(TSMC_180NM)/stdcells.db" \
  {% for sram in srams | default([]) -%}
  "../00-openram-memgen/{{sram}}.db" \
  {% endfor %}
]

set_app_var synthetic_library dw_foundation.sldb
set_app_var link_library [concat "*" $target_library $synthetic_library]

# Use alib cache for faster runs

set_app_var alib_library_analysis_path alib

# Increase the number of significant digits in reports

set_app_var report_default_significant_digits 4

# Set work directory

define_design_lib WORK -path work

# Ensure synchronous reset

set hdlin_ff_always_sync_set_reset      true
set compile_seqmap_honor_sync_set_reset true

# Turn off synopsys formality

set_svf -off

#-------------------------------------------------------------------------
# Inputs
#-------------------------------------------------------------------------

analyze -format sverilog ../01-verilator-pickle/{{design_name}}_pickled.v
elaborate {{design_name}}

#-------------------------------------------------------------------------
# Timing constraints
#-------------------------------------------------------------------------

# Clock period constraint

create_clock clk -name ideal_clock1 -period {{clock_period}}

# Set the assumed propagation and contamination delay for inputs

set_input_delay -clock ideal_clock1 -max 0.050 [all_inputs -exclude_clock_ports]
set_input_delay -clock ideal_clock1 -min 0     [all_inputs -exclude_clock_ports]

# Set the assumed setup and hold time constraints for outputs

set_output_delay -clock ideal_clock1 -max 0.050 [all_outputs]
set_output_delay -clock ideal_clock1 -min 0     [all_outputs]

# Constraint all feed-through paths (i.e., combinational paths from
# inputs to outputs to take no longer than one clock cycle

set_max_delay {{ clock_period }} -from [all_inputs -exclude_clock_ports] -to [all_outputs]

# Set the max transition for any net in the design

set_max_transition 0.250 {{design_name}}

# Set the assumed driving cell for all inputs. Ideally we want to use
# something like this:
#
#  set_driving_cell -no_design_rule -lib_cell INVD1BWP7T [all_inputs]
#
# However, using set_driving cell causes Cadence Innovus to factor in
# a "Drive Adjustment" into its timing analysis (which is fine) but
# then this "Drive Adjustment" is not written into the SDF file (which
# is not fine). This can cause hold time violations in the
# back-annotated gate-level simulation because the timing analysis
# assumes there is a drive adjustment but there is no drive adjustment
# in the actual simulation. So for now, we just force all input
# transitions to be instantaneous.

set_input_transition 0 [all_inputs]

# Set the assumed load for all outputs

set_load 0.005 [all_outputs]

{% if retiming is defined %}
# Register retiming

{% endif %}
{% for module in retiming | default([]) -%}
set_optimize_registers true \
  -design {{ module }}  \
  -check_design -verbose -print_critical_loop \
  -clock ideal_clock1 -delay_threshold {{ clock_period }}

{% endfor %}
# Check all timing constraints to make sure there are no issues

check_timing

#-------------------------------------------------------------------------
# Synthesis
#-------------------------------------------------------------------------

# Check the design for common issues

check_design

# compile_ultra enables more optimized synthesis compared to compile.
# We use -no_autoungroup to prevent Synopsys DC from flattening the
# design chich can complicated understanding timing, area, and energy.
# We use -gate_clock to turn on clock gating.

# compile_ultra enables more optimized synthesis compared to compile.
# We use -no_autoungroup to prevent Synopsys DC from flattening the
# design chich can complicated understanding timing, area, and energy.
# We use -gate_clock to turn on clock gating.

compile_ultra -no_autoungroup -gate_clock

#-------------------------------------------------------------------------
# Outputs
#-------------------------------------------------------------------------

# Output the design which can be loaded into Synopsys DV later

write -format ddc -hierarchy -output post-synth.ddc

# Output the post-synth gate-level netlist

define_name_rules verilog -preserve_struct_ports
change_names -rules verilog -hierarchy
write -format verilog -hierarchy -output post-synth.v

# Output the final timing constraints

write_sdc post-synth.sdc

# Report the critical path (i.e., setup-time constraint)

report_timing -nets > timing.rpt

# Report the area broken down by module

report_area -hierarchy > area.rpt

# Report which DesignWare components were used

report_resources -hierarchy > resources.rpt

exit
