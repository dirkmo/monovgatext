module memory(
    input        i_clk,
    input  [12:0] i_addr,
    input  [7:0] i_dat,
    output [7:0] o_dat,
    input        i_we,
    input        i_cs
);

reg [7:0] mem[0:'h1fff];

always @(posedge i_clk)
    if (i_cs && ~i_we)
        o_dat <= mem[i_addr[7:0]];

always @(posedge i_clk)
begin
    if(i_cs && i_we) begin
        mem[i_addr[7:0]] <= i_dat;
    end
end

initial begin
    $readmemh("font.mem", mem, 0);
    $readmemh("screen.mem", mem, 4096);
end

endmodule