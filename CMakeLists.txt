# ========================================================================
# CMakeLists.txt
# ========================================================================
# A build system for Blimp

SET(CMAKE_CXX_STANDARD_LIBRARIES "")

#-------------------------------------------------------------------------
# Get all of the source files
#-------------------------------------------------------------------------

set(V_TEST_FILES
  fpga/test/CharBuf_test.v
  fpga/test/CharLUT_test.v
  hw/common/test/Fifo_test.v
  hw/common/test/PriorityEncoder_test.v
  hw/common/test/RRArb_test.v
  hw/common/test/MRRArb_test.v
  hw/decode_issue/test/DecodeIssueUnitL1_test.v
  hw/decode_issue/test/DecodeIssueUnitL2_test.v
  hw/decode_issue/test/DecodeIssueUnitL3_test.v
  hw/decode_issue/test/DecodeIssueUnitL4_test.v
  hw/decode_issue/test/DecodeIssueUnitL5_test.v
  hw/decode_issue/test/DecodeIssueUnitL6_test.v
  hw/decode_issue/test/DecodeIssueUnitL7_test.v
  hw/decode_issue/test/ImmGen_test.v
  hw/decode_issue/test/IssueQueueInOrder_test.v
  hw/decode_issue/test/RegfilePending_test.v
  hw/decode_issue/test/MRegfile_test.v
  hw/decode_issue/test/RenameTable_test.v
  hw/decode_issue/test/MRenameTable_test.v
  hw/execute/test/ExQueue_test.v
  hw/execute/test/l1/ALUL1_test.v
  hw/execute/test/l1/MultiplierL1_test.v
  hw/execute/test/l2/PipelinedMultiplierL2_test.v
  hw/execute/test/l2/IterativeMultiplierL2_test.v
  hw/execute/test/l3/LoadStoreUnitL3_test.v
  hw/execute/test/l4/ControlFlowUnitL4_test.v
  hw/execute/test/l5/ControlFlowUnitL5_test.v
  hw/execute/test/l6/ALUL6_test.v
  hw/execute/test/l6/ControlFlowUnitL6_test.v
  hw/execute/test/l7/IterativeMulDivRemL7_test.v
  hw/execute/test/l7/LoadStoreUnitL7_test.v
  hw/fetch/test/FetchUnitL1_test.v
  hw/fetch/test/FetchUnitL2_test.v
  hw/fetch/test/FetchUnitL3_test.v
  hw/fetch/test/SeqNumGenL2_test.v
  hw/fetch/test/SeqNumGenL3_test.v
  hw/squash/test/SquashUnitL1_test.v
  hw/squash/test/SquashUnitL1Chain_test.v
  hw/util/test/SeqAge_test.v
  hw/util/test/MSeqAge_test.v
  hw/util/test/SeqArb_test.v
  hw/writeback_commit/test/WritebackCommitUnitL1_test.v
  hw/writeback_commit/test/WritebackCommitUnitL2_test.v
  hw/writeback_commit/test/WritebackCommitUnitL3_test.v
  hw/writeback_commit/test/WritebackCommitUnitL4_test.v
  hw/writeback_commit/test/ROB_test.v
  hw/writeback_commit/test/MROB_test.v
)

set(ASM_FILES
  asm/assemble.cpp
  asm/disassemble.cpp
  asm/inst.cpp
  asm/fields.cpp
)

set(FL_PROC_FILES
  fl/FLInst.cpp
  fl/FLMem.cpp
  fl/FLPeripheral.cpp
  fl/FLProc.cpp
  fl/FLRegfile.cpp
  fl/FLTrace.cpp
  fl/fl_vtrace.cpp
  fl/fl_peripherals.cpp
  fl/parse_elf.cpp

  fl/peripherals/FLExit.cpp
  fl/peripherals/FLTerminal.cpp
)

set(APP_SUBDIRS
  app
)

#-------------------------------------------------------------------------
# Set the compiler
#-------------------------------------------------------------------------

set(CMAKE_C_COMPILER gcc)
set(CMAKE_CXX_COMPILER g++)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED True)

#-------------------------------------------------------------------------
# Boilerplate
#-------------------------------------------------------------------------

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

cmake_minimum_required(VERSION 3.10)
project(
  BLIMP 
  VERSION 1.0
  DESCRIPTION "BLIMP: BRG's Luculently-Interfaced Modular Processor"
  LANGUAGES Verilog C CXX ASM
)

include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/vdeps.cmake)
include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/vlint.cmake)

enable_testing()
include_directories(${CMAKE_CURRENT_SOURCE_DIR})

if(CMAKE_Verilog_COMPILER_ID STREQUAL "Verilator")
  add_compile_definitions("BLIMP_VERILATOR")
