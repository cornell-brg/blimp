#=========================================================================
# 03-synopsys-dc-synth/dc-warnings.tcl
#=========================================================================
#
# ELAB 2084       - Original RTL file not found, so checksum can't be performed

set suppress_list {
  {ELAB-2084}
}

foreach item $suppress_list {
  suppress_message {*}$item
}
