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
// Синхронизатор уровня из домена одной частоты в домен другой частоты.
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module ff_sync (
    input i_clka,     // Тактовая частота домена A.
    input i_clkb,     // Тактовая частота домена B.
    
    input i_siga,     // Входной сигнал домена A.
    output o_sigb     // Выходной сигнал домена B.
);
 
// Регистр 1 домена A.
(*async_reg = "true"*) reg a1_reg = 0;
wire sig_mux1;
wire sig_mux2;

// Регистр 1 домена B.
(*async_reg = "true"*) reg b1_reg = 0;

// Регистр 2 домена B.
reg b2_reg = 0;

// Выходной регистр.
reg sigb_reg = 0;
wire sigb;

//------------------------------------------------------------------------------
// Регистр 1 домена A.
always @(posedge i_clka)
begin
    a1_reg <= i_siga;
end

//------------------------------------------------------------------------------
// Регистр 1 домена B.
always @(posedge i_clkb)
begin
    b1_reg <= a1_reg;
end

//------------------------------------------------------------------------------
// Регистр 2 домена B.
always @(posedge i_clkb)
begin
    b2_reg <= b1_reg;
end

assign o_sigb = b2_reg;

endmodule
