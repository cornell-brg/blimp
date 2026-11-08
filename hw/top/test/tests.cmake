# ========================================================================
# tests.cmake
# ========================================================================
# Identify all of Blimp's sub-tests

set(BLIMP_VERSIONS
  FLProc
  BlimpV1
  BlimpV2
  BlimpV3
  BlimpV4
  BlimpV5
  BlimpV6
  BlimpV7
  BlimpV8
  BlimpV8_sp26
)

# ------------------------------------------------------------------------
# FLProc
# ------------------------------------------------------------------------

set(FLProc_TESTS
  FLProc_test/FLProc_test.v
)

# ------------------------------------------------------------------------
# BlimpV1
# ------------------------------------------------------------------------

set(BlimpV1_TESTS
  BlimpV1_test/BlimpV1_add_test.v
  BlimpV1_test/BlimpV1_addi_test.v
  BlimpV1_test/BlimpV1_mul_test.v
  BlimpV1_test/BlimpV1_ALL_test.v
)

# ------------------------------------------------------------------------
# BlimpV2
# ------------------------------------------------------------------------

set(BlimpV2_TESTS
  BlimpV2_test/BlimpV2_add_test.v
  BlimpV2_test/BlimpV2_addi_test.v
  BlimpV2_test/BlimpV2_mul_test.v
  BlimpV2_test/BlimpV2_ALL_test.v
)

# ------------------------------------------------------------------------
# BlimpV3
# ------------------------------------------------------------------------

set(BlimpV3_TESTS
  BlimpV3_test/BlimpV3_add_test.v
  BlimpV3_test/BlimpV3_addi_test.v
  BlimpV3_test/BlimpV3_mul_test.v
  BlimpV3_test/BlimpV3_ALL_test.v
)

# ------------------------------------------------------------------------
# BlimpV4
# ------------------------------------------------------------------------

set(BlimpV4_TESTS
  BlimpV4_test/BlimpV4_add_test.v
  BlimpV4_test/BlimpV4_addi_test.v
  BlimpV4_test/BlimpV4_mul_test.v
  BlimpV4_test/BlimpV4_lw_test.v
  BlimpV4_test/BlimpV4_sw_test.v
  BlimpV4_test/BlimpV4_ALL_test.v
)

# ------------------------------------------------------------------------
# BlimpV5
# ------------------------------------------------------------------------

set(BlimpV5_TESTS
  BlimpV5_test/BlimpV5_add_test.v
  BlimpV5_test/BlimpV5_addi_test.v
  BlimpV5_test/BlimpV5_mul_test.v
  BlimpV5_test/BlimpV5_lw_test.v
  BlimpV5_test/BlimpV5_sw_test.v
  BlimpV5_test/BlimpV5_jal_test.v
  BlimpV5_test/BlimpV5_jalr_test.v
  BlimpV5_test/BlimpV5_ALL_test.v
)

# ------------------------------------------------------------------------
# BlimpV6
# ------------------------------------------------------------------------

set(BlimpV6_TESTS
  BlimpV6_test/BlimpV6_add_test.v
  BlimpV6_test/BlimpV6_addi_test.v
  BlimpV6_test/BlimpV6_mul_test.v
  BlimpV6_test/BlimpV6_lw_test.v
  BlimpV6_test/BlimpV6_sw_test.v
  BlimpV6_test/BlimpV6_jal_test.v
  BlimpV6_test/BlimpV6_jalr_test.v
  BlimpV6_test/BlimpV6_bne_test.v
  BlimpV6_test/BlimpV6_ALL_test.v
)

# ------------------------------------------------------------------------
# BlimpV7
# ------------------------------------------------------------------------

