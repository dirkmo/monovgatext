module UartMaster(
    input  i_clk,
    input  i_reset,

    input  [7:0]  i_data,
    output [7:0]  o_data,
    output [15:0] o_addr,
    input  i_ack,
    output o_we,
    output o_cs,

    input  i_uart_rx,
    output o_uart_tx
);

parameter
    BAUDRATE /* verilator public */ = 115200,
    SYS_FREQ /* verilator public */ = 25000000;

wire uart_tx_ready;
wire uart_tx_pulse;
wire uart_rx_received;
wire [7:0] uart_rx_dat;
wire [7:0] uart_tx_dat;

UartProtocol uartprotocol0 (
    .i_clk(i_clk),
    .i_reset(i_reset),
    .i_ack(i_ack),
    .i_dat(i_data),
    .o_dat(o_data),
    .o_addr(o_addr),
    .o_we(o_we),
    .o_cs(o_cs),
    .i_uart_received_pulse(uart_rx_received),
    .i_uart_dat(uart_rx_dat),
    .i_uart_send_ready(uart_tx_ready),
    .o_uart_send_pulse(uart_tx_pulse),
    .o_uart_dat(uart_tx_dat)
);

uart_rx #(.TICK(SYS_FREQ/BAUDRATE)) uart_rx0(
    .i_clk(i_clk),
    .i_reset(i_reset),
    .o_dat(uart_rx_dat),
    .o_received(uart_rx_received),
    .rx(i_uart_rx)
);

uart_tx #(.TICK(SYS_FREQ/BAUDRATE)) uart_tx0(
    .i_clk(i_clk),
    .i_reset(i_reset),
    .i_dat(uart_tx_dat),
    .i_start(uart_tx_pulse),
    .o_ready(uart_tx_ready),
    .tx(o_uart_tx)
);

endmodule
