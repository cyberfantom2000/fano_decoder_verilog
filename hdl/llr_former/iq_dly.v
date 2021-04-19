`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: STC
// Engineer: Sergeev_DA
// 
// Create Date: 10.03.2018 11:01:24
// Design Name: 
// Module Name: iq_dly
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


module iq_dly #(
    // ����������� ��� ������ IQ.
    parameter DATA_WIDTH = 6 )
(
    input i_clk,                  // �������� �������.
    input i_reset,                // ������ ������.

    input [DATA_WIDTH-1:0] i_i,   // ������� ������ I.
    input [DATA_WIDTH-1:0] i_q,   // ������� ������ Q.
    input i_valid,                // ���������� ������� ������.
    
    input i_i_dly_enable,         // ���������� �������� I.
    input i_q_dly_enable,         // ���������� �������� Q.
    
    output [DATA_WIDTH-1:0] o_i,  // �������� ������ I.
    output [DATA_WIDTH-1:0] o_q,  // �������� ������ Q.
    output o_valid                // ���������� �������� ������.
);

// ��������� �������� �������� ���� I, Q.
reg [2*DATA_WIDTH-1:0] i_sreg = 0;
reg [2*DATA_WIDTH-1:0] q_sreg = 0;
wire iq_sreg_rst;
wire iq_sreg_ce;

// ������� ���������� ��� I, Q � ��������� ��������.
reg [1:0] pair_cnt = 0;
wire pair_cnt_rst;
wire pair_cnt_ce;
wire stop_pair_cnt;

// �������� �������������.
reg valid_reg = 0;
reg [DATA_WIDTH-1:0] i_reg = 0;
reg [DATA_WIDTH-1:0] q_reg = 0;
wire [DATA_WIDTH-1:0] i_mux;
wire [DATA_WIDTH-1:0] q_mux;
wire i_mux_s;
wire q_mux_s;
wire valid;
wire iq_no_dly;

//------------------------------------------------------------------------------
// ��������� �������� �������� ���� I, Q.
always @(posedge i_clk)
begin
    if (iq_sreg_rst) begin
        i_sreg[2*DATA_WIDTH-1:0] <= 0;
        q_sreg[2*DATA_WIDTH-1:0] <= 0;
    end else if (iq_sreg_ce) begin
        i_sreg[2*DATA_WIDTH-1:0] <= {i_sreg[DATA_WIDTH-1:0], i_i[DATA_WIDTH-1:0]};
        q_sreg[2*DATA_WIDTH-1:0] <= {q_sreg[DATA_WIDTH-1:0], i_q[DATA_WIDTH-1:0]};
    end
end

assign iq_sreg_rst = i_reset;
assign iq_sreg_ce = i_valid;

//------------------------------------------------------------------------------
// ������� ���������� �������� ��� I, Q � ��������� ��������.
always @(posedge i_clk)
begin
    if (pair_cnt_rst) begin
        pair_cnt[1:0] <= 0;
    end else if (pair_cnt_ce) begin
        pair_cnt[1:0] <= pair_cnt[1:0] + 1;
    end
end

assign pair_cnt_rst = i_reset;
assign pair_cnt_ce = i_valid & ~stop_pair_cnt;
assign stop_pair_cnt = (pair_cnt[1:0] == 2);

//------------------------------------------------------------------------------
// �������� �������������.
always @(posedge i_clk)
begin
    i_reg[DATA_WIDTH-1:0] <= i_mux[DATA_WIDTH-1:0];
    q_reg[DATA_WIDTH-1:0] <= q_mux[DATA_WIDTH-1:0];
    valid_reg <= valid;
end

assign i_mux[DATA_WIDTH-1:0] = (i_mux_s) ?
        i_sreg[2*DATA_WIDTH-1-:DATA_WIDTH] : i_sreg[DATA_WIDTH-1:0];
assign q_mux[DATA_WIDTH-1:0] = (q_mux_s) ?
        q_sreg[2*DATA_WIDTH-1-:DATA_WIDTH] : q_sreg[DATA_WIDTH-1:0];
assign i_mux_s = i_i_dly_enable | iq_no_dly;
assign q_mux_s = i_q_dly_enable | iq_no_dly;
assign iq_no_dly = ~i_i_dly_enable & ~i_q_dly_enable;
assign valid = i_valid & stop_pair_cnt;

assign o_i[DATA_WIDTH-1:0] = i_reg[DATA_WIDTH-1:0];
assign o_q[DATA_WIDTH-1:0] = q_reg[DATA_WIDTH-1:0];
assign o_valid = valid_reg;

endmodule
