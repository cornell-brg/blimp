# ========================================================================
# CMakeLists.txt
# ========================================================================
# A build system for blimp

#-------------------------------------------------------------------------
# Get all of the test files
#-------------------------------------------------------------------------

set(V_TEST_FILES
  hw/gcd/test/GcdUnit_test.v
)

#-------------------------------------------------------------------------
# Boilerplate
#-------------------------------------------------------------------------

cmake_minimum_required(VERSION 3.10)
project(BLIMP VERSION 1.0)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED True)

enable_testing()

#-------------------------------------------------------------------------
# verilator_share_from_bin
#-------------------------------------------------------------------------
# Hacky way to Verilator's share directory from the bin directory

function(verilator_share_from_bin VARNAME BIN)
  get_filename_component(BIN_DIR ${BIN} DIRECTORY)
  get_filename_component(INSTALL_DIR ${BIN_DIR} DIRECTORY)
  set(${VARNAME} "${INSTALL_DIR}/share/verilator" PARENT_SCOPE)
endfunction()

#------------------------------------------------------------------------
# Import Verilator
#------------------------------------------------------------------------

find_program(VERILATOR_BIN "verilator")
verilator_share_from_bin(VERILATOR_SHARE ${VERILATOR_BIN})

list(APPEND CMAKE_PREFIX_PATH ${VERILATOR_SHARE})

find_package(verilator REQUIRED)

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
# Add our targets
#------------------------------------------------------------------------

add_custom_target(check COMMAND "ctest" "--timeout" "10")
set(V_INCL_DIR ${CMAKE_CURRENT_SOURCE_DIR})

foreach(V_TEST_FILE_REL_PATH ${V_TEST_FILES})
  set(V_TEST_FILE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/${V_TEST_FILE_REL_PATH}")
  get_leaf(V_TEST_FILE ${V_TEST_FILE_PATH})
  remove_extension(V_TEST_BIN ${V_TEST_FILE})

  add_executable(${V_TEST_BIN} "${CMAKE_CURRENT_SOURCE_DIR}/test/sim.cpp")
  set(CMAKE_VTESTS ${CMAKE_VTESTS} ${V_TEST_BIN})

  target_compile_definitions(${V_TEST_BIN} PRIVATE 
    VERILATOR_INCL_HEADER="V${V_TEST_BIN}.h"
    VERILATOR_DPI_HEADER="V${V_TEST_BIN}__Dpi.h"
    VERILATOR_TOP_MODULE=V${V_TEST_BIN}
  )
  verilate(
    ${V_TEST_BIN} 
    SOURCES ${V_TEST_FILE_PATH} 
    INCLUDE_DIRS ${V_INCL_DIR}
    TRACE
    TRACE_STRUCTS
    VERILATOR_ARGS --timing --flatten --quiet-stats
  )

  add_dependencies(check ${V_TEST_BIN})
  file(RELATIVE_PATH TEST_PATH ${CMAKE_CURRENT_SOURCE_DIR} ${V_TEST_FILE_PATH})
  remove_extension(TEST_NAME ${TEST_PATH})
  add_test(NAME ${TEST_NAME} COMMAND ${V_TEST_BIN})
endforeach(V_TEST_FILE_REL_PATH)

#------------------------------------------------------------------------
# List tests
#------------------------------------------------------------------------

set(KNOWN_TESTS_TEXT "Available test targets:")
foreach(VTEST ${CMAKE_VTESTS})
  set(KNOWN_TESTS_TEXT "${KNOWN_TESTS_TEXT}\\n - ${VTEST}")
endforeach(VTEST)

add_custom_target(
  list
  COMMAND echo ${KNOWN_TESTS_TEXT}
  VERBATIM
)