.PHONY: all compile sim cov-report clean help

VCS ?= vcs
VCS_FLAGS ?= -sverilog -full64 -timescale=1ns/1ps +v2k -debug_pp
# Coverage flags: enable all coverage types useful for covergroups/functional coverage
COV_FLAGS ?= -cm line+cond+fsm+branch

# directory containing this Makefile (so Makefile can be invoked from elsewhere)
MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# files to compile: look for .sv files next to this Makefile and in
# `coverage/` and `transactions/` subdirectories (paths are absolute so
# the Makefile can be run from another working directory, e.g. `../../build`).
SRCS := $(wildcard $(MAKEFILE_DIR)/*.sv $(MAKEFILE_DIR)/transactions/*.sv $(MAKEFILE_DIR)/coverage/*.sv)

# add CSR execute-unit sources located outside this test directory
CSR_DIR_REL := ../../../execute_units_l8
CSR_DIR := $(abspath $(MAKEFILE_DIR)/$(CSR_DIR_REL))
SRCS += $(CSR_DIR)/CSR.v $(CSR_DIR)/CSRFile.v

# Include directory: point to project root so `defs/` and `intf/` resolve
PROJ_ROOT := $(abspath $(MAKEFILE_DIR)/../../../../..)
INCDIRS := +incdir+$(PROJ_ROOT)

# Simulation top/test name (passed to the simulator as an argument). Some
# testbenches use a +TESTNAME or UVM testname macro; override TOP as needed.
TOP ?= tb

SIMV := simv
SIM_ARGS ?= +TOP=$(TOP)

all: sim

compile:
	@echo "Compiling: $(SRCS)"
	$(VCS) $(VCS_FLAGS) $(INCDIRS) $(COV_FLAGS) -top $(TOP) $(SRCS) -o $(SIMV)

sim: compile
	@echo "Running simulation (binary: ./$(SIMV))"
	./$(SIMV) $(SIM_ARGS)

# Try to generate a coverage report. Typical Synopsys workflow uses `urg` or
# `vcover`. This target attempts to call `urg` if available and otherwise
# prints guidance.
cov-report:
	@if command -v urg >/dev/null 2>&1; then \
	  echo "Found urg: generating coverage report (default output file: coverage_urg_report.xml)"; \
	  # `-dir` should point to the VCS VDB directory (often simv.vdb or csrc) -- adjust if needed
	  urg -dir simv.vdb -report coverage_urg_report.xml || echo "urg failed or needs different args"; \
	else \
	  echo "urg not found. If you have Synopsys tools, use `urg -dir <vdb_dir> -report <out>` or use vcover.`"; \
	fi

clean:
	@echo "Cleaning simulation products"
	rm -rf $(SIMV) csrc* simv* ucli.key vc_hdrs.h INCA_libs simv.vdb coverage_urg_report.xml

help:
	@echo "Makefile for running VCS with coverage (Makefile dir: $(MAKEFILE_DIR))"
	@echo "Usage: make -f $(abspath $(lastword $(MAKEFILE_LIST))) [target] TOP=<top>" \
		|| true
	@echo "Targets: all (default), compile, sim, cov-report, clean, help"
