`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: STC
// Engineer: Evstigneev D.
// 
// Create Date: 12.04.2021 12:31:04
// Design Name: 
// Module Name: conv_encoder
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments: Convolution encoder 1/2 for Fano's alg test.
// 
//////////////////////////////////////////////////////////////////////////////////


module conv_encoder(
    input        clk,
    input        reset_n,
    input        i_vld,
    input        i_sym,
    output       o_vld,
    output [1:0] o_word
);

localparam[63:0] parity_mask = 63'hD354E3267; // parity mask for 1/2 comthech

reg [6 :0] vld_rsn;
reg [35:0] sh_reg;
wire[63:0] sh_64;
reg [31:0] xor_0;
reg [15:0] xor_1;
reg [7 :0] xor_2;
reg [3 :0] xor_3;
reg [1 :0] xor_4;
reg        parity;


always@(posedge clk) begin
    if(!reset_n)   sh_reg[35:0] <= 0;
    else if(i_vld) sh_reg[35:0] <= {sh_reg[34:0], i_sym};
end

always@(posedge clk) begin
    if(!reset_n) vld_rsn[6:0] <= 0;
    else         vld_rsn[6:0] <= {vld_rsn[5:0], i_vld};
end

assign sh_64 = {28'b0, sh_reg[35:0]} & parity_mask;

genvar i;
generate
    // Cascade 0
    for (i=0; i<32; i++) begin
        always@(posedge clk) begin
            if (!reset_n) xor_0[i] <= 0;                
            else          xor_0[i] <= sh_64[2*i] ^ sh_64[2*i+1];
        end
    end
    // Cascade 1
    for (i=0; i<16; i++) begin
        always@(posedge clk) begin
            if (!reset_n) xor_1[i] <= 0;                
            else          xor_1[i] <= xor_0[2*i] ^ xor_0[2*i+1];
        end
    end
    // Cascade 2
    for (i=0; i<8; i++) begin
        always@(posedge clk) begin
            if (!reset_n) xor_2[i] <= 0;                
            else          xor_2[i] <= xor_1[2*i] ^ xor_1[2*i+1];
        end
    end
    // Cascade 3
    for (i=0; i<4; i++) begin
        always@(posedge clk) begin
            if (!reset_n) xor_3[i] <= 0;                
            else          xor_3[i] <= xor_2[2*i] ^ xor_2[2*i+1];
        end
    end
    // Cascade 4
    for (i=0; i<2; i++) begin
        always@(posedge clk) begin
            if (!reset_n) xor_4[i] <= 0;                
            else          xor_4[i] <= xor_3[2*i] ^ xor_3[2*i+1];
        end
    end
    // Cascade 5
    always@(posedge clk) begin
            if (!reset_n) parity <= 0;                
            else          parity <= xor_4[1] ^ xor_4[0];
        end
endgenerate

assign o_word[1:0] = {sh_reg[0], parity};
assign o_vld = vld_rsn[6];

endmodule
