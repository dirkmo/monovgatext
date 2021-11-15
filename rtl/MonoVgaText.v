module MonoVgaText(
    input             i_clk,
    input             i_reset,

    output     [11:0] o_vgamaster_addr,
    input      [15:0] i_vgamaster_dat,
    output            o_vgamaster_cs,
    output            o_vgamaster_access,

    input      [15:0] i_vgaslave_dat,
    output reg [15:0] o_vgaslave_dat,
    input             i_vgaslave_addr,
    input             i_vgaslave_cs,
    input             i_vgaslave_we,
    output reg        o_vgaslave_ack,

    output reg        o_hsync,
    output reg        o_vsync,
    output            o_pixel
);

parameter
    HSIZE /*verilator public*/ = 640,
    HFP   /*verilator public*/ = 16,
    HSYNC /*verilator public*/ = 96,
    HBP   /*verilator public*/ = 48,
    HPOL  /*verilator public*/ = 0,
    VSIZE /*verilator public*/ = 480,
    VFP   /*verilator public*/ = 10,
    VSYNC /*verilator public*/ = 2,
    VBP   /*verilator public*/ = 33,
    VPOL  /*verilator public*/ = 0;

parameter
    FONT_WIDTH = 8,
    FONT_HEIGHT = 16;

parameter
    FONT_BASE_INITIAL   = 4'h0, // 0x0000
    SCREEN_BASE_INITIAL = 4'h1; // 0x1000

// ----------------------------------------------------------------------------
// This module generates:
// 640x480, monochrome, 60 Hz, 25.175 MHz pixel clock
// sync pulses negative
//
// Font properties:
// Character geometry: 8(H)x16(V)
// 8x16 pixels per char = 16 Bytes per character
// 256*16 = 4096 bytes font ROM
// 0 .. 0xFFF (10-bit, 9:0)
//
// Screen buffer:
// Resolution: 640x480, Font: 8x16 --> 80x30 = 2400 chars per screen
// 0 .. 0x95f (10-bit, 9:0)

// ----------------------------------------------------------------------------
// horizontal (x) and vertical (y) pixel position counters
reg [9:0] x /*verilator public*/;
reg [9:0] y /*verilator public*/;

// ----------------------------------------------------------------------------
// Timing generation

// Horizontal
// Scanline part	Pixels	Time [µs]
// Visible area	    640	    25.422045680238
// Front porch	    16	    0.63555114200596
// Sync pulse	    96	    3.8133068520357
// Back porch	    48  	1.9066534260179
// Whole line	    800	    31.777557100298

// For simpler screen address generation, visible pixels start at 8:
// [8 BP] [640 visible] [16 FP] [96 SYNC] [40 BP]

// signals come 1 clock early
wire h_start   = (x == 8 - 1);
wire h_fp      = (x == 8 + HSIZE - 1); // start front porch
wire h_sp      = (x == 8 + HSIZE + HFP - 1); // start sync pulse
wire h_bp      = (x == 8 + HSIZE + HFP + HSYNC - 1); // start back porch
wire h_last    = (x ==     HSIZE + HFP + HSYNC + HBP - 1); // last column

always @(posedge i_clk)
begin
    x <= h_last ? 'h0 : x + 'd1;
    if (i_reset)
        x <= 0;
end

reg isVisible_x;
always @(posedge i_clk)
begin
    if (h_start)
        isVisible_x <= 1'b1;
    if (h_fp || i_reset)
        isVisible_x <= 1'b0;
end

// Vertical
// Frame part	    Lines	Time [ms]
// Visible area	    480	    15.253227408143
// Front porch	    10	    0.31777557100298
// Sync pulse	    2	    0.063555114200596
// Back porch	    33	    1.0486593843098
// Whole frame	    525	    16.683217477656

// signals come 1 clock early
wire v_fp   = (y == VSIZE - 1); // start front porch
wire v_sp   = (y == VSIZE + VFP - 1); // start sync pulse
wire v_bp   = (y == VSIZE + VFP + VSYNC - 1); // start back porch
wire v_last = (y == VSIZE + VFP + VSYNC + VBP - 1); // last line

always @(posedge i_clk)
begin
    if (h_last)
        y <= v_last ? 'h0 : y + 'd1;
    if (i_reset)
        y <= VSIZE + VFP - 1; // instead of 0, starting with vsync to well-position the first frame
end

reg isVisible_y;
always @(posedge i_clk)
begin
    if (v_last && h_last)
        isVisible_y <= 1'b1;
    if (v_fp || i_reset)
        isVisible_y <= 1'b0;
end

wire isVisible = isVisible_x && isVisible_y;

// syncs
always @(posedge i_clk)
begin
    if (h_sp) o_hsync <= HPOL;
    if (h_bp) o_hsync <= ~HPOL;
    if (v_sp) o_vsync <= VPOL;
    if (v_bp) o_vsync <= ~VPOL;
    if (i_reset) begin
        o_hsync <= ~HPOL;
        o_vsync <= ~VPOL;
    end
