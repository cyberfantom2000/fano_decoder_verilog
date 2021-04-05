`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: STC
// Engineer: Evstigneev D.
// 
// Create Date: 09.03.2021 10:11:24
// Design Name: 
// Module Name: recover_encoder
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

// Чтобы переключить code_rate надо после выставления подать сброс.
// Латентность 8.
module recover_encoder #(
    parameter DEBUG = 0
)(
    input        clk,
    input        reset_n,
    input        i_diff_en,    // включение выключение diff кодера
    input [1 :0] i_code_rate,  // 2'd0 - 1/2, 2'd1 - 3/4, 2'd2 - 7/8
    input        i_vld,
    input [88:0] i_data,
    
    output       o_vld,
    output[1 :0] o_rib_0,
    output[1 :0] o_rib_1    
);
    
    
//**********  Constants and parameters  **********//   
localparam[88:0] mask_1_2 = 89'hD354E3267;                      //89'o714461625313;
localparam[88:0] mask_3_4 = 89'h87AFC51E7688DDEE;               //89'o736750426717050772741;
localparam[88:0] mask_7_8 = 89'o77663166177600720153763372136;  // FIXME!

//**********  Declaration  **********//
wire [127:0] data_mask0, data_mask1;
reg  [88 :0] data_r0, data_r1;
reg  [88 :0] mask = mask_1_2;
reg  [7  :0] vld_rsn;
reg          diff_reg0, diff_reg1;
reg          parity_0, parity_1;
// каскадный xor. Первая цифра - номер каскада, вторая цифра - последний бит.
reg [63 :0] xor_0_0;
reg [63 :0] xor_0_1;
reg [31 :0] xor_1_0;
reg [31 :0] xor_1_1;
reg [15 :0] xor_2_0;
reg [15 :0] xor_2_1;
reg [7  :0] xor_3_0;
reg [7  :0] xor_3_1;
reg [3  :0] xor_4_0;
reg [3  :0] xor_4_1;
reg [1  :0] xor_5_0;
reg [1  :0] xor_5_1;


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
        diff_reg0  <= 0;
        diff_reg1  <= 1;
        data_r0    <= 0;
        data_r1    <= 0;
        vld_rsn    <= 0;   
    end else if (i_vld) begin // end else begin ? FIXME
        // Включение/выклчюение дифф декодера
        if (i_diff_en) begin
            diff_reg0  <= 1'b0 ^ i_data[0];
            diff_reg1  <= 1'b1 ^ i_data[0];
        end else begin
            diff_reg0  <= 1'b0;
            diff_reg1  <= 1'b1;
        end             
    end else begin
        data_r0[87:0] <= {i_data[87:0], diff_reg0} & mask[88:0]; 
        data_r1[87:0] <= {i_data[87:0], diff_reg1} & mask[88:0];
    end
end

// Расширение до 128 чтобы было удобно ксорить.
assign data_mask0 = {{39{1'b0}}, data_r0[88:0]};
assign data_mask1 = {{39{1'b0}}, data_r1[88:0]};

genvar i;
// Cascade 0
generate
    for (i=0; i<64; i++) begin
        always@(posedge clk) begin
            if (!reset_n) begin
                xor_0_0 <= 0;
                xor_0_1 <= 0;
            end else begin
                xor_0_0[i] <= data_mask0[2*i] ^ data_mask0[2*i+1];
                xor_0_1[i] <= data_mask1[2*i] ^ data_mask1[2*i+1];
            end
        end
    end
endgenerate
// Cascade 1
generate
    for (i=0; i<32; i++) begin
        always@(posedge clk) begin
            if (!reset_n) begin
                xor_1_0 <= 0;
                xor_1_1 <= 0;
            end else begin
                xor_1_0[i] <= xor_0_0[2*i] ^ xor_0_0[2*i+1];
                xor_1_1[i] <= xor_0_1[2*i] ^ xor_0_1[2*i+1];
            end
        end
    end
endgenerate
// Cascade 2
generate
    for (i=0; i<16; i++) begin
        always@(posedge clk) begin
            if (!reset_n) begin
                xor_2_0 <= 0;
                xor_2_1 <= 0;
            end else begin
                xor_2_0[i] <= xor_1_0[2*i] ^ xor_1_0[2*i+1];
                xor_2_1[i] <= xor_1_1[2*i] ^ xor_1_1[2*i+1];
            end
        end
    end
endgenerate
// Cascade 3
generate
    for (i=0; i<8; i++) begin
        always@(posedge clk) begin
            if (!reset_n) begin
                xor_3_0 <= 0;
                xor_3_1 <= 0;
            end else begin        
                xor_3_0[i] <= xor_2_0[2*i] ^ xor_2_0[2*i+1];
                xor_3_1[i] <= xor_2_1[2*i] ^ xor_2_1[2*i+1];
            end
        end
    end
endgenerate
// Cascade 4
generate
    for (i=0; i<4; i++) begin
        always@(posedge clk) begin
            if (!reset_n) begin
                xor_4_0 <= 0;
                xor_4_1 <= 0;
            end else begin
                xor_4_0[i] <= xor_3_0[2*i] ^ xor_3_0[2*i+1];
                xor_4_1[i] <= xor_3_1[2*i] ^ xor_3_1[2*i+1];
            end
        end
    end
endgenerate
// Cascade 5
generate
    for (i=0; i<2; i++) begin
        always@(posedge clk) begin
            if (!reset_n) begin
                xor_5_0 <= 0;
                xor_5_1 <= 0;
            end else begin
                xor_5_0[i] <= xor_4_0[2*i] ^ xor_4_0[2*i+1];
                xor_5_1[i] <= xor_4_1[2*i] ^ xor_4_1[2*i+1];
            end
        end
    end
endgenerate
// Cascade 6
always@(posedge clk) begin
    if (!reset_n) begin
        parity_0 <= 0;
        parity_1 <= 0;
    end else begin
        parity_0 <= xor_5_0[0] ^ xor_5_0[1];
        parity_1 <= xor_5_1[0] ^ xor_5_1[1];
    end
end


//Output assign
assign o_vld   = vld_rsn[7];
assign o_rib_0 = {1'b0, parity_0};
assign o_rib_1 = {1'b1, parity_1};

endmodule
