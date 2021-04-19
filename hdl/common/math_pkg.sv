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

package math_pkg;

// Функция вычисляет размерность шины адреса из размера памяти.
function integer log2;
input integer value;
reg [31:0] shifted;
integer res;
    begin
        if (value == 1) begin
            log2 = value;
        end else begin
            shifted = value-1;
            for (res = 0; shifted > 0; res = res + 1) begin
                shifted = shifted >> 1;
            end
            log2 = res;
        end
    end
endfunction

endpackage