#!/usr/bin/env python3
#=========================================================================
# generate_tests.py
#=========================================================================
# Generates a single-suite BlimpV11 test file.
#
# Reads the original test file from hw/top/test/BlimpV11_test/, keeps
# the suite module definition intact, and replaces the multi-suite
# instantiation template with a single suite.
#
# Usage:
#   python3 generate_tests.py <test_name> [-DKEY=VALUE ...] [-o <output_dir>]

import argparse
import re
import os
import sys

# Path to the original test files relative to the repo root.
# Derived from test name prefix (e.g. BlimpV8_bne_test -> BlimpV8_test).
ORIG_TEST_DIR_FMT = "hw/top/test/{prefix}_test"


def find_repo_root():
    """Walk up from this script's location to find the repo root."""
    d = os.path.dirname(os.path.abspath(__file__))
    while d != "/":
        if os.path.isdir(os.path.join(d, ".git")):
            return d
        d = os.path.dirname(d)
    return None


def parse_original_test(filepath):
    """Parse an original test file and return its two parts.

    Returns (suite_def, suite_module_name, bottom_module_name) where
    suite_def is everything from the start of the file through the first
    endmodule (the test suite module definition).
    """
    with open(filepath) as f:
        content = f.read()

    # Split on the second module declaration (the bottom instantiation module)
    # Pattern: find the second 'module' keyword at the start of a line
    modules = list(re.finditer(r"^module\s+(\w+)", content, re.MULTILINE))
    if len(modules) < 2:
        raise ValueError(f"Expected 2 modules in {filepath}, found {len(modules)}")

    suite_module_name = modules[0].group(1)
    bottom_module_name = modules[1].group(1)

    # suite_def = everything up to (and including) the first endmodule
    endmodule_match = re.search(r"^endmodule", content, re.MULTILINE)
    if not endmodule_match:
        raise ValueError(f"No endmodule found in {filepath}")

    suite_def = content[:endmodule_match.end()]

    return suite_def, suite_module_name, bottom_module_name


def generate_test_file(suite_def, suite_module_name, bottom_module_name,
                       param_overrides):
    """Generate a new test file with a single suite using the given params."""

    # Build parameter override string with aligned columns
    all_params = [("p_suite_num", "1")] + \
                 [(p, str(v)) for p, v in param_overrides.items()]

    max_name_len = max(len(p) for p, _ in all_params)

    param_lines = []
    for param, value in all_params:
        padding = " " * (max_name_len - len(param))
        param_lines.append(f"    .{param}{padding} ({value})")
    params_str = ",\n".join(param_lines)

    out = f"""{suite_def}

module {bottom_module_name};

  {suite_module_name} #(
{params_str}
  ) suite_1();

  initial begin
    test_bench_begin( `__FILE__ );
    suite_1.run_test_suite();
    test_bench_end();
  end

endmodule
"""
    return out


def main():
    parser = argparse.ArgumentParser(
        description="Generate a single-suite BlimpV11 test file.")
    parser.add_argument("test_name",
                        help="Name of the test to generate (e.g. BlimpV11_test)")
    parser.add_argument("-D", dest="defines", action="append", default=[],
                        metavar="KEY=VALUE",
                        help="Parameter override in -DKEY=VALUE format "
                             "(can be specified multiple times)")
    parser.add_argument("-o", "--output-dir", default=".",
                        help="Output directory for generated test files "
                             "(default: current directory)")
    args = parser.parse_args()

    # Convert -DKEY=VALUE defines to parameter overrides dict
    param_overrides = {}
    for d in args.defines:
        if "=" in d:
            key, val = d.split("=", 1)
            param_overrides[key.lower()] = val

    # Find repo root for locating original test files
    repo_root = find_repo_root()
    if repo_root is None:
        print("Error: could not find repo root (.git directory)",
              file=sys.stderr)
        sys.exit(1)

    os.makedirs(args.output_dir, exist_ok=True)

    test_name = args.test_name
    # Derive the test directory from the test name prefix
    # e.g. BlimpV8_bne_test -> BlimpV8, BlimpV11_bne_test -> BlimpV11
    parts = test_name.split("_")
    prefix = parts[0]
    orig_test_dir = ORIG_TEST_DIR_FMT.format(prefix=prefix)
    src_path = os.path.join(repo_root, orig_test_dir, f"{test_name}.v")
    if not os.path.exists(src_path):
        print(f"Error: source test file not found: {src_path}",
              file=sys.stderr)
        sys.exit(1)

    suite_def, suite_module_name, bottom_module_name = \
        parse_original_test(src_path)

    output = generate_test_file(suite_def, suite_module_name,
                                bottom_module_name, param_overrides)

    out_path = os.path.join(args.output_dir, f"{test_name}.v")
    with open(out_path, "w") as f:
        f.write(output)

    print(f"Generated {out_path}")


if __name__ == "__main__":
    main()
