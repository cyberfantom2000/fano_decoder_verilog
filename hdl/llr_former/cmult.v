`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: STC
// Engineer: Sergeev_DA
// 
// Create Date: 18.01.2019 10:23:38
// Design Name: 
// Module Name: cmult
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

module cmult #(
    // Size of 1st input of multiplier
    parameter AWIDTH = 16,
    // Size of 2nd input of multiplier
    parameter BWIDTH = 18 )
(
    input i_clk,
    input i_ce,
    input signed [AWIDTH-1:0] i_are,
    input signed [AWIDTH-1:0] i_aim,
    input signed [BWIDTH-1:0] i_bre,
    input signed [BWIDTH-1:0] i_bim,
    output signed [AWIDTH+BWIDTH:0] o_pre,
    output signed [AWIDTH+BWIDTH:0] o_pim
);

reg signed [AWIDTH-1:0]	aim_d = 0;
reg signed [AWIDTH-1:0] aim_dd = 0;
reg signed [AWIDTH-1:0] aim_ddd = 0;
reg signed [AWIDTH-1:0] aim_dddd = 0;
reg signed [AWIDTH-1:0]	are_d = 0;
reg signed [AWIDTH-1:0] are_dd = 0;
reg signed [AWIDTH-1:0] are_ddd = 0;
reg signed [AWIDTH-1:0] are_dddd = 0;
reg signed [BWIDTH-1:0]	bim_d = 0;
reg signed [BWIDTH-1:0] bim_dd = 0;
reg signed [BWIDTH-1:0] bim_ddd = 0;
reg signed [BWIDTH-1:0] bre_d = 0;
reg signed [BWIDTH-1:0] bre_dd = 0;
reg signed [BWIDTH-1:0] bre_ddd = 0;
reg signed [AWIDTH:0] addcommon = 0;
reg signed [BWIDTH:0] addre = 0;
reg signed [BWIDTH:0] addim = 0;
reg signed [AWIDTH+BWIDTH:0] mult0 = 0;
reg signed [AWIDTH+BWIDTH:0] multre = 0;
reg signed [AWIDTH+BWIDTH:0] multim = 0;
reg signed [AWIDTH+BWIDTH:0] pre_int = 0;
reg signed [AWIDTH+BWIDTH:0] pim_int = 0;
reg signed [AWIDTH+BWIDTH:0] common = 0;
reg signed [AWIDTH+BWIDTH:0] commonr1 = 0;
reg signed [AWIDTH+BWIDTH:0] commonr2 = 0;

always @(posedge i_clk) begin
    if (i_ce) begin
        are_d <= i_are;
        are_dd <= are_d;
        aim_d <= i_aim;
        aim_dd <= aim_d;
        bre_d <= i_bre;
        bre_dd <= bre_d;
        bre_ddd <= bre_dd;
        bim_d <= i_bim;
        bim_dd <= bim_d;
        bim_ddd <= bim_dd;
    end
end

// Common factor (ar aim) x bim, shared for the calculations of the real and imaginary final products
always @(posedge i_clk) begin
    if (i_ce) begin
        addcommon <= are_d - aim_d;
        mult0 <= addcommon * bim_dd;
        common <= mult0;
    end
end

// Real product
always @(posedge i_clk) begin
    if (i_ce) begin
        are_ddd <= are_dd;
        are_dddd <= are_ddd;
        addre <= bre_ddd - bim_ddd;
        multre <= addre * are_dddd;
        commonr1 <= common;
        pre_int <= multre + commonr1;
    end
end

// Imaginary product
always @(posedge i_clk) begin
    if (i_ce) begin
        aim_ddd <= aim_dd;
        aim_dddd <= aim_ddd;
        addim <= bre_ddd + bim_ddd;
        multim <= addim * aim_dddd;
        commonr2 <= common;
        pim_int <= multim + commonr2;
    end
end

assign o_pre = pre_int;
assign o_pim = pim_int;

endmodule
