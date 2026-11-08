# ========================================================================
# CMakeLists.txt
# ========================================================================
# Building RISCV binaries for use in Blimp

include(${CMAKE_CURRENT_SOURCE_DIR}/cmake/rv32.cmake)
include_directories(${CMAKE_CURRENT_SOURCE_DIR})
add_compile_definitions(BUILTIN)

#-------------------------------------------------------------------------
# Set all of the directories to look in
#-------------------------------------------------------------------------

set(APP_SUBDIRS
  adventure
  fp
  demo
  echo
  hello
  sqrt
  ubmark
)

#-------------------------------------------------------------------------
# Set the libraries
#-------------------------------------------------------------------------

set(UTIL_FILES
  utils/blimp_exit.cpp
  utils/blimp_misc.cpp
  utils/blimp_rand.cpp
  utils/blimp_stats.cpp
  utils/blimp_stdio.cpp
  utils/blimp_string.cpp
  utils/blimp_wprintf.cpp
)

#-------------------------------------------------------------------------
# Object library for entry point
#-------------------------------------------------------------------------
# Need to do this with a custom command, so our linker script can later
# find it (otherwise CMake will put it somewhere crazy with a weird name)

# Need to replace spaces to avoid CMake escaping them
string(REPLACE " " ";" CMAKE_CXX_CUSTOM_FLAGS ${CMAKE_CXX_FLAGS})

add_custom_command(
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/crt0.o
    COMMAND ${CMAKE_CXX_COMPILER} ${CMAKE_CXX_CUSTOM_FLAGS} -c ${CMAKE_CURRENT_SOURCE_DIR}/scripts/crt0.S -o ${CMAKE_CURRENT_BINARY_DIR}/crt0.o
    DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/scripts/crt0.S
)
add_custom_target(compile_crt ALL DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/crt0.o)

#-------------------------------------------------------------------------
# Build the libraries
#-------------------------------------------------------------------------

add_library(UTILS STATIC ${UTIL_FILES})

#-------------------------------------------------------------------------
# Make targets
#-------------------------------------------------------------------------

set(PROGS "")

