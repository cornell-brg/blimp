//========================================================================
// parse_elf.cpp
//========================================================================
// A parser for ELF files
//
// Heavily inspired by PyMTL's ELF reader here:
// (Authors: Christopher Batten, Shunning Jiang)
//
// https://github.com/pymtl/pymtl3/blob/eea5ff49e06b303123097dc4d9e163790c0f58d6/pymtl3/stdlib/proc/elf.py
//
// as well as this lightweight ELF parser
//
// https://github.com/finixbit/elf-parser/tree/master
//
// and Gemini output for loading an ELF file

#include "fl/parse_elf.h"
#include <cstring>
#include <elf.h>
#include <fcntl.h>
#include <format>
#include <fstream>
#include <stdexcept>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

#ifndef EM_RISCV
#define EM_RISCV 243  // RISCV Architecture Identifier
#endif

void parse_elf( std::string                               elf_path,
                std::function<void( uint32_t, uint32_t )> set_mem )
{
  // ---------------------------------------------------------------------
  // Map file into memory space
  // ---------------------------------------------------------------------

  int fd;
  if ( ( fd = open( elf_path.c_str(), O_RDONLY ) ) < 0 ) {
    std::string excp =
        std::format( "Error: Unable to open file '{}'", elf_path );
    throw std::invalid_argument( excp );
  }

  // Get file size
  struct stat sb;
  if ( fstat( fd, &sb ) < 0 ) {
    std::string excp =
        std::format( "Error: Unable to get size of file '{}'", elf_path );
    throw std::invalid_argument( excp );
  }

  // Map file
  void* elf_map =
      mmap( nullptr, sb.st_size, PROT_READ, MAP_PRIVATE, fd, 0 );
  if ( elf_map == MAP_FAILED ) {
    std::string excp = std::format(
        "Error: Unable to map file to memory space '{}'", elf_path );
    throw std::invalid_argument( excp );
  }

  // ---------------------------------------------------------------------
  // Parse the ELF header
  // ---------------------------------------------------------------------

  Elf32_Ehdr* elf_header = (Elf32_Ehdr*) elf_map;

  // Verify that the first bytes are
  // - 0x7f
  // - 'E' (0x45)
  // - 'L' (0x4c)
  // - 'F' (0x46)
  if ( elf_header->e_ident[EI_MAG0] != ELFMAG0 ||
       elf_header->e_ident[EI_MAG1] != ELFMAG1 ||
       elf_header->e_ident[EI_MAG2] != ELFMAG2 ||
       elf_header->e_ident[EI_MAG3] != ELFMAG3 ) {
    std::string excp =
        std::format( "Error: Invalid ELF file '{}'", elf_path );
    throw std::invalid_argument( excp );
  }

  // Verify that it's a RISCV ELF file
  if ( elf_header->e_machine != EM_RISCV ) {
    std::string excp =
        std::format( "Error: ELF file isn't for RISCV '{}'", elf_path );
    throw std::invalid_argument( excp );
  }

  // Verify that it's a 32-bit ELF file
  if ( elf_header->e_ident[EI_CLASS] != ELFCLASS32 ) {
    std::string excp = std::format(
        "Error: ELF file isn't for 32b machines '{}'", elf_path );
    throw std::invalid_argument( excp );
  }

  // Verify that our entry point is as expected
  if ( elf_header->e_entry != 0x000 ) {
    std::string excp = "Error: Entry point isn't 0x000";
    throw std::invalid_argument( excp );
  }

  // ---------------------------------------------------------------------
  // Parse section string table
  // ---------------------------------------------------------------------

  // Get the header for the string table
  // (header offset + (string header index * header size))
  Elf32_Shdr* string_table_header =
      (Elf32_Shdr*) ( (char*) elf_map + elf_header->e_shoff +
                      ( elf_header->e_shstrndx *
                        elf_header->e_shentsize ) );

  char* string_table = (char*) elf_map + string_table_header->sh_offset;

  // ---------------------------------------------------------------------
  // Parse sections
  // ---------------------------------------------------------------------

  for ( int section_idx = 0; section_idx < elf_header->e_shnum;
        section_idx++ ) {
    Elf32_Shdr* section_header =
        (Elf32_Shdr*) ( (char*) elf_map + elf_header->e_shoff +
                        ( section_idx * elf_header->e_shentsize ) );
    char* section_name = string_table + section_header->sh_name;

    // Only load in sections marked
    if ( !( section_header->sh_flags & SHF_ALLOC ) ) {
      continue;
    }

    // Go to the section data
    char* section_data = (char*) elf_map + section_header->sh_offset;

    // Read the data in
    uint32_t curr_addr = section_header->sh_addr;
    for ( unsigned int i = 0; i < section_header->sh_size; i += 4 ) {
      if ( strcmp( section_name, ".sbss" ) == 0 ||
           strcmp( section_name, ".bss" ) == 0 ) {
        // Should be empty
        // http://stackoverflow.com/questions/610682/bss-section-in-elf-file
        set_mem( curr_addr, 0 );
      }
      else {
        set_mem( curr_addr, *( (uint32_t*) section_data ) );
      }

      curr_addr += 4;
      section_data += 4;
    }
  }

  // ---------------------------------------------------------------------
  // Cleaning up
  // ---------------------------------------------------------------------

  munmap( elf_map, sb.st_size );
  close( fd );
}