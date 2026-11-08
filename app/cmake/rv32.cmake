# ========================================================================
# rv32.cmake
# ========================================================================
# A toolchain for compiling RISCV binaries for Blimp
# Based off of Derin Ozturk's toolchain: 
#  - https://github.com/cornell-brg/ento-bench/blob/main/gem5-cmake/rv32-gem5.cmake

if(RISCV_TOOLCHAIN_INCLUDED)
  return()
endif(RISCV_TOOLCHAIN_INCLUDED)

if(NOT DEFINED RISCV_TOOLCHAIN_CONFIGURED)
  if(NOT DEFINED TOOLCHAIN_PREFIX)
    set(TOOLCHAIN_PREFIX riscv64-unknown-elf- CACHE STRING "")
  endif()

  FIND_FILE(RISCV_GCC_COMPILER ${TOOLCHAIN_PREFIX}gcc PATHS ENV INCLUDE ${PATH} "/classes/c2s2/easybuild-rhel/software/riscv-gnu-toolchain/2024.02.02-GCCcore-13.2.0/bin")
  if (EXISTS ${RISCV_GCC_COMPILER})
    message(STATUS "Found RISC-V GCC Toolchain: ${RISCV_GCC_COMPILER}")
  else()
    message(FATAL_ERROR "RISC-V GCC Toolchain not found!")
  endif()

  get_filename_component(RISCV_TOOLCHAIN_BIN_PATH ${RISCV_GCC_COMPILER} DIRECTORY CACHE)
  get_filename_component(RISCV_TOOLCHAIN_BIN_GCC ${RISCV_GCC_COMPILER} NAME_WE CACHE)
  get_filename_component(RISCV_TOOLCHAIN_BIN_EXT ${RISCV_GCC_COMPILER} EXT CACHE)
  message(STATUS "Found RISCV toolchain path: ${RISCV_TOOLCHAIN_BIN_PATH}")
  message(STATUS "Found RISCV toolchain prefix: ${RISCV_TOOLCHAIN_BIN_GCC}")
  message(STATUS "Found RISCV toolchain ext: ${RISCV_TOOLCHAIN_BIN_EXT}")
  set(RISCV_TOOLCHAIN_CONFIGURED true CACHE INTERNAL "")
endif()

set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR RISCV)

set(CMAKE_C_COMPILER ${RISCV_TOOLCHAIN_BIN_PATH}/${TOOLCHAIN_PREFIX}gcc)
set(CMAKE_CXX_COMPILER ${RISCV_TOOLCHAIN_BIN_PATH}/${TOOLCHAIN_PREFIX}g++)
set(CMAKE_ASM_COMPILER ${RISCV_TOOLCHAIN_BIN_PATH}/${TOOLCHAIN_PREFIX}gcc)
set(CMAKE_AR ${RISCV_TOOLCHAIN_BIN_PATH}/${TOOLCHAIN_PREFIX}ar)
set(CMAKE_OBJCOPY ${RISCV_TOOLCHAIN_BIN_PATH}/${CROSS_COMPILE}objcopy CACHE FILEPATH "The toolchain objcopy command " FORCE)
set(CMAKE_OBJDUMP ${RISCV_TOOLCHAIN_BIN_PATH}/${CROSS_COMPILE}objdump CACHE FILEPATH "The toolchain objdump command " FORCE)

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -O3 -D_RISCV -fno-builtin -march=rv32im -mabi=ilp32")
set(CMAKE_CXX_FLAGS "${CMAKE_C_FLAGS} -std=c++20")
set(CMAKE_ASM_FLAGS "${CMAKE_C_FLAGS}")
set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -march=rv32im -mabi=ilp32 -nostdlib -nostartfiles -Wl,--no-warn-rwx-segments -L${CMAKE_CURRENT_BINARY_DIR}" )