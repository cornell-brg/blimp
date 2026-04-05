#=========================================================================
# 05-cadence-innovus-pnr/setup-timing.tcl
#=========================================================================

# We need to include the lib files for the standard cells and any
# generated SRAMs.

set lib_files [list \
  "$env(TSMC_180NM)/stdcells.lib" \
  {% for sram in srams | default([]) -%}
  "../00-openram-memgen/{{sram}}.lib" \
  {% endfor %}
]

create_rc_corner -name typical \
   -cap_table "$env(TSMC_180NM)/typical.captable" \
   -T 25

create_library_set -name libs_typical \
   -timing $lib_files

create_delay_corner -name delay_default \
   -library_set libs_typical \
   -rc_corner typical

create_constraint_mode -name constraints_default \
   -sdc_files [list ../03-synopsys-dc-synth/post-synth.sdc]

create_analysis_view -name analysis_default \
   -constraint_mode constraints_default \
   -delay_corner delay_default

set_analysis_view \
   -setup analysis_default \
   -hold analysis_default