end


// ----------------------------------------------------------------------------
// CPU databus interface

reg [ 7: 0] r_cursor      = 8'd219;
reg [11: 0] r_cursor_addr = 12'd0;

// register map
// 0:  [7:0] Cursor character index
// 1: [11:0] Cursor address [7:0]

always @(posedge i_clk)
    case (i_vgaslave_addr)
        1'h0: o_vgaslave_dat <= {8'h00, r_cursor};
        1'h1: o_vgaslave_dat <= {4'h0, r_cursor_addr[11:0]};
    endcase

always @(posedge i_clk)
begin
    if (i_vgaslave_cs)
    begin
        if (i_vgaslave_we) begin
            case (i_vgaslave_addr)
                1'h0: r_cursor <= i_vgaslave_dat[7:0];
                1'h1: r_cursor_addr <= i_vgaslave_dat[11:0];
            endcase
        end
    end
end

always @(posedge i_clk)
    o_vgaslave_ack <= i_vgaslave_cs;

// ----------------------------------------------------------------------------
// read data from memory in two consecutive ram accesses

// A character is 8 pixels wide. Every char needs 2 memory accesses per line:
// First access: Fetch two chars from screen memory
// Second access: Fetch byte from font which represents a line of 8 pixels of current char ("fontline")
// Both accesses must be finished before the first pixel of the character is drawn

// phase 0: output screen addr
// phase 1: fetch characters from data bus
// phase 2: output fontline address (dependent on character)
// phase 3: fetch fontline

// start_fetch
// Triggers one cycle earlier to prepare the multi-busmaster module that this module wants memory access.
wire start_fetch = (isVisible && (x[2:0] == 3'h3)) || (isVisible_y && (x==3));

reg [3:0] r_phases;
always @(posedge i_clk)
begin
    if (start_fetch)
        r_phases <= 4'b0001;
    else
        r_phases <= { r_phases[2:0], 1'b0 };
end

wire output_addr_char_from_screen = r_phases[0] && ~x[3];
wire       fetch_char_from_screen = r_phases[1] && ~x[3];
wire      output_address_fontline = r_phases[2];
wire               fetch_fontline = r_phases[3];

// ----------------------------------------------------------------------------
// screen memory address generation

reg [11:0] r_screen_addr_nextline;

always @(posedge i_clk)
begin
    if (h_last && (y[3:0] == 4'b1111))
        r_screen_addr_nextline <= r_screen_addr_nextline + HSIZE / FONT_WIDTH;
    if (~isVisible_y)
        r_screen_addr_nextline <= 0;
end

reg  [11:0] r_screen_addr_rel; // relative address to r_screen_addr_nextline

always @(posedge i_clk)
begin
    if (x[2:0] == 3'b111) begin
        r_screen_addr_rel <= r_screen_addr_rel + 'h1; //{11'h0, isVisible_x};
    end
    if (x==0)
        r_screen_addr_rel <= r_screen_addr_nextline;
end

wire [12:0] screen_addr = { 1'b1, r_screen_addr_rel[11:0] };

reg [23:0] blink;
always @(posedge i_clk)
    blink <= blink + 1'b1;

wire on_cursor_position = (r_screen_addr_rel == r_cursor_addr) && blink[23];

// ----------------------------------------------------------------------------
// Fontline read-out

// font memory address generation
wire [11:0] font_addr_rel;
wire [11:0] font_addr = font_addr_rel[11:0];

reg [15:0] characters;
always @(posedge i_clk)
    if (fetch_char_from_screen)
        characters <= i_vgamaster_dat;
    else if (x[3:0] == 13)
        characters <= { characters[7:0], 8'h0 };

wire [7:0] char = on_cursor_position ? r_cursor : characters[15:8];

assign font_addr_rel = {  char, y[3:0] };


// the pixels of the current charecter line
reg [7:0] r_fontline;

always @(posedge i_clk)
begin
    if (fetch_fontline)
    begin
        r_fontline <= font_addr[0] ? i_vgamaster_dat[7:0] : i_vgamaster_dat[15:8];
    end
end

// ----------------------------------------------------------------------------
// vga memory interface

assign o_vgamaster_cs   = output_address_fontline || output_addr_char_from_screen;

assign o_vgamaster_addr = output_address_fontline      ? { 1'b0,   font_addr[11:1] } :
                          output_addr_char_from_screen ? { 1'b1, screen_addr[11:1] } : 12'h00;

// o_vgamaster_access informs the multi-bus-master that the vga module wants
// memory access in the next clock cycle
assign o_vgamaster_access = (start_fetch && ~x[3]) || r_phases[1];

// ----------------------------------------------------------------------------

// output the pixel
assign o_pixel = isVisible && r_fontline[~x[2:0]];

endmodule