set(BlimpV7_TESTS
  BlimpV7_test/BlimpV7_add_test.v
  BlimpV7_test/BlimpV7_addi_test.v
  BlimpV7_test/BlimpV7_mul_test.v
  BlimpV7_test/BlimpV7_lw_test.v
  BlimpV7_test/BlimpV7_sw_test.v
  BlimpV7_test/BlimpV7_jal_test.v
  BlimpV7_test/BlimpV7_jalr_test.v
  BlimpV7_test/BlimpV7_bne_test.v

  BlimpV7_test/BlimpV7_sub_test.v
  BlimpV7_test/BlimpV7_and_test.v
  BlimpV7_test/BlimpV7_or_test.v
  BlimpV7_test/BlimpV7_xor_test.v
  BlimpV7_test/BlimpV7_slt_test.v
  BlimpV7_test/BlimpV7_sltu_test.v
  BlimpV7_test/BlimpV7_sra_test.v
  BlimpV7_test/BlimpV7_srl_test.v
  BlimpV7_test/BlimpV7_sll_test.v

  BlimpV7_test/BlimpV7_andi_test.v
  BlimpV7_test/BlimpV7_ori_test.v
  BlimpV7_test/BlimpV7_xori_test.v
  BlimpV7_test/BlimpV7_slti_test.v
  BlimpV7_test/BlimpV7_sltiu_test.v
  BlimpV7_test/BlimpV7_srai_test.v
  BlimpV7_test/BlimpV7_srli_test.v
  BlimpV7_test/BlimpV7_slli_test.v
  BlimpV7_test/BlimpV7_lui_test.v
  BlimpV7_test/BlimpV7_auipc_test.v

  BlimpV7_test/BlimpV7_beq_test.v
  BlimpV7_test/BlimpV7_blt_test.v
  BlimpV7_test/BlimpV7_bge_test.v
  BlimpV7_test/BlimpV7_bltu_test.v
  BlimpV7_test/BlimpV7_bgeu_test.v

  BlimpV7_test/BlimpV7_ALL_test.v
)

# ------------------------------------------------------------------------
# BlimpV7
# ------------------------------------------------------------------------

set(BlimpV8_TESTS
  BlimpV8_test/BlimpV8_add_test.v
  BlimpV8_test/BlimpV8_addi_test.v
  BlimpV8_test/BlimpV8_lw_test.v
  BlimpV8_test/BlimpV8_sw_test.v
  BlimpV8_test/BlimpV8_jal_test.v
  BlimpV8_test/BlimpV8_jalr_test.v
  BlimpV8_test/BlimpV8_bne_test.v

  BlimpV8_test/BlimpV8_sub_test.v
  BlimpV8_test/BlimpV8_and_test.v
  BlimpV8_test/BlimpV8_or_test.v
  BlimpV8_test/BlimpV8_xor_test.v
  BlimpV8_test/BlimpV8_slt_test.v
  BlimpV8_test/BlimpV8_sltu_test.v
  BlimpV8_test/BlimpV8_sra_test.v
  BlimpV8_test/BlimpV8_srl_test.v
  BlimpV8_test/BlimpV8_sll_test.v

  BlimpV8_test/BlimpV8_andi_test.v
  BlimpV8_test/BlimpV8_ori_test.v
  BlimpV8_test/BlimpV8_xori_test.v
  BlimpV8_test/BlimpV8_slti_test.v
  BlimpV8_test/BlimpV8_sltiu_test.v
  BlimpV8_test/BlimpV8_srai_test.v
  BlimpV8_test/BlimpV8_srli_test.v
  BlimpV8_test/BlimpV8_slli_test.v
  BlimpV8_test/BlimpV8_lui_test.v
  BlimpV8_test/BlimpV8_auipc_test.v

  BlimpV8_test/BlimpV8_beq_test.v
  BlimpV8_test/BlimpV8_blt_test.v
  BlimpV8_test/BlimpV8_bge_test.v
  BlimpV8_test/BlimpV8_bltu_test.v
  BlimpV8_test/BlimpV8_bgeu_test.v

  BlimpV8_test/BlimpV8_lb_test.v
  BlimpV8_test/BlimpV8_lh_test.v
  BlimpV8_test/BlimpV8_lbu_test.v
  BlimpV8_test/BlimpV8_lhu_test.v
  BlimpV8_test/BlimpV8_sb_test.v
  BlimpV8_test/BlimpV8_sh_test.v
  BlimpV8_test/BlimpV8_fence_test.v

  BlimpV8_test/BlimpV8_mul_test.v
  BlimpV8_test/BlimpV8_mulh_test.v
  BlimpV8_test/BlimpV8_mulhu_test.v
  BlimpV8_test/BlimpV8_mulhsu_test.v
  BlimpV8_test/BlimpV8_div_test.v
  BlimpV8_test/BlimpV8_divu_test.v
  BlimpV8_test/BlimpV8_rem_test.v
  BlimpV8_test/BlimpV8_remu_test.v
  
  BlimpV8_test/BlimpV8_ALL_test.v
)

