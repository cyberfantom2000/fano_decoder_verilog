`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: STC
// Engineer: Evstigneev D.
// 
// Create Date: 10.03.2021 11:37:25
// Design Name: 
// Module Name: deperforator
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

// Пока что только для 1/2
module deperforator#(
    parameter D_WIDTH = 2,
    parameter DEBUG   = 0
)(
    input               clk,
    input               reset_n,
//    input [1        :0] i_code_rate,  // 2'd0 - 1/2, 2'd1 - 3/4, 2'd2 - 7/8
    input               i_sh_pointer,
    input               i_vld,
    input [D_WIDTH-1:0] i_data,
    output              o_vld,
    output[D_WIDTH-1:0] o_data
);
    
reg                sh_vld;
reg[D_WIDTH*2-1:0] sh_reg;
reg flag = 0;

always@(posedge clk) begin
    if     (!reset_n    ) flag <= 0;        
    else if(i_sh_pointer) flag <= ~flag;
end

always@(posedge clk) begin
    if (!reset_n) begin
        sh_reg <= 0;
        sh_vld <= 0;
    end else if(i_vld) begin
        sh_reg <= {sh_reg[D_WIDTH-1:0], i_data[D_WIDTH-1:0]};
    end
    
    sh_vld <= i_vld;
end

assign o_vld  = sh_vld;
assign o_data = flag ? sh_reg[D_WIDTH:1] : sh_reg[D_WIDTH-1:0]; 
 
endmodule