elseif(CMAKE_Verilog_COMPILER_ID STREQUAL "VCS")
  add_compile_definitions("BLIMP_VCS")
elseif(CMAKE_Verilog_COMPILER_ID STREQUAL "Iverilog")
  message(WARNING
    "Blimp uses many SystemVerilog features that Iverilog doesn't support\n"
    "Results may vary"
  )
endif()

#-------------------------------------------------------------------------
# Tracing
#-------------------------------------------------------------------------
# Disable by default for speed

if(NOT DEFINED TRACE)
set(TRACE 0)
endif()

#-------------------------------------------------------------------------
# Coverage Reporting
#-------------------------------------------------------------------------
# Disable by default for speed

if(NOT DEFINED COVERAGE)
set(COVERAGE 0)
endif()

#-------------------------------------------------------------------------
# get_leaf
#-------------------------------------------------------------------------
# Gets the leaf file of a path.

function(get_leaf VARNAME FILE_NAME)
  string(REGEX REPLACE "[^/]*/" "" NAME_WITHOUT_EXT ${FILE_NAME})
  set(${VARNAME} "${NAME_WITHOUT_EXT}" PARENT_SCOPE)
endfunction()

#------------------------------------------------------------------------
# remove_extension
#------------------------------------------------------------------------
# A function to remove a file's extension

function(remove_extension VARNAME FILE_NAME)
  string(REGEX REPLACE "\\.[^.]*$" "" NAME_WITHOUT_EXT ${FILE_NAME})
  set(${VARNAME} "${NAME_WITHOUT_EXT}" PARENT_SCOPE)
endfunction()

#------------------------------------------------------------------------
# version_name
#------------------------------------------------------------------------
# A function to get the version indicator from a Blimp version

function(version_name VNAME BLIMP_VERSION)
  # Check for FL
  if(BLIMP_VERSION STREQUAL "FLProc")
    set(${VNAME} "fl" PARENT_SCOPE)
    return()
  endif()

  string(REGEX MATCH "BlimpV([0-9]+)" BLIMP_VERSION ${BLIMP_VERSION})
  set(${VNAME} "v${CMAKE_MATCH_1}" PARENT_SCOPE)
endfunction()

#------------------------------------------------------------------------
# sim_name
#------------------------------------------------------------------------
# A function to convert a simulation Verilog file name to an executable
# name

function(sim_name SIMNAME FILE_NAME)
  string(REGEX MATCH "BlimpV(.+)_sim\\.v" FILE_NAME ${FILE_NAME})
  set(${SIMNAME} "v${CMAKE_MATCH_1}-sim" PARENT_SCOPE)
endfunction()

#------------------------------------------------------------------------
# add_prefix
#------------------------------------------------------------------------
# A function to add a prefix to all elements of a list

function(add_prefix LIST_VAR PREFIX)
  set(NEW_LIST_VAR "")
  foreach(ITEM ${${LIST_VAR}})
    list(APPEND NEW_LIST_VAR "${PREFIX}${ITEM}")
  endforeach(ITEM)
  set(${LIST_VAR} ${NEW_LIST_VAR} PARENT_SCOPE)
endfunction()

#------------------------------------------------------------------------
# ASM Library
#------------------------------------------------------------------------

add_library(ASM STATIC ${ASM_FILES})
target_compile_options(ASM PRIVATE -O3 -Wall -Wextra -Wpedantic -Werror)

#------------------------------------------------------------------------
# FL_PROC Library
#------------------------------------------------------------------------

add_library(FL_PROC STATIC ${FL_PROC_FILES})
target_link_libraries(FL_PROC PRIVATE ASM)
target_compile_options(FL_PROC PRIVATE -O3 -Wall -Wextra -Wpedantic -Werror)

#------------------------------------------------------------------------
# Add Blimp's tests
#------------------------------------------------------------------------

include(${CMAKE_CURRENT_SOURCE_DIR}/hw/top/test/tests.cmake)

foreach(BLIMP_VERSION ${BLIMP_VERSIONS})
  add_prefix(${BLIMP_VERSION}_TESTS "hw/top/test/")
  set(V_TEST_FILES
    ${V_TEST_FILES}
    ${${BLIMP_VERSION}_TESTS}
  )
endforeach()

#------------------------------------------------------------------------
# Add our SystemVerilog tests
#------------------------------------------------------------------------

add_custom_target(check COMMAND "ctest")
foreach(BLIMP_VERSION ${BLIMP_VERSIONS})
  version_name(BLIMP_VERSION_SHORT ${BLIMP_VERSION})
  add_custom_target(check-${BLIMP_VERSION_SHORT} COMMAND "ctest" "-L" "${BLIMP_VERSION}")