# ------------------------------------------------------------------------
# BlimpV8_sp26
# ------------------------------------------------------------------------

set(BlimpV8_sp26_TESTS
  BlimpV8_sp26_test/BlimpV8_sp26_add_test.v
  BlimpV8_sp26_test/BlimpV8_sp26_addi_test.v
  BlimpV8_sp26_test/BlimpV8_sp26_lw_test.v
  BlimpV8_sp26_test/BlimpV8_sp26_sw_test.v
  BlimpV8_sp26_test/BlimpV8_sp26_jal_test.v
  BlimpV8_sp26_test/BlimpV8_sp26_jalr_test.v
  BlimpV8_sp26_test/BlimpV8_sp26_bne_test.v

  BlimpV8_sp26_test/BlimpV8_sp26_sub_test.v
  BlimpV8_sp26_test/BlimpV8_sp26_and_test.v
  BlimpV8_sp26_test/BlimpV8_sp26_or_test.v
  BlimpV8_sp26_test/BlimpV8_sp26_xor_test.v
  BlimpV8_sp26_test/BlimpV8_sp26_slt_test.v
  BlimpV8_sp26_test/BlimpV8_sp26_sltu_test.v
  BlimpV8_sp26_test/BlimpV8_sp26_sra_test.v
  BlimpV8_sp26_test/BlimpV8_sp26_srl_test.v
  BlimpV8_sp26_test/BlimpV8_sp26_sll_test.v

  BlimpV8_sp26_test/BlimpV8_sp26_andi_test.v
  BlimpV8_sp26_test/BlimpV8_sp26_ori_test.v
  BlimpV8_sp26_test/BlimpV8_sp26_xori_test.v
  BlimpV8_sp26_test/BlimpV8_sp26_slti_test.v
  BlimpV8_sp26_test/BlimpV8_sp26_sltiu_test.v
  BlimpV8_sp26_test/BlimpV8_sp26_srai_test.v
  BlimpV8_sp26_test/BlimpV8_sp26_srli_test.v
  BlimpV8_sp26_test/BlimpV8_sp26_slli_test.v
  BlimpV8_sp26_test/BlimpV8_sp26_lui_test.v
  BlimpV8_sp26_test/BlimpV8_sp26_auipc_test.v

  BlimpV8_sp26_test/BlimpV8_sp26_beq_test.v
  BlimpV8_sp26_test/BlimpV8_sp26_blt_test.v
  BlimpV8_sp26_test/BlimpV8_sp26_bge_test.v
  BlimpV8_sp26_test/BlimpV8_sp26_bltu_test.v
  BlimpV8_sp26_test/BlimpV8_sp26_bgeu_test.v

  BlimpV8_sp26_test/BlimpV8_sp26_lb_test.v
  BlimpV8_sp26_test/BlimpV8_sp26_lh_test.v
  BlimpV8_sp26_test/BlimpV8_sp26_lbu_test.v
  BlimpV8_sp26_test/BlimpV8_sp26_lhu_test.v
  BlimpV8_sp26_test/BlimpV8_sp26_sb_test.v
  BlimpV8_sp26_test/BlimpV8_sp26_sh_test.v
  BlimpV8_sp26_test/BlimpV8_sp26_fence_test.v

  BlimpV8_sp26_test/BlimpV8_sp26_mul_test.v
  BlimpV8_sp26_test/BlimpV8_sp26_mulh_test.v
  BlimpV8_sp26_test/BlimpV8_sp26_mulhu_test.v
  BlimpV8_sp26_test/BlimpV8_sp26_mulhsu_test.v
  BlimpV8_sp26_test/BlimpV8_sp26_div_test.v
  BlimpV8_sp26_test/BlimpV8_sp26_divu_test.v
  BlimpV8_sp26_test/BlimpV8_sp26_rem_test.v
  BlimpV8_sp26_test/BlimpV8_sp26_remu_test.v

  BlimpV8_sp26_test/BlimpV8_sp26_ALL_test.v
  BlimpV8_sp26_test/BlimpV8_sp26_debug_test.v
)