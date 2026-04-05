#=========================================================================
# 08-synopsys-pt-pwr/run.tcl
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

# Turn on power analysis

set_app_var power_enable_analysis true

#-------------------------------------------------------------------------
# Inputs
#-------------------------------------------------------------------------

read_verilog ../05-cadence-innovus-pnr/post-pnr.v
current_design {{ design_name }}
link_design

read_saif ../07-synopsys-vcs-baglsim/$env(EVALNAME).saif -strip_path $env(SIMNAME)/dut
read_parasitics -format spef ../05-cadence-innovus-pnr/post-pnr.spef
read_sdc ../05-cadence-innovus-pnr/post-pnr.sdc -version 1.9

#-------------------------------------------------------------------------
# Power analysis
#-------------------------------------------------------------------------

update_power

#-------------------------------------------------------------------------
# Outputs
#-------------------------------------------------------------------------

report_power            > $env(EVALNAME)-summary.rpt
report_power -hierarchy > $env(EVALNAME)-detailed.rpt

exit
