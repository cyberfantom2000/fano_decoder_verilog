`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: STC
// Engineer: Evstigneev D.
// 
// Create Date: 12.04.2021 09:41:39
// Design Name: 
// Module Name: prs_gen
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module prs_gen(
    input  clk,
    input  reset_n,
    input  i_vld,
    output o_vld,
    output o_sym    
);

reg [15:0] sr = 16'h1; // 16'hFFFE;
wire[15:0] sr_sh;
reg        vld_sh;
reg        prs;


always@(posedge clk) begin
    if(!reset_n) vld_sh <= 0;        
    else         vld_sh <= i_vld;
end

always@(posedge clk) begin
    if(!reset_n)    sr <= 16'h1;
    else if(vld_sh) sr <= sr_sh | prs; 
end

always@(posedge clk) begin
    if(!reset_n)   prs <= 0;      
    else if(i_vld) prs <= sr[0] ^ sr[14];
end

assign sr_sh = sr << 1;


assign o_vld = vld_sh;
assign o_sym = prs;

endmodule
