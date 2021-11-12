module top(
    input  clk100mhz,
    input  reset_n,
    
    output hsync,
    output vsync,
    output [2:0] red,
    output [2:0] green,
    output [2:0] blue,

    output uart_tx,
    input uart_rx
);

wire clk25mhz /* verilator public */;

`ifdef SIM
reg [1:0] counter;
always @(posedge clk100mhz)
    counter <= counter + 1'b1;
assign clk25mhz = counter[1];
`else
wire pll_locked;
// icepll -i 100 -o 25 -m -f pll.v
pll pll0(clk100mhz, clk25mhz, pll_locked);
`endif

wire [15:0] addr;
wire [15:0] dat_from_mem;
wire [15:0] dat_from_master;
wire vga_cs;
wire pix;
wire cs;
wire ack;
wire we;

MasterShell master0(
    .i_clk(clk25mhz),
    .i_reset(~reset_n),
    .i_dat(dat_from_mem),
    .o_dat(dat_from_master),
    .o_addr(addr),
    .o_cs(cs),
    .o_we(we),
    .i_ack(ack),
    .o_hsync(hsync),
    .o_vsync(vsync),
    .o_pixel(pix),
    .i_uart_rx(uart_rx),
    .o_uart_tx(uart_tx)
);

memory mem0(
    .i_clk(clk25mhz),
    .i_addr(addr[12:0]),
    .i_dat(dat_from_master),
    .o_dat(dat_from_mem),
    .i_we(we),
    .i_cs(cs),
    .o_ack(ack)
);

assign red[2:0]   = {pix,pix,pix};
assign green[2:0] = {pix,pix,pix};
assign blue[2:0]  = {pix,pix,pix};

endmodule