//========================================================================
// assemble.cpp
//========================================================================
// A function to assemble instructions directly into binary, for use from
// test cases

#include "asm/assemble.h"
#include "asm/fields.h"
#include "asm/inst.h"
#include <format>
#include <functional>
#include <iostream>
#include <map>
#include <stdexcept>
#include <string>
#include <vector>

//------------------------------------------------------------------------
// Field Table
//------------------------------------------------------------------------
// Map fields to instructions to call for the corresponding token

std::map<std::string, std::function<uint32_t( const std::string& )>>
    asm_field_map = {
      { "rs1", rs1_mask },
      { "rs2", rs2_mask },
      { "rd",  rd_mask  },

      // FP register fields
      { "frs1", frs1_mask },
      { "frs2", frs2_mask },
      { "frd",  frd_mask  },

      { "imm_i", imm_i_mask },
      { "imm_s", imm_s_mask },
      { "imm_b", imm_b_mask },
      { "imm_u", imm_u_mask },
      { "imm_j", imm_j_mask },
      { "imm_is", imm_is_mask },
      { "pred", pred_mask },
      { "succ", succ_mask }
    };

std::map<std::string,
         std::function<uint32_t( const std::string&, uint32_t )>>
    asm_pc_field_map = { { "addr_b", addr_b_mask },
                         { "addr_j", addr_j_mask } };

//------------------------------------------------------------------------
// assemble
//------------------------------------------------------------------------
// Convert the assembly into tokens, then call the instruction-specific
// assembler

uint32_t assemble( const char* vassembly, uint32_t* vpc )
{
  std::string              assembly = vassembly;
  uint32_t                 pc       = *vpc;
  std::vector<std::string> tokens   = tokenize( assembly );

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Get the appropriate instruction specification
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  std::string inst;
  std::string excp;

  try {
    inst = tokens.at( 0 );
  } catch ( const std::out_of_range& e ) {
    excp = std::format( "Error: Empty assembly '{}'", assembly );
    throw std::invalid_argument( excp );
  }

  const inst_spec_t*       spec        = get_inst_spec( inst );
  std::vector<std::string> spec_tokens = tokenize( spec->assembly );

  if ( spec_tokens.size() != tokens.size() ) {
    excp = std::format( "Error: '{}' expects {} fields, but found {}",
                        assembly, spec_tokens.size(), tokens.size() );
    throw std::invalid_argument( excp );
  }

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Use tokens to form instruction
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  uint32_t encoding = spec->match;

  for ( std::size_t i = 1; i < spec_tokens.size(); i++ ) {
    std::string inst_token = tokens[i];
    std::string spec_token = spec_tokens[i];

    try {
      if ( asm_pc_field_map.contains( spec_token ) ) {
        encoding |= asm_pc_field_map[spec_token]( inst_token, pc );
      }
      else {
        encoding |= asm_field_map[spec_token]( inst_token );
      }
    } catch ( const std::exception& e ) {
      throw std::invalid_argument(
        std::format("Error assembling '{}': token '{}' for spec '{}' failed: {}",
                    assembly, inst_token, spec_token, e.what() ) );
    }
  }

  return encoding;
}
