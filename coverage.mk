.PHONY: coverage

coverage:
	python ../verilator_coverage_split.py
	verilator_coverage --annotate coverage/total coverage.dat
	verilator_coverage --annotate coverage/total_details coverage.dat --annotate-points
	verilator_coverage --annotate coverage/line line.dat
	verilator_coverage --annotate coverage/line_details line.dat --annotate-points
	verilator_coverage --annotate coverage/toggle toggle.dat
	verilator_coverage --annotate coverage/toggle_details toggle.dat --annotate-points
	verilator_coverage --annotate coverage/branch branch.dat
	verilator_coverage --annotate coverage/branch_details branch.dat --annotate-points
	verilator_coverage --annotate coverage/functional functional.dat
	verilator_coverage --annotate coverage/functional_details functional.dat --annotate-points
