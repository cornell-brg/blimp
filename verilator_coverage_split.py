#=========================================================================
# verilator_coverage_split.py
#=========================================================================
# Simple script to parse the Verilator coverage output into separate files
# by coverage type: line, toggle, branch, and functional (user).
# 
# Author: Simeon Turner


line_file = "# SystemC::Coverage-3\n"
toggle_file = "# SystemC::Coverage-3\n"
branch_file = "# SystemC::Coverage-3\n"
user_file = "# SystemC::Coverage-3\n"

# Read the coverage file

with open("coverage.dat", 'r') as file:
  for line in file:
    if "v_line" in line:
      line_file += line
    elif "v_toggle" in line:
      toggle_file += line
    elif "v_branch" in line:
      branch_file += line
    elif "v_user" in line:
      user_file += line

# Write out all of the individual coverage files by type

with open("line.dat", 'w') as file:
  file.write(line_file)

with open("toggle.dat", 'w') as file:
  file.write(toggle_file)

with open("branch.dat", 'w') as file:
  file.write(branch_file)

with open("functional.dat", 'w') as file:
  file.write(user_file)
