# ========================================================================
# vlint.cmake
# ========================================================================
# A function to create a target that lints Verilog files
#
# Author: Aidan McNay
# Date: March 27th, 2025

find_program(
  VERILATOR_BIN
  NAMES verilator_bin verilator_bin.exe
)

if(NOT VERILATOR_BIN)
  message(FATAL_ERROR "Cannot find verilator executable.")
endif()

set(VLINT_FLAGS
  --quiet
  --timing
  ${CMAKE_CURRENT_LIST_DIR}/../verilator_waivers.vlt
)

cmake_minimum_required(VERSION 3.19)
function(vlint TARGET)
  cmake_parse_arguments(
    VLINT
    ""
    "TARGET_NAME"
    "VERILATOR_FLAGS;SOURCES;INCLUDE_DIRS;DEPENDS"
    ${ARGN}
  )

  foreach(INC ${VLINT_INCLUDE_DIRS})
    list(APPEND INCLUDE_FLAGS "-I${INC}")
  endforeach()

  set(LINT_CMD
    ${VERILATOR_BIN}
    --lint-only
    ${VLINT_FLAGS}
    ${VLINT_VERILATOR_FLAGS}
    ${INCLUDE_FLAGS}
    ${VLINT_SOURCES}
  )

  add_custom_command(
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/${TARGET}-vlint.in
    COMMAND ${LINT_CMD}
    COMMAND ${CMAKE_COMMAND} "-E" "touch" ${CMAKE_CURRENT_BINARY_DIR}/${TARGET}-vlint.in
    COMMENT "Linting sources for ${VLINT_TARGET_NAME}"
    DEPENDS ${VLINT_DEPENDS}
  )
  add_custom_target(
    ${TARGET}
    DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/${TARGET}-vlint.in
  )
endfunction()