module top(
    input  clk100mhz,
    input  reset_n,
    
    output hsync,
    output vsync,
    output [2:0] red,
    output [2:0] green,
    output [2:0] blue
);

wire clk25mhz;
wire pll_locked;
// icepll -i 100 -o 25 -m -f pll.v
pll pll0(clk100mhz, clk25mhz, pll_locked);

wire [15:0] vga_addr;
wire [ 7:0] vga_dat;
wire vga_cs;
wire pix;

MonoVgaText vga0(
    .i_clk(clk25mhz),
    .i_reset(~reset_n),
    .o_vgaram_addr(vga_addr),
    .i_vgaram_dat(vga_dat),
    .o_vgaram_cs(),
    .o_vgaram_access(),
    .i_dat(8'h0),
    .o_dat(),
    .i_addr(1'h0),
    .i_cs(1'b0),
    .i_we(1'b0),
    .o_hsync(hsync),
    .o_vsync(vsync),
    .o_pixel(pix)
);

memory mem0(
    .i_addr(vga_addr[12:0]),
    .o_dat(vga_dat)
);

assign red[2:0]   = {pix,pix,pix};
assign green[2:0] = {pix,pix,pix};
assign blue[2:0]  = {pix,pix,pix};

endmodule