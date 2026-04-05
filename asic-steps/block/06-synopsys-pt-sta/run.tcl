#=========================================================================
# 06-synopsys-pt-sta/run.tcl
#=========================================================================

#-------------------------------------------------------------------------
# Initial setup
#-------------------------------------------------------------------------

# We need to include the db files for the standard cells and any
# generated SRAMs.

set_app_var target_library [list \
  "$env(TSMC_180NM)/stdcells.db" \
  {% for sram in srams | default([]) -%}
  "../00-artisan-sramgen/{{sram}}.db" \
  {% endfor %}
]

set_app_var link_library [concat "*" $target_library]

# Increase the number of significant digits in reports

set_app_var report_default_significant_digits 4

#-------------------------------------------------------------------------
# Inputs
#-------------------------------------------------------------------------

read_verilog ../05-cadence-innovus-pnr/post-pnr.v
current_design {{ design_name }}
link_design

read_parasitics -format spef ../05-cadence-innovus-pnr/post-pnr.spef
read_sdc ../05-cadence-innovus-pnr/post-pnr.sdc -version 1.9

#-------------------------------------------------------------------------
# Check design constraints
#-------------------------------------------------------------------------

check_timing
check_constraints

#-------------------------------------------------------------------------
# Static timing analysis
#-------------------------------------------------------------------------

update_timing

#-------------------------------------------------------------------------
# Outputs
#-------------------------------------------------------------------------

report_global_timing -delay_type max > timing-setup-summary.rpt
report_timing -nets -delay_type max > timing-setup.rpt

report_global_timing -delay_type min > timing-hold-summary.rpt
report_timing -nets -delay_type min > timing-hold.rpt

exit
