`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: STC
// Engineer: Sergeev_DA
// 
// Create Date: 19.10.2017 14:04:25
// Design Name: 
// Module Name: ff_sync
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// ������������� ������ �� ������ ����� ������� � ����� ������ �������.
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module ff_sync (
    input i_clka,     // �������� ������� ������ A.
    input i_clkb,     // �������� ������� ������ B.
    
    input i_siga,     // ������� ������ ������ A.
    output o_sigb     // �������� ������ ������ B.
);
 
// ������� 1 ������ A.
(*async_reg = "true"*) reg a1_reg = 0;
wire sig_mux1;
wire sig_mux2;

// ������� 1 ������ B.
(*async_reg = "true"*) reg b1_reg = 0;

// ������� 2 ������ B.
reg b2_reg = 0;

// �������� �������.
reg sigb_reg = 0;
wire sigb;

//------------------------------------------------------------------------------
// ������� 1 ������ A.
always @(posedge i_clka)
begin
    a1_reg <= i_siga;
end

//------------------------------------------------------------------------------
// ������� 1 ������ B.
always @(posedge i_clkb)
begin
    b1_reg <= a1_reg;
end

//------------------------------------------------------------------------------
// ������� 2 ������ B.
always @(posedge i_clkb)
begin
    b2_reg <= b1_reg;
end

assign o_sigb = b2_reg;

endmodule
