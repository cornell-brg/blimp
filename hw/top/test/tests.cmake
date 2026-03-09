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
  BlimpV9
  BlimpV10
  BlimpV11
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
)

# ------------------------------------------------------------------------
# BlimpV2
# ------------------------------------------------------------------------

set(BlimpV2_TESTS
  BlimpV2_test/BlimpV2_add_test.v
  BlimpV2_test/BlimpV2_addi_test.v
  BlimpV2_test/BlimpV2_mul_test.v
)

# ------------------------------------------------------------------------
# BlimpV3
# ------------------------------------------------------------------------

set(BlimpV3_TESTS
  BlimpV3_test/BlimpV3_add_test.v
  BlimpV3_test/BlimpV3_addi_test.v
  BlimpV3_test/BlimpV3_mul_test.v
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
)

# ------------------------------------------------------------------------
# BlimpV8
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
)

# ------------------------------------------------------------------------
# BlimpV9
# ------------------------------------------------------------------------

set(BlimpV9_TESTS
  BlimpV9_test/BlimpV9_add_test.v
  BlimpV9_test/BlimpV9_addi_test.v
  BlimpV9_test/BlimpV9_lw_test.v
  BlimpV9_test/BlimpV9_sw_test.v
  BlimpV9_test/BlimpV9_jal_test.v
  BlimpV9_test/BlimpV9_jalr_test.v
  BlimpV9_test/BlimpV9_bne_test.v

  BlimpV9_test/BlimpV9_sub_test.v
  BlimpV9_test/BlimpV9_and_test.v
  BlimpV9_test/BlimpV9_or_test.v
  BlimpV9_test/BlimpV9_xor_test.v
  BlimpV9_test/BlimpV9_slt_test.v
  BlimpV9_test/BlimpV9_sltu_test.v
  BlimpV9_test/BlimpV9_sra_test.v
  BlimpV9_test/BlimpV9_srl_test.v
  BlimpV9_test/BlimpV9_sll_test.v

  BlimpV9_test/BlimpV9_andi_test.v
  BlimpV9_test/BlimpV9_ori_test.v
  BlimpV9_test/BlimpV9_xori_test.v
  BlimpV9_test/BlimpV9_slti_test.v
  BlimpV9_test/BlimpV9_sltiu_test.v
  BlimpV9_test/BlimpV9_srai_test.v
  BlimpV9_test/BlimpV9_srli_test.v
  BlimpV9_test/BlimpV9_slli_test.v
  BlimpV9_test/BlimpV9_lui_test.v
  BlimpV9_test/BlimpV9_auipc_test.v

  BlimpV9_test/BlimpV9_beq_test.v
  BlimpV9_test/BlimpV9_blt_test.v
  BlimpV9_test/BlimpV9_bge_test.v
  BlimpV9_test/BlimpV9_bltu_test.v
  BlimpV9_test/BlimpV9_bgeu_test.v

  BlimpV9_test/BlimpV9_lb_test.v
  BlimpV9_test/BlimpV9_lh_test.v
  BlimpV9_test/BlimpV9_lbu_test.v
  BlimpV9_test/BlimpV9_lhu_test.v
  BlimpV9_test/BlimpV9_sb_test.v
  BlimpV9_test/BlimpV9_sh_test.v
  BlimpV9_test/BlimpV9_fence_test.v

  BlimpV9_test/BlimpV9_mul_test.v
  BlimpV9_test/BlimpV9_mulh_test.v
  BlimpV9_test/BlimpV9_mulhu_test.v
  BlimpV9_test/BlimpV9_mulhsu_test.v
  BlimpV9_test/BlimpV9_div_test.v
  BlimpV9_test/BlimpV9_divu_test.v
  BlimpV9_test/BlimpV9_rem_test.v
  BlimpV9_test/BlimpV9_remu_test.v

  BlimpV9_test/BlimpV9_mixed_test.v
  BlimpV9_test/BlimpV9_torture_test.v
)

# ------------------------------------------------------------------------
# BlimpV10
# ------------------------------------------------------------------------

