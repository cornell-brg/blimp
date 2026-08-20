> [!IMPORTANT]
> **Blimp has been superseded by [Zeppelin](https://github.com/cornell-brg/zeppelin).**
> This repository is no longer actively developed and is kept for reference.

# BLIMP
BRG’s Luculently Interfaced Modular Processor

<p align="center">
  <img src="docs/_static/img/blimp_no_border.png" alt="A tech-inspired blimp" width="50%"/>
</p>

## Documentation

The main documentation for Blimp can be found on the [GitHub Pages](https://cornell-brg.github.io/blimp/)

## Testing

Blimp uses CMake as its build system generator. To begin testing, first generate the build
system using CMake, optionally specifying either `Verilator` or `VCS` as the Verilog compiler
(Blimp uses Verilator by default)

```bash
mkdir build
cd build
cmake .. -DCMAKE_Verilog_COMPILER_ID=Verilator
```

From there, users can run any individual test by specifying its name as a target:

```bash
make ALU_test
```

Known tests can be listed with the `list` target.

Tests for a specific top-level version `N` can be run with the target `check-vN`

```bash
make check-v7
```

Finally, all tests can be run with the `check` target

```bash
make check
```

Running tests as shown above can often be slow; users may additionally
want to specify a level of parallelism (ex. `make -j ALU_test`) or
specify a different backend when generating the build system (ex.
`cmake .. -GNinja`)

## Simulation

Simulation programs are kept in the `app` directory. A given program
can be built natively by with the target `app-<program>-native`,
which will build `<program>-native` in the `app` directory

```bash
make app-hello-native
./app/hello-native
```

Programs can also be built for RISCV by omitting the `native` suffix

```bash
make app-hello
```

These can then be run using the functional-level simulator, specifying
the path to the ELF file

```bash
make fl-sim
./fl-sim app/hello
```

They can also be run on a specific Blimp version by making the
corresponding simulator

```bash
make v7-sim
./v7-sim +elf=app/hello
```
