module MasterShell(
    input             i_clk,
    input             i_reset,
    input      [7:0]  i_dat,
    output reg [7:0]  o_dat,
    output    [15:0]  o_addr,
    output            o_cs,
    output            o_we,
    input             i_ack,

    // MonoVgaText
    output reg        o_hsync,
    output reg        o_vsync,
    output            o_pixel,

    // uart master
    input             i_uart_rx,
    output            o_uart_tx
);

wire [15:0] vgamaster_addr;
wire vgamaster_cs;
wire vgamaster_access;
reg vgaslave_cs;

wire [7:0] uartmaster_dat;
wire [15:0] uartmaster_addr;
wire uartmaster_ack;
wire uartmaster_we;
wire uartmaster_cs;

reg r_vga_active;
always @(posedge i_clk)
    if (vgamaster_access)
        r_vga_active <= 1;
    else
        r_vga_active <= 0;

MonoVgaText vga0(
    .i_clk(i_clk),
    .i_reset(i_reset),
    // vga bus master
    .o_vgaram_addr(vgamaster_addr),
    .i_vgaram_dat(i_dat),
    .o_vgaram_cs(vgamaster_cs),
    .o_vgaram_access(vgamaster_access),
    // vga bus slave
    .i_dat(i_dat),
    .o_dat(o_vgaslave_dat),
    .i_addr(o_addr[1:0]),
    .i_cs(vgaslave_cs),
    .i_we(o_we),
    .o_hsync(o_hsync),
    .o_vsync(o_vsync),
    .o_pixel(o_pixel)
);

UartMaster uartmaster0(
    .i_clk(i_clk),
    .i_reset(i_reset),
    .i_data(i_dat),
    .o_data(uartmaster_dat),
    .o_addr(uartmaster_addr),
    .i_ack(uartmaster_ack),
    .o_we(uartmaster_we),
    .o_cs(uartmaster_cs),
    .i_uart_rx(uart_rx),
    .o_uart_tx(uart_tx)
);

assign          o_dat =  vgaslave_cs ? o_vgaslave_dat : uartmaster_dat;
assign         o_addr = r_vga_active ? vgamaster_addr : uartmaster_addr;
assign           o_we = r_vga_active ? 1'b0 : uartmaster_we;
assign           o_cs = r_vga_active ? vgamaster_cs : 
                         vgaslave_cs ? 1'b0 : uartmaster_cs;

assign    vgaslave_cs = (o_addr[15:1] == 15'h7ff8); // 0xfff0, 0xfff1

assign uartmaster_ack = ~r_vga_active && i_ack;

endmodule