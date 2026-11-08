//========================================================================
// CSRFile.v
//========================================================================
// Author: Emily Lan
//========================================================================
// Stores all control and status registers (CSRs)

`ifndef HW_EXECUTE_STATE_CSRFILE_V
`define HW_EXECUTE_STATE_CSRFILE_V

`include "intf/CSRIntf.v"

module CSRFile (
    input  logic clk,
    input  logic rst,
    CSRIntf.F_intf csr
);

    // CSR registers
    logic [31:0] fcsr;
    logic [4:0] fflags;
    logic [2:0] frm;
    assign fcsr = {24'b0, frm, fflags};


    // Rdy always high
    assign csr.rdy = 1'b1;

    // Read logic
    always_comb begin
    case (csr.addr)
        12'h001: csr.rdata = {27'b0, fflags};          // fflags
        12'h002: csr.rdata = {29'b0, frm};             // frm
        12'h003: csr.rdata = {24'b0, frm, fflags};     // fcsr
        default: csr.rdata = 32'h0;
    endcase
    end

    // Write logic
    always_ff @(posedge clk) begin
        if (rst) begin
            fflags <= 5'b0;
            frm    <= 3'b0;
        end
        else if (csr.val && csr.rdy) begin
            case (csr.cmd)
                3'b001: begin // write (CSRRW)
                    case (csr.addr)
                    12'h001: fflags <= csr.wdata[4:0];
                    12'h002: frm    <= csr.wdata[2:0];
                    12'h003: begin
                        fflags <= csr.wdata[4:0];
                        frm    <= csr.wdata[7:5];
                    end
                    default: ;
                    endcase
                end

                3'b010: begin // set (CSRRS)
                    case (csr.addr)
                    12'h001: fflags <= fflags | csr.wdata[4:0];
                    12'h002: frm    <= frm    | csr.wdata[2:0];
                    12'h003: begin
                        fflags <= fflags | csr.wdata[4:0];
                        frm    <= frm    | csr.wdata[7:5];
                    end
                    default: ;
                    endcase
                end

                3'b011: begin // clear (CSRRC)
                    case (csr.addr)
                    12'h001: fflags <= fflags & ~csr.wdata[4:0];
                    12'h002: frm    <= frm    & ~csr.wdata[2:0];
                    12'h003: begin
                        fflags <= fflags & ~csr.wdata[4:0];
                        frm    <= frm    & ~csr.wdata[7:5];
                    end
                    default: ;
                    endcase
                end

                default: ;
            endcase
        end
    end


endmodule

`endif // HW_EXECUTE_STATE_CSRFILE_V
