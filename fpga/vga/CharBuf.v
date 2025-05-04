//========================================================================
// CharBuf.v
//========================================================================
// A character buffer for storing the characters from the stream
//
// In addition to the normal visible ASCII characters, we support the
// following characters:
//
//  - DEL: Delete the last character and move the cursor back
//  - ESC: Clear the screen to the reset state
//  - LF: (Newline) Start a new line

`ifndef FPGA_PROTOCOLS_VGA_CHARBUF_V
`define FPGA_PROTOCOLS_VGA_CHARBUF_V

`include "fpga/vga/CharLUT.v"

module CharBuf #(
  parameter p_num_rows = 16,
  parameter p_num_cols = 32
)(
  input  logic clk,
  input  logic rst,

  //----------------------------------------------------------------------
  // ASCII Stream Input
  //----------------------------------------------------------------------

  input  logic [7:0] ascii,
  input  logic       ascii_val,

  //----------------------------------------------------------------------
  // VGA Driver Interface
  //----------------------------------------------------------------------
  // Index into row buffers, assuming 8x8 characters are tiled across the
  // screen. Reads have a one-cycle latency

  input  logic [6:0] read_hchar,
  input  logic [4:0] read_vchar,
  input  logic [2:0] read_hoffset,
  input  logic [3:0] read_voffset,
  output logic       read_lit,
  output logic       out_of_bounds
);

  //----------------------------------------------------------------------
  // Create signals to handle special characters
  //----------------------------------------------------------------------

  localparam ASCII_ESC = 8'h1B;
  localparam ASCII_DEL = 8'h7F;
  localparam ASCII_LF  = 8'h0A;

  logic is_esc, is_del, is_newline;

  assign is_esc     = ( ascii == ASCII_ESC );
  assign is_del     = ( ascii == ASCII_DEL );
  assign is_newline = ( ascii == ASCII_LF  );

  logic buf_write;
  assign buf_write = ascii_val;

  //----------------------------------------------------------------------
  // Create memory
  //----------------------------------------------------------------------

  logic [$clog2(p_num_rows)-1:0] wrow;
  logic [$clog2(p_num_cols)-1:0] wcol;
  logic [                   7:0] wdata;
  logic [$clog2(p_num_rows)-1:0] rrow;
  logic [$clog2(p_num_cols)-1:0] rcol;
  logic [                   7:0] rdata;

  logic                          clr_screen;
  logic                          clr_row;
  logic [$clog2(p_num_rows)-1:0] clr_row_idx;

  assign clr_screen = is_esc & buf_write;

  logic [7:0] mem [p_num_rows-1:0] [p_num_cols-1:0];

  genvar i;

  generate
    for( i = 0; i < p_num_rows; i = i + 1 ) begin: MEM_ROWS
  
      always_ff @( posedge clk ) begin

        //----------------------------------------------------------------
        // Reset
        //----------------------------------------------------------------

        if( rst ) begin
          mem[i] <= '{default: '0};
        end

        //----------------------------------------------------------------
        // Clearing Screen
        //----------------------------------------------------------------

        else if( clr_screen ) begin
          mem[i] <= '{default: '0};
        end

        //----------------------------------------------------------------
        // Clearing Row
        //----------------------------------------------------------------

        else if( clr_row & (i == clr_row_idx) ) begin
          mem[i] <= '{default: '0};
        end

        //----------------------------------------------------------------
        // Writing Value
        //----------------------------------------------------------------

        else if( buf_write & (i == wrow) & !is_newline ) begin
          mem[i][wcol] <= wdata;
        end
      end
    end
  endgenerate

  //----------------------------------------------------------------------
  // Reading Value
  //----------------------------------------------------------------------

  always_ff @( posedge clk ) begin
    if( rst ) rdata <= '0;
    else      rdata <= mem[rrow][rcol];
  end

  //----------------------------------------------------------------------
  // Keep track of the cursor
  //----------------------------------------------------------------------

  logic [$clog2(p_num_rows)-1:0] cursor_y;
  logic [$clog2(p_num_cols)-1:0] cursor_x;
  logic [$clog2(p_num_rows)-1:0] next_cursor_y;
  logic [$clog2(p_num_cols)-1:0] next_cursor_x;

  always_ff @( posedge clk ) begin
    if( rst ) begin
      cursor_x <= '0;
      cursor_y <= '0;
    end else if( clr_screen ) begin
      cursor_x <= '0;
      cursor_y <= '0;
    end else begin
      cursor_x <= next_cursor_x;
      cursor_y <= next_cursor_y;
    end
  end

  logic [$clog2(p_num_rows)-1:0] cursor_y_inc;
  logic [$clog2(p_num_cols)-1:0] cursor_x_inc;

  assign cursor_y_inc = 'd1;
  assign cursor_x_inc = 'd1;

  always_comb begin
    next_cursor_x = cursor_x;
    next_cursor_y = cursor_y;

    //--------------------------------------------------------------------
    // Decrement on deletion
    //--------------------------------------------------------------------

    if( is_del & buf_write ) begin
      if( cursor_x != '0 )
        next_cursor_x = cursor_x - cursor_x_inc;
    end

    //--------------------------------------------------------------------
    // Go to next line on newline
    //--------------------------------------------------------------------

    else if( is_newline & buf_write ) begin
      next_cursor_x = '0;
      next_cursor_y = cursor_y + cursor_y_inc;
    end

    //--------------------------------------------------------------------
    // Increment on normal write
    //--------------------------------------------------------------------

    else if( buf_write ) begin
      next_cursor_x = cursor_x + cursor_x_inc;
      if( next_cursor_x == ($clog2(p_num_cols))'(p_num_cols) )
        next_cursor_x = '0;
      if( next_cursor_x == '0 ) begin
        next_cursor_y = cursor_y + cursor_y_inc;
        if( next_cursor_y == ($clog2(p_num_rows))'(p_num_rows) )
          next_cursor_y = '0;
      end
    end
  end

  //----------------------------------------------------------------------
  // Keep track of row shifts
  //----------------------------------------------------------------------

  logic [$clog2(p_num_rows)-1:0] shift_offset;
  logic [$clog2(p_num_rows)-1:0] next_shift_offset;
  logic [$clog2(p_num_rows)-1:0] shift_offset_inc;

  assign shift_offset_inc = 'd1;

  always_ff @( posedge clk ) begin
    if     ( rst        ) shift_offset <= 'd1;
    else if( clr_screen ) shift_offset <= 'd1;
    else                  shift_offset <= next_shift_offset;
  end

  always_comb begin
    next_shift_offset = shift_offset;
    clr_row           = '0;
    clr_row_idx       = '0;

    if( buf_write & ( !is_del ) & ( next_cursor_x == '0 ) ) begin
      // Shifting to a new line
      next_shift_offset = ( shift_offset == ($clog2(p_num_rows))'( p_num_rows - 1 ) ) ? '0 
                          : shift_offset + shift_offset_inc;
      clr_row           = 1'b1;
      clr_row_idx       = next_cursor_y;
    end
    if( next_shift_offset == ($clog2(p_num_rows))'(p_num_rows) )
      next_shift_offset = 'd0;
  end

  //----------------------------------------------------------------------
  // Assign writing signals
  //----------------------------------------------------------------------

  assign wrow  = cursor_y;
  assign wcol  = ( is_del ) ? next_cursor_x : cursor_x;
  assign wdata = ( is_del ) ? 8'h0 : ascii;

  //----------------------------------------------------------------------
  // Assign reading signals
  //----------------------------------------------------------------------

  assign rcol = read_hchar[$clog2(p_num_cols)-1:0];

  // Use one extra bit to avoid wraparound issues
  logic [$clog2(p_num_rows):0] rrow_tmp;
  always_comb begin
    rrow_tmp = ( { 1'b0, read_vchar[$clog2(p_num_rows)-1:0] }
               + { 1'b0, shift_offset } );
    if( rrow_tmp >= p_num_rows )
      rrow_tmp = rrow_tmp - ($clog2(p_num_rows + 1))'(p_num_rows);
  end
  assign rrow = rrow_tmp[$clog2(p_num_rows)-1:0];

  //----------------------------------------------------------------------
  // Assign final output
  //----------------------------------------------------------------------
  // Use a CharLUT to decipher the stored ASCII character

  logic rdata_lit;
  logic [2:0] read_hoffset_buf;
  logic [3:0] read_voffset_buf;

  always_ff @( posedge clk ) begin
    if( rst ) begin
      read_hoffset_buf <= '0;
      read_voffset_buf <= '0;
    end else begin
      read_hoffset_buf <= read_hoffset;
      read_voffset_buf <= read_voffset;
    end
  end

  CharLUT char_lut (
    .ascii_char (rdata),
    .vidx       (read_voffset_buf),
    .hidx       (read_hoffset_buf),
    .lit        (rdata_lit)
  );
  
  logic invalid_hcoord;
  logic invalid_vcoord;
  logic invalid_coord;

  assign invalid_hcoord = ( read_hchar >= p_num_cols );
  assign invalid_vcoord = ( read_vchar >= p_num_rows );

  always_ff @( posedge clk ) begin
    if( rst )
      invalid_coord <= 1'b1;
    else
      invalid_coord <= invalid_hcoord | invalid_vcoord;
  end

  logic cursor_present;

  always_ff @( posedge clk ) begin
    if( rst )
      cursor_present <= 1'b0;
    else
      cursor_present <= ( rrow         == cursor_y ) &
                        ( rcol         == cursor_x ) &
                        ( read_voffset == 4'b1111  ) &
                        ( read_hoffset != 3'b111   );
  end

  always_comb begin
    if( invalid_coord )
      read_lit = 1'b0;
    else if( cursor_present )
      read_lit = 1'b1;
    else
      read_lit = rdata_lit;
  end

  assign out_of_bounds = invalid_coord;

endmodule

`endif // FPGA_PROTOCOLS_VGA_CHARBUF_V
