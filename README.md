# Blimp (test-framework)

This is a proposed SystemVerilog test framework to be used within Blimp,
as well as across BRG. It makes use of high-level SystemVerilog features
to make testing easy and resemble other languages.

Currently, an example GCD module is implemented as a minimal
proof-of-concept

## Running Tests

CMake is used as the build framework; accordingly, to run the tests we
must first generate the build system with CMake in a build directory:

```bash
mkdir build
cd build
cmake ..
```

From there, we can make and run any test that we want, as defined in
the top-level CMakeLists.txt (with the test name being the name
of the file without an extension)

```bash
make GcdUnit_test
./GcdUnit_test
```

Alternatively, one can use `make check` to run all tests at once with
`ctest`

## Test Arguments

The testing framework supports a few arguments for ease of testing, using
SystemVerilog's `+` notation to pass arguments to the main simulator:

 - `+test-suite=<num>`: Runs only the test suite of the specified number
 - `+filter=<text>`: Runs only tests that have `<text>` in their name
 - `+v`: Increases verbosity to enable linetracing
 - `+dump-vcd=/path/to/file.vcd`: Dumps a VCD waveform to the specified
   file