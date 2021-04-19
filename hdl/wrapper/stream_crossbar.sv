`timescale 1 ns / 1 ps

import math_pkg::*;

module stream_crossbar #(
    // Ширина шины данных.
    parameter DATA_WIDTH = 32,
    // Количество каналов.
    parameter N_CHS = 8 )
(
    input i_clk,
    
    input [DATA_WIDTH-1:0] i_data,
    input i_valid,
    
    input [log2(N_CHS)-1:0] i_dev_sel,

    output [DATA_WIDTH*N_CHS-1:0] o_data,
    output [N_CHS-1:0] o_valid
);

wire [(DATA_WIDTH+1)*N_CHS-1:0] demux;

demux #(
    .N_CHS(N_CHS),
    .DATA_WIDTH(DATA_WIDTH+1)
) demux_dev_inst (
    .i_clk(i_clk),
    .i_mux_s(i_dev_sel[log2(N_CHS)-1:0]),
    .i_data({i_data[DATA_WIDTH-1:0], i_valid}),
    .o_data(demux[(DATA_WIDTH+1)*N_CHS-1:0])
);

genvar ch_idx;
generate
    for (ch_idx = 0; ch_idx < N_CHS; ch_idx = ch_idx + 1) begin 
        assign o_data[DATA_WIDTH*(ch_idx+1)-1-:DATA_WIDTH] = demux[(DATA_WIDTH+1)*(ch_idx+1)-1-:DATA_WIDTH];
        assign o_valid[ch_idx] = demux[(DATA_WIDTH+1)*ch_idx];
    end
endgenerate

endmodule
