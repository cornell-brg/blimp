//========================================================================
// FPUMsg - FPU message interface
// Original Author: Parker Schless
// Adapted to C2S2 BLIMP by: Emily Lan
// Code taken from: https://github.com/cornell-brg/parker-fpu/blob/main/sim/fpu/FPUMsg.v
//========================================================================

`ifndef FPU_FPUMSG_V
`define FPU_FPUMSG_V

typedef enum logic [3:0] {
  FPU_OP_ADD = 4'd0,
  FPU_OP_SUB = 4'd1,
  FPU_OP_MUL = 4'd2
} fpu_op_t;

`define FPU_REQ(EXP_BITS, FR_BITS) fpu_req_``EXP_BITS``_``FR_BITS``_t

`define FPU_REQ_DEFINE(EXP_BITS, FR_BITS) \
  typedef struct packed                   \
  {                                       \
    fpu_op_t             op;              \
    logic                sn0;             \
    logic [EXP_BITS-1:0] exp0;            \
    logic [FR_BITS-1:0]  fr0;             \
    logic                sn1;             \
    logic [EXP_BITS-1:0] exp1;            \
    logic [FR_BITS-1:0]  fr1;             \
  } `FPU_REQ(EXP_BITS, FR_BITS)


`define FPU_RESP(EXP_BITS, FR_BITS) fpu_resp_``EXP_BITS``_``FR_BITS``_t

`define FPU_RESP_DEFINE(EXP_BITS, FR_BITS) \
  typedef struct packed                    \
  {                                        \
    logic                sn;               \
    logic [EXP_BITS-1:0] exp;              \
    logic [FR_BITS-1:0]  fr;               \
  } `FPU_RESP(EXP_BITS, FR_BITS)

`FPU_REQ_DEFINE(5, 10);
`FPU_RESP_DEFINE(5, 10);
`FPU_REQ_DEFINE(8, 23);
`FPU_RESP_DEFINE(8, 23);
`FPU_REQ_DEFINE(11, 52);
`FPU_RESP_DEFINE(11, 52);
`FPU_REQ_DEFINE(15, 112);
`FPU_RESP_DEFINE(15, 112);

`endif /* FPU_FPUMSG_V */