endforeach()

foreach(V_TEST_FILE_REL_PATH ${V_TEST_FILES})
  set(V_TEST_FILE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/${V_TEST_FILE_REL_PATH}")
  get_leaf(V_TEST_FILE ${V_TEST_FILE_PATH})
  remove_extension(V_TEST_BIN ${V_TEST_FILE})

  add_executable(${V_TEST_BIN} ${V_TEST_FILE_PATH})
  target_include_directories(${V_TEST_BIN} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR} ${CMAKE_Verilog_DPI_INCLUDES})

  if(CMAKE_Verilog_COMPILER_ID STREQUAL "Verilator")
    target_compile_options(${V_TEST_BIN} PRIVATE --timing --quiet-stats)
    if(TRACE)
      target_compile_options(${V_TEST_BIN} PRIVATE --trace --trace-structs)
    endif()
    if(COVERAGE)
      target_compile_options(${V_TEST_BIN} PRIVATE --coverage)
    endif()
  endif()

  if(CMAKE_Verilog_COMPILER_ID STREQUAL "VCS")
    target_link_options(${V_TEST_BIN} PRIVATE -full64 -xprop=tmerge)
    if(TRACE)
      target_link_options(${V_TEST_BIN} PRIVATE +vcs+dumpvars+${V_TEST_BIN}.vcd +vcs+vcdpluson +vcs+vcdplusmemon)
    endif()
    if(COVERAGE)
      target_link_options(${V_TEST_BIN} PRIVATE +cover=all -cm line+cond+tgl+fsm+branch -cm_dir ${V_TEST_BIN}.vdb)
    endif()
  endif()

  # Add our main simulation loop and libraries
  target_link_libraries(${V_TEST_BIN} PRIVATE FL_PROC)

  # Track dependencies
  vdeps(TEST_DEPS
    SOURCE ${V_TEST_FILE_REL_PATH}
    INCLUDE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}"
  )
  add_prefix(TEST_DEPS "${CMAKE_CURRENT_SOURCE_DIR}/")
  set_property(SOURCE ${V_TEST_FILE_PATH} APPEND PROPERTY OBJECT_DEPENDS ${TEST_DEPS})

  # Add linting
  vlint(${V_TEST_BIN}-lint
    TARGET_NAME ${V_TEST_BIN}
    SOURCES ${V_TEST_FILE_REL_PATH}
    INCLUDE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}"
    DEPENDS ${TEST_DEPS}
  )
  add_dependencies(${V_TEST_BIN} ${V_TEST_BIN}-lint)

  add_dependencies(check ${V_TEST_BIN})
  file(RELATIVE_PATH TEST_PATH ${CMAKE_CURRENT_SOURCE_DIR} ${V_TEST_FILE_PATH})
  remove_extension(TEST_NAME ${TEST_PATH})
  add_test(NAME ${TEST_NAME} COMMAND ${V_TEST_BIN})
  set(CMAKE_VTESTS ${CMAKE_VTESTS} ${V_TEST_BIN})
  set_tests_properties(
    ${TEST_NAME} PROPERTIES 
    FAIL_REGULAR_EXPRESSION "timeout!|One or more tests failed"
    TIMEOUT 20
  )

  # Include check commands for each version
  foreach(BLIMP_VERSION ${BLIMP_VERSIONS})
    if(${V_TEST_FILE_REL_PATH} IN_LIST ${BLIMP_VERSION}_TESTS)
      version_name(BLIMP_VERSION_SHORT ${BLIMP_VERSION})
      add_dependencies(check-${BLIMP_VERSION_SHORT} ${V_TEST_BIN})
      set_tests_properties(${TEST_NAME} PROPERTIES LABELS "${BLIMP_VERSION}")
    endif()
  endforeach(BLIMP_VERSION)
endforeach(V_TEST_FILE_REL_PATH)

#------------------------------------------------------------------------
# List tests
#------------------------------------------------------------------------

set(KNOWN_TESTS_TEXT "Available test targets:")
set(LIST_COMMANDS COMMAND ${CMAKE_COMMAND} -E echo "Available test targets:")
foreach(VTEST ${CMAKE_VTESTS})
  set(LIST_COMMANDS ${LIST_COMMANDS} COMMAND ${CMAKE_COMMAND} -E echo " - ${VTEST}")
endforeach(VTEST)

add_custom_target(
  list
  ${LIST_COMMANDS}
  COMMENT ${KNOWN_TEST_TEXT}
)

#------------------------------------------------------------------------
# Include RISCV programs
#------------------------------------------------------------------------

