`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: STC
// Engineer: Evstigneev D.
// 
// Create Date: 09.03.2021 10:11:24
// Design Name: 
// Module Name: seq_conv_encoder
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

// Чтобы изменить code_rate надо после выставления подать сброс.
// Латентность 8.
module seq_conv_encoder #(
    parameter DEBUG = 0
)(
    input       clk,
    input       reset_n,
    input       i_diff_en,    // включение выключение diff кодера
    input [1:0] i_code_rate,  // 2'd0 - 1/2, 2'd1 - 3/4, 2'd2 - 7/8
    input       i_vld,
    input       i_data,
    
    output      o_vld,
    output[1:0] o_data 
);
    
    
//**********  Constants and parameters  **********//   
localparam[88:0] mask_1_2 = 89'hD354E3267;                      //89'o714461625313;
localparam[88:0] mask_3_4 = 89'h87AFC51E7688DDEE;               //89'o736750426717050772741;
localparam[88:0] mask_7_8 = 89'o77663166177600720153763372136;  // FIXME!

//**********  Declaration  **********//
wire [127:0] data_mask;
reg  [88 :0] data_r;
reg  [88 :0] ish_reg;
reg  [88 :0] mask = mask_1_2;
reg  [7  :0] vld_rsn;
reg          diff_reg;
reg          parity;
// каскадный xor. Первая цифра - номер каскада, вторая цифра - последний бит.
reg [63:0] xor_0;
reg [31:0] xor_1;
reg [15:0] xor_2;
reg [7 :0] xor_3;
reg [3 :0] xor_4;
reg [1 :0] xor_5;


// Code rate select
always@(posedge clk) begin
    if (!reset_n) begin
        case (i_code_rate)
            2'b00:   mask[88:0] <= mask_1_2[88:0];
            2'b01:   mask[88:0] <= mask_3_4[88:0];
            2'b10:   mask[88:0] <= mask_7_8[88:0];
            default: mask[88:0] <= mask_1_2[88:0];
        endcase
    end
end


always@(posedge clk) begin
    if(!reset_n) vld_rsn <= 0;
    else         vld_rsn[7:0] <= {vld_rsn[6:0], i_vld};
end

always@(posedge clk) begin
    if (!reset_n) begin
        diff_reg <= 0;
        data_r   <= 0;
        vld_rsn  <= 0;
        ish_reg  <= 0;
    end else if (i_vld) begin // end else begin ? FIXME
        ish_reg[88:0] <= {ish_reg[87:0], i_data};
        // Включение/выклчюение дифф декодера
        if (i_diff_en) begin
            diff_reg <= ish_reg[0] ^ i_data;
        end else begin
            diff_reg <= i_data;
        end             
    end else begin
        data_r[88:0] <= {data_r[87:0], diff_reg} & mask[88:0]; 
    end
end

// Расширение до 128 чтобы было удобно ксорить.
assign data_mask[127:0] = {{39{1'b0}}, data_r[88:0]};

genvar i;
// Cascade 0
generate
    for (i=0; i<64; i++) begin
        always@(posedge clk) begin
            if (!reset_n) xor_0    <= 0;
            else          xor_0[i] <= data_mask[2*i] ^ data_mask[2*i+1];
        end
    end
endgenerate
// Cascade 1
generate
    for (i=0; i<32; i++) begin
        always@(posedge clk) begin
            if (!reset_n) xor_1    <= 0;
            else          xor_1[i] <= xor_0[2*i] ^ xor_0[2*i+1];
        end
    end
endgenerate
// Cascade 2
generate
    for (i=0; i<16; i++) begin
        always@(posedge clk) begin
            if (!reset_n) xor_2    <= 0;
            else          xor_2[i] <= xor_1[2*i] ^ xor_1[2*i+1];
        end
    end
endgenerate
// Cascade 3
generate
    for (i=0; i<8; i++) begin
        always@(posedge clk) begin
            if (!reset_n) xor_3    <= 0; 
            else          xor_3[i] <= xor_2[2*i] ^ xor_2[2*i+1];
        end
    end
endgenerate
// Cascade 4
generate
    for (i=0; i<4; i++) begin
        always@(posedge clk) begin
            if (!reset_n) xor_4    <= 0;
            else          xor_4[i] <= xor_3[2*i] ^ xor_3[2*i+1];
        end
    end
endgenerate
// Cascade 5
generate
    for (i=0; i<2; i++) begin
        always@(posedge clk) begin
            if (!reset_n) xor_5    <= 0;
            else          xor_5[i] <= xor_4[2*i] ^ xor_4[2*i+1];
        end
    end
endgenerate
// Cascade 6
always@(posedge clk) begin
    if (!reset_n) parity <= 0;
    else          parity <= xor_5[0] ^ xor_5[1];
end

//Output assign
assign o_vld  = vld_rsn[7];
assign o_data = {data_r[0], parity};


endmodule
