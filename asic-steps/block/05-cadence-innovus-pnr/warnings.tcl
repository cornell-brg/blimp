#=========================================================================
# 05-cadence-innovus-pnr/warnings.tcl
#=========================================================================
#
# IMPLF-200/201 : Pin "pin" in macro "macro" has no ANTENNADIFFAREA value defined
# - This is an issue with the lef files themselves from TSMC
# TECHLIB-302 : No function defined for cell "cell"
# - This is an issue with the db/lib files themselves from TSMC
# IMPVL-159 : Pin "pin" of cell "cell" is defined in LEF but not in the timing library
# - This is an issue with the lef files themselves from TSMC
# IMPFP-325 : Floorplan of the design is resized
# - This is expected since we resize the floorplan manually
# IMPFP-3961 : The techSite "site" has no related standard cells in the LEF/OA library
# - This is an issue with the apr-tech file itself from TSMC
# IMPPSP-1501 : Ignored degenerated net
# - This is just Innovus saying that a net has been redefined (normally an I/O cell PAD net)
# IMPSP-9025 : No scan chain specified/traced
# - This is expected - we do not use scan chains (yet)
# IMPOPT-3195 : Analysis mode has changed
# - This is expected - we set the analysis mode ourselves
# IMPOPT-7329 : Skipping refinePlace due to user configuration
# - We do not use refinePlace for our flow - this is OK
# IMPPP-141 : Instances "io" and "io/NAME" overlap
# - We place our bondpads on top of the I/O cells - Innovus complains about 
#   an overlap but this is expected and has been manually verified
# IMPSR-1254/1255 : Unable to connect specified objects since block pins of VDD/VSS
#                   net were not found in the design/Cannot find any non 'CLASS CORE'
#                   pad pin of net VDD/VSS
# - The VDD/VSS net is internal to the padring and thus Innovus complains, this is OK
#   and has been manually verified during the final LVS stage
# IMPCCOPT-2015 : Innovus will not update I/O latencies for the following reason(s)
# - Depending on the configuration, CCOpt property update_io_latency is false
#   to prevent complications during baglsim
# IMPOPT-7139 : 'setExtractRCMode -coupled false' has been implicitly activated 
#               since current delay calulation is under SIAware false mode
# - The standard flow has signal-integrity awareness turned off, thus this
#   is expected
# IMPOGDS-250 : Specified unit is smaller than the one in db. You may have rounding problems
# - The database unit is 2000 unit/um while we set the output unit to be 1000 unit/um
#   since Calibre requires it to be in 1000 unit/um - we have not found any issues
#   with rounding yet so this is OK to suppress

set suppress_list {
  {IMPLF 200 201}
  {TECHLIB 302}
  {IMPVL 159}
  {IMPFP 325 3961}
  {IMPPSP 1501}
  {IMPSP 9025}
  {IMPOPT 3195 7139 7329}
  {IMPPP 141}
  {IMPSR 1254 1255}
  {IMPCCOPT 2015}
  {IMPOGDS 250}
}

foreach item $suppress_list {
  suppressMessage {*}$item
}