foreach(APP_SUBDIR ${APP_SUBDIRS})
  set(PROGS "")
  add_subdirectory(${APP_SUBDIR})
  add_prefix(SRC_FILES ${CMAKE_CURRENT_SOURCE_DIR}/${APP_SUBDIR}/)
  add_prefix(APP_FILES ${CMAKE_CURRENT_SOURCE_DIR}/${APP_SUBDIR}/)

  # Include native builds for all apps
  foreach(PROG ${PROGS})
    set(SRC_FILES ${${APP_SUBDIR}-${PROG}-files})
    add_prefix(SRC_FILES ${CMAKE_CURRENT_SOURCE_DIR}/${APP_SUBDIR}/)
    add_executable(${APP_SUBDIR}-${PROG}-native ${SRC_FILES})
    target_compile_options(${APP_SUBDIR}-${PROG}-native PRIVATE -O3 -Wall -Wextra -Wpedantic -Werror)
    target_include_directories(${APP_SUBDIR}-${PROG}-native PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/${APP_SUBDIR})
    set_target_properties(${APP_SUBDIR}-${PROG}-native PROPERTIES
      RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/${APP_SUBDIR}"
      OUTPUT_NAME ${PROG}-native
    )
  endforeach(PROG)
endforeach(APP_SUBDIR)

#-------------------------------------------------------------------------
# Include FL simulator
#-------------------------------------------------------------------------

add_executable(fl-sim fl/fl_sim.cpp)
target_compile_options(fl-sim PRIVATE -Wall -Wextra -Wpedantic -Werror)
target_link_libraries(fl-sim PRIVATE FL_PROC)

#------------------------------------------------------------------------
# Add our SystemVerilog simulators
#------------------------------------------------------------------------

include(${CMAKE_CURRENT_SOURCE_DIR}/hw/top/sim/sims.cmake)
add_prefix(BLIMP_SIMS "hw/top/sim/")

foreach(V_SIM_FILE_REL_PATH ${BLIMP_SIMS})
  set(V_SIM_FILE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/${V_SIM_FILE_REL_PATH}")
  get_leaf(V_SIM_FILE ${V_SIM_FILE_PATH})
  sim_name(V_SIM_BIN ${V_SIM_FILE})

  add_executable(${V_SIM_BIN} ${V_SIM_FILE_PATH} "hw/top/sim/utils/load_elf.cpp")
  target_include_directories(${V_SIM_BIN} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR} ${CMAKE_Verilog_DPI_INCLUDES})

  if(CMAKE_Verilog_COMPILER_ID STREQUAL "Verilator")
    set(V_COMPILE_FLAGS "--timing --quiet-stats")
    if(TRACE)
      set(V_COMPILE_FLAGS "${V_COMPILE_FLAGS} --trace --trace-structs")
    endif()
    set_source_files_properties(
      ${V_SIM_FILE_PATH}
      PROPERTIES
      COMPILE_FLAGS "${V_COMPILE_FLAGS}"
    )
  endif()
  
  # Add our main simulation loop and libraries
  target_link_libraries(${V_SIM_BIN} PRIVATE FL_PROC)

  # Track dependencies
  vdeps(SIM_DEPS
    SOURCE ${V_SIM_FILE_REL_PATH}
    INCLUDE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}"
  )
  add_prefix(SIM_DEPS "${CMAKE_CURRENT_SOURCE_DIR}/")
  set_property(SOURCE ${V_SIM_FILE_PATH} APPEND PROPERTY OBJECT_DEPENDS ${SIM_DEPS})

  # Add linting
  vlint(${V_SIM_BIN}-lint
    TARGET_NAME ${V_SIM_BIN}
    SOURCES ${V_SIM_FILE_REL_PATH}
    INCLUDE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}"
    DEPENDS ${SIM_DEPS}
  )
  add_dependencies(${V_SIM_BIN} ${V_SIM_BIN}-lint)
endforeach(V_SIM_FILE_REL_PATH)

#------------------------------------------------------------------------
# Add our CLI tools
#------------------------------------------------------------------------

add_subdirectory(tools)

foreach(TOOL_FILE_REL_PATH ${TOOL_FILES})
  set(TOOL_FILE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/tools/${TOOL_FILE_REL_PATH}")
  get_leaf(TOOL_FILE ${TOOL_FILE_PATH})
  remove_extension(TOOL_BIN ${TOOL_FILE})

  add_executable(${TOOL_BIN} ${TOOL_FILE_PATH})
  target_compile_options(${TOOL_BIN} PRIVATE -Wall -Wextra -Wpedantic -Werror)
  target_link_libraries(${TOOL_BIN} PRIVATE FL_PROC)
endforeach(TOOL_FILE_REL_PATH)