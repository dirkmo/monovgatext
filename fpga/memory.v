module memory(
    input [12:0] i_addr,
    output [7:0] o_dat
);

reg [7:0] font[0:'hfff];
reg [7:0] screen[0:'d2399];

assign o_dat = i_addr[12] ? screen[i_addr[11:0]] : font[i_addr[11:0]];

initial begin
    $readmemh("font.mem", font);
    $readmemh("screen.mem", screen);
end

endmodule