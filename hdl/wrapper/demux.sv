`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: STC
// Engineer: Sergeev_DA
// 
// Create Date: 19.11.2018 14:45:13
// Design Name: 
// Module Name: demux
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

import math_pkg::*;

module demux #(
    // Количество каналов мультиплексирования.
    parameter N_CHS = 4,
    // Размерность шины данных.
    parameter DATA_WIDTH = 32 )
(
    input i_clk, // Тактовая частота.

    input [log2(N_CHS)-1:0] i_mux_s,
    input [DATA_WIDTH-1:0] i_data,
    output [N_CHS*DATA_WIDTH-1:0] o_data
);
 
reg [N_CHS*DATA_WIDTH-1:0] data_reg = 0;

genvar i;
generate
    for (i = 0; i < N_CHS; i = i + 1) begin: data_regs
        always @(posedge i_clk) begin
            if (i_mux_s[log2(N_CHS)-1:0] == i) begin
                data_reg[(i+1)*DATA_WIDTH-1-:DATA_WIDTH] <= i_data[DATA_WIDTH-1:0];
            end else begin
                data_reg[(i+1)*DATA_WIDTH-1-:DATA_WIDTH] <= 0;
            end
        end
    end
endgenerate

assign o_data[N_CHS*DATA_WIDTH-1:0] = data_reg[N_CHS*DATA_WIDTH-1:0];

endmodule
