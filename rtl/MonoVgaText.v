module MonoVgaText(
    input             i_clk,
    input             i_reset,

    output     [15:0] o_vgaram_addr,
    input      [7:0]  i_vgaram_dat,
    output            o_vgaram_cs,
    output            o_vgaram_access,

    input      [7:0]  i_dat,
    output reg [7:0]  o_dat,
    input      [1:0]  i_addr,
    input             i_cs,
    input             i_we,

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

reg [15:12] r_font_base = FONT_BASE_INITIAL; // base address of fonts
reg [15:12] r_screen_base = SCREEN_BASE_INITIAL; // base address of screen
reg [ 7: 0] r_cursor = 8'd219;
reg [11: 0] r_cursor_addr = 12'd0;

// register map
// 0: [7:4] font address, [3:0] screen address
// 1: Cursor character index
// 2: Cursor address low byte [7:0]
// 3: Cursor address high byte [11:8]

always @(*)
    case (i_addr)
        2'h0: o_dat = {r_font_base[15:12], r_screen_base [15:12]};
        2'h1: o_dat = r_cursor;
        2'h2: o_dat = r_cursor_addr[ 7:0];
        2'h3: o_dat = { 4'h0, r_cursor_addr[11:8]};
    endcase

always @(posedge i_clk)
begin
    if (i_cs)
    begin
        if (i_we) begin
            case (i_addr)
                2'h0: {r_font_base[15:12], r_screen_base [15:12]} <= i_dat[7:0];
                2'h1: r_cursor <= i_dat;
                2'h2: r_cursor_addr[ 7:0] <= i_dat;
                2'h3: r_cursor_addr[11:8] <= i_dat[3:0];
            endcase
        end
    end
end


// ----------------------------------------------------------------------------
// read data from memory in two consecutive ram accesses

// A character is 8 pixels wide. Every char needs 2 memory accesses:
// First access: Fetch char from screen memory, trigger: fetch_char_from_screen
// Second access: Fetch byte from font which represents a line of 8 pixels of current char, trigger: fetch_fontline
// Both accesses must be finished before the first pixel of the character is drawn

// start_fetch
// Triggers one cycle earlier to prepare the multi-busmaster module that this module wants memory access.
wire start_fetch = (isVisible && (x[2:0] == 3'b101)) || (isVisible_y && (x==5));

reg fetch_char_from_screen;
reg fetch_fontline;

always @(posedge i_clk)
begin
    fetch_char_from_screen <= start_fetch;
    fetch_fontline <= fetch_char_from_screen;
end


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

wire [15:0] screen_addr = { r_screen_base[15:12], r_screen_addr_rel[11:0] };

reg [23:0] blink;
always @(posedge i_clk)
    blink <= blink + 1'b1;

wire on_cursor_position = (r_screen_addr_rel == r_cursor_addr) && blink[23];

// ----------------------------------------------------------------------------
// Fontline read-out

// font memory address generation
reg  [11:0] r_font_addr_rel;
wire [15:0] font_addr = { r_font_base[15:12], r_font_addr_rel[11:0] };
wire [7:0] character = on_cursor_position ? r_cursor : i_vgaram_dat;

always @(posedge i_clk)
begin
    if (fetch_char_from_screen) begin
        r_font_addr_rel <= { character, y[3:0] };
    end
end

// the pixels of the current charecter line
reg [7:0] r_fontline;

always @(posedge i_clk)
begin
    if (fetch_fontline)
    begin
        r_fontline <= i_vgaram_dat;
    end
end

// ----------------------------------------------------------------------------
// vga memory interface

assign o_vgaram_cs   = fetch_fontline || fetch_char_from_screen;

assign o_vgaram_addr = fetch_fontline         ? font_addr :
                       fetch_char_from_screen ? screen_addr
                                              : 16'h00;

// o_vgaram_access informs the multi-bus-master that the vga module wants
// memory access in the next clock cycle
assign o_vgaram_access = start_fetch || fetch_char_from_screen;

// ----------------------------------------------------------------------------

// output the pixel
assign o_pixel = isVisible && r_fontline[~x[2:0]];

endmodule
