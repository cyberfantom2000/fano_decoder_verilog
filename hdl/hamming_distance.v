`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10.03.2021 15:55:07
// Design Name: 
// Module Name: hamming_distance
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

// Реализовано отстойно. Приходит две последовательности по 2 бита и маска 2 бита.
// Если бит i = 1  маски то в выходной регистр в бит i записывается результат XOR,
// Иначе 0.
module hamming_distance(
    input       clk,
    input       reset_n,
    input       i_vld,
    input [1:0] i_mask,
    input [1:0] i_a,
    input [1:0] i_b,    
    output      o_vld,
    output[1:0] o_metric    
);
reg [1:0] result;
reg [1:0] bit_cnt;
reg [1:0] sh_vld;

genvar i;
generate
    for(i=0; i<2; i=i+1) begin  // FIXME: привязать к кодовой скорости
        always@(posedge clk) begin
            if  (!reset_n) result[i] <= 0;           
            else if(i_vld) result[i] <= (i_a[i] ^ i_b[i]) & i_mask[i];
        end
    end
endgenerate

always@(posedge clk) begin
    if(!reset_n) begin
        sh_vld  <= 0;
        bit_cnt <= 0;
    end else begin
        if(sh_vld[0]) bit_cnt <= result[1] + result[0];
        sh_vld  <= {sh_vld[0], i_vld};        
    end
end

assign o_vld = sh_vld[1];
assign o_metric = bit_cnt;

endmodule