foreach(APP_SUBDIR ${APP_SUBDIRS})
  add_subdirectory(${APP_SUBDIR} "${CMAKE_CURRENT_BINARY_DIR}/${APP_SUBDIR}_cmake")
  add_prefix(SRC_FILES "${APP_SUBDIR}/")
  add_prefix(APP_FILES "${APP_SUBDIR}/")

  set(ABSOLUTE_SRC_FILES ${SRC_FILES})
  add_prefix(ABSOLUTE_SRC_FILES "${CMAKE_CURRENT_SOURCE_DIR}/")
  
  foreach(APP_FILE_REL_PATH ${APP_FILES})
    set(APP_FILE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/${APP_FILE_REL_PATH}")
    get_leaf(APP_FILE ${APP_FILE_PATH})
    remove_extension(APP_BIN ${APP_FILE})
  
    add_executable(
      app-${APP_BIN} 
      ${APP_FILE_PATH}
      ${ABSOLUTE_SRC_FILES}
    )
    target_compile_options(app-${APP_BIN} PRIVATE -Wall -Wextra -Wpedantic -Werror)
    # For most apps, ensure the default crt0 is compiled. For the FP
    # variant we want a separate FP startup object (crt0_fp.o) and
    # linker script, so skip the default compile_crt dependency here.
    if(NOT APP_BIN STREQUAL "fp")
      add_dependencies(app-${APP_BIN} compile_crt)
    endif()
    set_target_properties(app-${APP_BIN} PROPERTIES OUTPUT_NAME ${APP_BIN})
    # Use -O0 for fp target, -O3 for others
    if(APP_BIN STREQUAL "fp")
      target_compile_options(app-${APP_BIN} PRIVATE -O0 -Wall -Wextra -Wpedantic -Werror)
    else()
      target_compile_options(app-${APP_BIN} PRIVATE -O3 -Wall -Wextra -Wpedantic -Werror)
    endif()
    if(NOT APP_BIN STREQUAL "fp")
      target_link_libraries(app-${APP_BIN} PRIVATE UTILS)
    endif()

    # Per-target linker options: use the normal linker script for
    # non-FP apps, and the FP linker script for the FP app.
    if(APP_BIN STREQUAL "fp")
      # app-fp gets a special FP linker script and FP libs (handled below)
      target_link_options(app-${APP_BIN} PRIVATE
        -march=rv32imf
        -mabi=ilp32f
        -nostdlib
        -nostartfiles
        -Wl,--no-warn-rwx-segments
        -T${CMAKE_CURRENT_BINARY_DIR}/blimp_fp.ld
        -L${CMAKE_CURRENT_BINARY_DIR}
      )
    else()
      target_link_options(app-${APP_BIN} PRIVATE
        -march=rv32im
        -mabi=ilp32
        -nostdlib
        -nostartfiles
        -Wl,--no-warn-rwx-segments
        -T${CMAKE_CURRENT_SOURCE_DIR}/scripts/blimp.ld
        -L${CMAKE_CURRENT_BINARY_DIR}
      )
    endif()

    # Add to list of programs for parent
    set(app-${APP_BIN}-files
      ${APP_FILE_REL_PATH}
      ${SRC_FILES}
    PARENT_SCOPE)
    set(PROGS ${PROGS} ${APP_BIN})
  endforeach(APP_FILE_REL_PATH)
endforeach(APP_SUBDIR)

#-------------------------------------------------------------------------
# Give parent our programs for native builds
#-------------------------------------------------------------------------

set(PROGS ${PROGS} PARENT_SCOPE)

#-------------------------------------------------------------------------
# Floating-point support for app-fp
#-------------------------------------------------------------------------
# Create FP version of UTILS library
add_library(UTILS_FP STATIC ${UTIL_FILES})
target_compile_options(UTILS_FP PRIVATE
  -march=rv32imf
  -mabi=ilp32f
)

# Create FP version of crt0
add_custom_command(
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/crt0_fp.o
    COMMAND ${CMAKE_CXX_COMPILER} ${CMAKE_CXX_CUSTOM_FLAGS} -march=rv32imf -mabi=ilp32f -c ${CMAKE_CURRENT_SOURCE_DIR}/scripts/crt0.S -o ${CMAKE_CURRENT_BINARY_DIR}/crt0_fp.o
    DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/scripts/crt0.S
)
add_custom_target(compile_crt_fp ALL DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/crt0_fp.o)

# Create FP-specific linker script that references crt0_fp.o instead of crt0.o
add_custom_command(
    OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/blimp_fp.ld
    COMMAND ${CMAKE_COMMAND} -E copy ${CMAKE_CURRENT_SOURCE_DIR}/scripts/blimp.ld ${CMAKE_CURRENT_BINARY_DIR}/blimp_fp.ld
    COMMAND sed -i 's/crt0\\.o/crt0_fp.o/g' ${CMAKE_CURRENT_BINARY_DIR}/blimp_fp.ld
    DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/scripts/blimp.ld
)
add_custom_target(linker_script_fp ALL DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/blimp_fp.ld)

# Reconfigure app-fp to use FP libraries
target_compile_options(app-fp PRIVATE
  -march=rv32imf
  -mabi=ilp32f
)

# Add dependency on FP linker script
add_dependencies(app-fp linker_script_fp compile_crt_fp)

# Replace UTILS with UTILS_FP
target_link_libraries(app-fp PRIVATE UTILS_FP)

# Use custom FP linker script (don't specify crt0_fp.o explicitly - linker script handles it)
target_link_options(app-fp PRIVATE
  -march=rv32imf
  -mabi=ilp32f
  -nostdlib
  -nostartfiles
  -Wl,--no-warn-rwx-segments
  -T${CMAKE_CURRENT_BINARY_DIR}/blimp_fp.ld
  -L${CMAKE_CURRENT_BINARY_DIR}
)