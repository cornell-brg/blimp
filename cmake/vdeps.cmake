# ========================================================================
# vdeps.cmake
# ========================================================================
# A function to find the Verilog dependencies of a source file
#
# Author: Aidan McNay
# Date: March 27th, 2025

cmake_minimum_required(VERSION 3.19)

function(vdeps DEPENDENCIES)
  cmake_parse_arguments(
    VDEP
    ""
    "SOURCE"
    "INCLUDE_DIRS"
    ${ARGN}
  )
  set(VDEPENDENCIES ${VDEP_SOURCE})

  # Get the file
  unset(FILE_PATH)
  find_file(
    FILE_PATH 
    NAMES ${VDEP_SOURCE}
    PATHS ${VDEP_INCLUDE_DIRS}
    NO_DEFAULT_PATH
    NO_CACHE
  )
  if(${FILE_PATH} STREQUAL "FILE_PATH-NOTFOUND")
    message(FATAL_ERROR "Couldn't find file '${VDEP_SOURCE}' (searched ${VDEP_INCLUDE_DIRS})")
  endif()
  file(READ ${FILE_PATH} FILE_CONTENTS)
  string(REPLACE "\n" ";" FILE_CONTENTS ${FILE_CONTENTS})

  # Find all `include lines, and recurse
  foreach(FILE_LINE ${FILE_CONTENTS})
    string(REGEX MATCHALL "^[^\\/]*`include[ \\t\\r\\n\\f]*(\"(.+)\"|'(.+)')[ \\t\\r\\n\\f]*$" INCL_MATCHES ${FILE_LINE})
    if(NOT ${CMAKE_MATCH_2} IN_LIST VDEPENDENCIES)
      # Check for memoization
      get_property(MEMOIZED
        DIRECTORY ${CMAKE_CURRENT_LIST_DIR}
        PROPERTY ${CMAKE_MATCH_2}_DEPS
        SET
      )
      if(MEMOIZED)
        get_property(MEMOIZED_DEPS
          DIRECTORY ${CMAKE_CURRENT_LIST_DIR}
          PROPERTY ${CMAKE_MATCH_2}_DEPS
        )
        set(VDEPENDENCIES ${VDEPENDENCIES} ${MEMOIZED_DEPS})
      else()
        # Not memoized - call recursively
        vdeps(NEW_DEPS
          SOURCE ${CMAKE_MATCH_2}
          INCLUDE_DIRS ${VDEP_INCLUDE_DIRS}
        )
        set(VDEPENDENCIES ${VDEPENDENCIES} ${NEW_DEPS})
      endif()
    endif()
  endforeach(FILE_LINE)

  # We could remove duplicates, but just slows down configuration
  # list(REMOVE_DUPLICATES VDEPENDENCIES)

  # Memoize for later calls
  set_property(
    DIRECTORY ${CMAKE_CURRENT_LIST_DIR}
    PROPERTY ${VDEP_SOURCE}_DEPS ${VDEPENDENCIES}
  )
  set(${DEPENDENCIES} ${VDEPENDENCIES} PARENT_SCOPE)
endfunction()