//========================================================================
// MemMsg.v
//========================================================================
// The type of default message to use when communicating with memory
//
//  - op: The operation to perform (read or write)
//  - opaque: Preserved bits (set the same for a request and corresponding
//            response)
//  - addr: The memory address to operate on. Must be word-aligned
//  - strb: A byte mask for which bytes are valid on a write (undefined for
//          a read)
//  - data:
//     - Request: The data to write (undefined for a read)
//     - Response: The data read (undefined for a write)

`ifndef TYPES_MEMMSG_V
`define TYPES_MEMMSG_V

//------------------------------------------------------------------------
// Implement parametrized typed through macro functions
//------------------------------------------------------------------------

typedef enum logic {
  MEM_MSG_READ  = 1'b0,
  MEM_MSG_WRITE = 1'b1,
  MEM_MSG_X     = 1'bx
} t_op;

`define MEM_REQ( OPAQ_BITS ) \
  t_mem_req_msg_``OPAQ_BITS``

`define MEM_REQ_DEFINE( OPAQ_BITS ) \
  typedef struct packed {           \
    t_op                  op;       \
    logic [OPAQ_BITS-1:0] opaque;   \
    logic [31:0]          addr;     \
    logic [3:0]           strb;     \
    logic [31:0]          data;     \
  } `MEM_REQ( OPAQ_BITS )

`define MEM_RESP( OPAQ_BITS ) \
  t_mem_resp_msg_``OPAQ_BITS``

`define MEM_RESP_DEFINE( OPAQ_BITS ) \
  typedef struct packed {            \
    t_op                  op;        \
    logic [OPAQ_BITS-1:0] opaque;    \
    logic [31:0]          addr;      \
    logic [3:0]           strb;      \
    logic [31:0]          data;      \
  } `MEM_RESP( OPAQ_BITS )

//------------------------------------------------------------------------
// Define commonly-used parametrizations
//------------------------------------------------------------------------

`MEM_REQ_DEFINE ( 8 );
`MEM_RESP_DEFINE( 8 );

`endif // TYPES_MEMMSG_V
