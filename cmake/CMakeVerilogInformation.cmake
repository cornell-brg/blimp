# ========================================================================
# CMakeVerilogInformation.cmake
# ========================================================================
# Information about how to use our compiler

# ------------------------------------------------------------------------
# Verilator
# ------------------------------------------------------------------------

if(CMAKE_Verilog_COMPILER_ID STREQUAL "Verilator")

  # Verilate files
  if(NOT CMAKE_Verilog_COMPILE_OBJECT)
    if(CMAKE_GENERATOR STREQUAL "Unix Makefiles")
      set(CMAKE_Verilog_COMPILE_OBJECT
        "<CMAKE_Verilog_COMPILER> <FLAGS> --cc --main <DEFINES> -DVERILATOR=1 <INCLUDES> <SOURCE> --Mdir <OBJECT>.vobjs --prefix VModel"
        "+make -C <OBJECT>.vobjs -f VModel.mk VM_PARALLEL_BUILDS=1"
        "<CMAKE_LINKER> -r -o <OBJECT> <OBJECT>.vobjs/*.o"
        "rm -r <OBJECT>.vobjs" # Otherwise it won't be cleaned by CMake
      )
    else() # Can't use jobserver support
      message(WARNING 
        "Using Verilator without Unix Makefiles won't parallelize, and will incur a build time penalty\n"
        "Use Makefiles as the generator to take advantage of jobserver parallelization"
      )
      set(CMAKE_Verilog_COMPILE_OBJECT
        "<CMAKE_Verilog_COMPILER> <FLAGS> --cc --main <DEFINES> -DVERILATOR=1 <INCLUDES> <SOURCE> --Mdir <OBJECT>.vobjs --prefix VModel"
        "make -s -C <OBJECT>.vobjs -f VModel.mk VM_PARALLEL_BUILDS=1"
        "<CMAKE_LINKER> -r -o <OBJECT> <OBJECT>.vobjs/*.o"
        "rm -r <OBJECT>.vobjs" # Otherwise it won't be cleaned by CMake
      )
    endif()
  endif()
  
  # Set flag for includes
  if(NOT CMAKE_INCLUDE_FLAG_Verilog)
    set(CMAKE_INCLUDE_FLAG_Verilog "-I")
  endif()
  
  # Set flag for defines
  if(NOT CMAKE_Verilog_DEFINE_FLAG)
    set(CMAKE_Verilog_DEFINE_FLAG "-D")
  endif()

# ------------------------------------------------------------------------
# VCS
# ------------------------------------------------------------------------

elseif(CMAKE_Verilog_COMPILER_ID STREQUAL "VCS")
  # "Compile" file - use Xman to act as a preprocessor (need to use sh for piping)
  if(NOT CMAKE_Verilog_COMPILE_OBJECT)
    set(CMAKE_Verilog_COMPILE_OBJECT
      "mkdir -p <OBJECT>.preproc"
      "bash -c 'set -o pipefail && cd <OBJECT>.preproc && <CMAKE_Verilog_COMPILER> <FLAGS> -sverilog <DEFINES> <INCLUDES> <SOURCE> -Xman=4 -q +warn=none | sed -n \'/Error/,+5p\''"
      "mv <OBJECT>.preproc/tokens.v <OBJECT>"
      "rm -r <OBJECT>.preproc" # Otherwise it won't be cleaned by CMake
    )
  endif()

  # Run VCS when linking (need to use sh for piping)
  if(NOT CMAKE_Verilog_LINK_EXECUTABLE)
    set(CMAKE_Verilog_LINK_EXECUTABLE
      "bash -c 'set -o pipefail && <CMAKE_Verilog_COMPILER> -sverilog -mda -q <LINK_FLAGS> -cc <CMAKE_C_COMPILER> -cpp <CMAKE_CXX_COMPILER> <LINK_LIBRARIES> -LDFLAGS \"-z noexecstack\" <OBJECTS> -Mdir=<TARGET>.gen -o <TARGET> +warn=none 2>&1 | sed -n \'/Error/,+5p\''"
    )
  endif()
  
  # Set flag for includes
  if(NOT CMAKE_INCLUDE_FLAG_Verilog)
    set(CMAKE_INCLUDE_FLAG_Verilog "+incdir+")
  endif()
  
  # Set flag for defines
  if(NOT CMAKE_Verilog_DEFINE_FLAG)
    set(CMAKE_Verilog_DEFINE_FLAG "+define+")
  endif()

# ------------------------------------------------------------------------
# Iverilog
# ------------------------------------------------------------------------
elseif(CMAKE_Verilog_COMPILER_ID STREQUAL "Iverilog")
  # No separate object files - just run preprocessor
  if(NOT CMAKE_Verilog_COMPILE_OBJECT)
    set(CMAKE_Verilog_COMPILE_OBJECT "<CMAKE_Verilog_COMPILER> -E <DEFINES> <INCLUDES> -o <OBJECT> <SOURCE>")
  endif()

  # Use linker to actually compile
  if(NOT CMAKE_Verilog_LINK_EXECUTABLE)
    set(CMAKE_Verilog_LINK_EXECUTABLE "<CMAKE_Verilog_COMPILER> -Wall -Winfloop -Wno-timescale -g2012 <LINK_FLAGS> <OBJECTS> -o <TARGET>")
  endif()

  # Set flag for includes
  if(NOT CMAKE_INCLUDE_FLAG_Verilog)
    set(CMAKE_INCLUDE_FLAG_Verilog "-I")
  endif()

  # Set flag for defines
  if(NOT CMAKE_Verilog_DEFINE_FLAG)
    set(CMAKE_Verilog_DEFINE_FLAG "-D")
  endif()
endif()

set(CMAKE_Verilog_INFORMATION_LOADED 1)