//========================================================================
// disassemble.cpp
//========================================================================
// A function to disassemble instructions directly from binary, for use
// from test cases

#include "asm/disassemble.h"
#include "asm/fields.h"
#include "asm/inst.h"
#include <cstdint>
#include <functional>
#include <map>
#include <stdexcept>
#include <string>
#include <vector>

//------------------------------------------------------------------------
// Field Table
//------------------------------------------------------------------------
// Map fields to instructions to call for the corresponding token

std::map<std::string, std::function<std::string( uint32_t )>>
    disasm_field_map = {
        { "rs1", get_rs1_id },
        { "rs2", get_rs2_id },
        { "rd",  get_rd_id  },

        // FP register fields
        { "frs1", get_frs1_id },
        { "frs2", get_frs2_id },
        { "frd",  get_frd_id  },

        { "imm_i", get_imm_i_id },
        { "imm_s", get_imm_s_id },
        { "imm_b", get_imm_b_id },
        { "imm_u", get_imm_u_id },
        { "imm_j", get_imm_j_id },
        { "imm_is", get_imm_is_id },
        { "pred", get_pred_id },
        { "succ", get_succ_id }
    };

std::map<std::string, std::function<std::string( uint32_t, uint32_t )>>
    disasm_pc_field_map = { { "addr_b", get_addr_b_id },
                            { "addr_j", get_addr_j_id } };

//------------------------------------------------------------------------
// disassemble
//------------------------------------------------------------------------
// Find the matching instruction for the binary, then assemble tokens
// from it

std::string instruction;

const char* disassemble( const uint32_t* vbinary, const uint32_t* vpc )
{
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Get the appropriate instruction specification
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  uint32_t           binary = *vbinary;
  uint32_t           pc     = *vpc;
  const inst_spec_t* spec;
  try {
    spec = get_inst_spec( binary );
  } catch ( std::exception& e ) {
    return "????????";
  }
  std::vector<std::string> spec_tokens = tokenize( spec->assembly );

  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  // Use tokens to form instruction
  // - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  instruction = spec->assembly;

  for ( std::size_t i = 1; i < spec_tokens.size(); i++ ) {
    std::string spec_token = spec_tokens[i];
    std::string replacement;
    if ( disasm_pc_field_map.contains( spec_token ) ) {
      replacement = disasm_pc_field_map[spec_token]( binary, pc );
    }
    else {
      replacement = disasm_field_map[spec_token]( binary );
    }

    instruction.replace( instruction.find( spec_token ),
                         spec_token.length(), replacement );
  }

  return instruction.c_str();
}
