module memory(
    input             i_clk,
    input      [12:0] i_addr,
    input      [15:0] i_dat,
    output reg [15:0] o_dat,
    input             i_we,
    input             i_cs,
    output reg        o_ack
);

reg [15:0] mem[0:'h1fff];

always @(posedge i_clk)
    o_dat <= mem[i_addr[12:0]];

always @(posedge i_clk)
begin
    if(i_cs && i_we) begin
        mem[i_addr[12:0]] <= i_dat;
    end
end

always @(posedge i_clk)
    o_ack <= i_cs;

initial begin
    $readmemh("font16.mem", mem, 0);
    $readmemh("screen16.mem", mem, 4096);
end

endmodule