set(BlimpV10_TESTS
  BlimpV10_test/BlimpV10_add_test.v
  BlimpV10_test/BlimpV10_addi_test.v
  BlimpV10_test/BlimpV10_lw_test.v
  BlimpV10_test/BlimpV10_sw_test.v
  BlimpV10_test/BlimpV10_jal_test.v
  BlimpV10_test/BlimpV10_jalr_test.v
  BlimpV10_test/BlimpV10_bne_test.v

  BlimpV10_test/BlimpV10_sub_test.v
  BlimpV10_test/BlimpV10_and_test.v
  BlimpV10_test/BlimpV10_or_test.v
  BlimpV10_test/BlimpV10_xor_test.v
  BlimpV10_test/BlimpV10_slt_test.v
  BlimpV10_test/BlimpV10_sltu_test.v
  BlimpV10_test/BlimpV10_sra_test.v
  BlimpV10_test/BlimpV10_srl_test.v
  BlimpV10_test/BlimpV10_sll_test.v

  BlimpV10_test/BlimpV10_andi_test.v
  BlimpV10_test/BlimpV10_ori_test.v
  BlimpV10_test/BlimpV10_xori_test.v
  BlimpV10_test/BlimpV10_slti_test.v
  BlimpV10_test/BlimpV10_sltiu_test.v
  BlimpV10_test/BlimpV10_srai_test.v
  BlimpV10_test/BlimpV10_srli_test.v
  BlimpV10_test/BlimpV10_slli_test.v
  BlimpV10_test/BlimpV10_lui_test.v
  BlimpV10_test/BlimpV10_auipc_test.v

  BlimpV10_test/BlimpV10_beq_test.v
  BlimpV10_test/BlimpV10_blt_test.v
  BlimpV10_test/BlimpV10_bge_test.v
  BlimpV10_test/BlimpV10_bltu_test.v
  BlimpV10_test/BlimpV10_bgeu_test.v

  BlimpV10_test/BlimpV10_lb_test.v
  BlimpV10_test/BlimpV10_lh_test.v
  BlimpV10_test/BlimpV10_lbu_test.v
  BlimpV10_test/BlimpV10_lhu_test.v
  BlimpV10_test/BlimpV10_sb_test.v
  BlimpV10_test/BlimpV10_sh_test.v
  BlimpV10_test/BlimpV10_fence_test.v

  BlimpV10_test/BlimpV10_mul_test.v
  BlimpV10_test/BlimpV10_mulh_test.v
  BlimpV10_test/BlimpV10_mulhu_test.v
  BlimpV10_test/BlimpV10_mulhsu_test.v
  BlimpV10_test/BlimpV10_div_test.v
  BlimpV10_test/BlimpV10_divu_test.v
  BlimpV10_test/BlimpV10_rem_test.v
  BlimpV10_test/BlimpV10_remu_test.v

  BlimpV10_test/BlimpV10_mixed_test.v
)


# ------------------------------------------------------------------------
# BlimpV11
# ------------------------------------------------------------------------

set(BlimpV11_TESTS
  BlimpV11_test/BlimpV11_add_test.v
  BlimpV11_test/BlimpV11_addi_test.v
  BlimpV11_test/BlimpV11_lw_test.v
  BlimpV11_test/BlimpV11_sw_test.v
  BlimpV11_test/BlimpV11_jal_test.v
  BlimpV11_test/BlimpV11_jalr_test.v
  BlimpV11_test/BlimpV11_bne_test.v

  BlimpV11_test/BlimpV11_sub_test.v
  BlimpV11_test/BlimpV11_and_test.v
  BlimpV11_test/BlimpV11_or_test.v
  BlimpV11_test/BlimpV11_xor_test.v
  BlimpV11_test/BlimpV11_slt_test.v
  BlimpV11_test/BlimpV11_sltu_test.v
  BlimpV11_test/BlimpV11_sra_test.v
  BlimpV11_test/BlimpV11_srl_test.v
  BlimpV11_test/BlimpV11_sll_test.v

  BlimpV11_test/BlimpV11_andi_test.v
  BlimpV11_test/BlimpV11_ori_test.v
  BlimpV11_test/BlimpV11_xori_test.v
  BlimpV11_test/BlimpV11_slti_test.v
  BlimpV11_test/BlimpV11_sltiu_test.v
  BlimpV11_test/BlimpV11_srai_test.v
  BlimpV11_test/BlimpV11_srli_test.v
  BlimpV11_test/BlimpV11_slli_test.v
  BlimpV11_test/BlimpV11_lui_test.v
  BlimpV11_test/BlimpV11_auipc_test.v

  BlimpV11_test/BlimpV11_beq_test.v
  BlimpV11_test/BlimpV11_blt_test.v
  BlimpV11_test/BlimpV11_bge_test.v
  BlimpV11_test/BlimpV11_bltu_test.v
  BlimpV11_test/BlimpV11_bgeu_test.v

  BlimpV11_test/BlimpV11_lb_test.v
  BlimpV11_test/BlimpV11_lh_test.v
  BlimpV11_test/BlimpV11_lbu_test.v
  BlimpV11_test/BlimpV11_lhu_test.v
  BlimpV11_test/BlimpV11_sb_test.v
  BlimpV11_test/BlimpV11_sh_test.v
  BlimpV11_test/BlimpV11_fence_test.v

  BlimpV11_test/BlimpV11_mul_test.v
  BlimpV11_test/BlimpV11_mulh_test.v
  BlimpV11_test/BlimpV11_mulhu_test.v
  BlimpV11_test/BlimpV11_mulhsu_test.v
  BlimpV11_test/BlimpV11_div_test.v
  BlimpV11_test/BlimpV11_divu_test.v
  BlimpV11_test/BlimpV11_rem_test.v
  BlimpV11_test/BlimpV11_remu_test.v

  BlimpV11_test/BlimpV11_mixed_test.v
)
