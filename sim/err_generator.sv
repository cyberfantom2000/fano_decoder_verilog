`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: STC
// Engineer: Evstigneev D.
// 
// Create Date: 12.04.2021 14:43:00
// Design Name: 
// Module Name: err_generator
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments: Ошибки добавляются только в четных бита. Впадлу думать как это
//  сделать по человечески.
//////////////////////////////////////////////////////////////////////////////////


module err_generator(
    input                 clk,
    input                 reset_n,
    input                 i_enable,
    input unsigned [11:0] i_first_err, // Номер слова с первой ошибкой
    input unsigned [11:0] i_err_rate,  // Период появления ошибки (начинается после появления первой ошибки)
    input                 i_vld,
    input          [1 :0] i_word,
    output                o_vld,
    input          [1 :0] o_word
);

reg unsigned [11:0] cntr;
reg [1:0] word_rsn;
reg [1:0] word_out;
reg [1:0] vld_rsn;

always@(posedge clk) begin
    if(!reset_n) vld_rsn[1:0] <= 0;
    else         vld_rsn[1:0] <= {vld_rsn[0], i_vld};
end

always@(posedge clk) begin
    if(!reset_n || clear_cnt ) cntr <= 0;
    else if(i_vld && i_enable) cntr <= cntr + 1;
end

always@(posedge clk) begin
    if(!reset_n)   word_rsn <= 0;
    else if(i_vld) word_rsn <= i_word;
end

always@(posedge clk) begin
    if(!reset_n) begin
        word_out <= 0;
    end else if(err_en) begin
        word_out[0] <= ~word_rsn[0];
        word_out[1] <= word_rsn[1];
    end else if(vld_rsn[0]) begin
        word_out <= word_rsn;
    end
end


localparam START = 0;
localparam MAIN  = 1;
reg[1:0] state = START;
reg[1:0] nextstate;
reg      err_en;
reg      clear_cnt;
//---------   FSM    -----------//
always@(posedge clk) begin
    if(!reset_n) state <= START;
    else         state <= nextstate;
end

always@(*) begin
    nextstate = 'hX;
    err_en    = 0;
    clear_cnt = 0;
    
    case(state)
        START: begin
            nextstate = START;
            if(cntr == i_first_err) begin
                err_en    = 1;
                clear_cnt = 1;
                nextstate = MAIN;
            end
        end
        
        MAIN: begin
            nextstate = MAIN;   
            if(cntr == i_err_rate) begin
                err_en    = 1;
                clear_cnt = 1;
                nextstate = MAIN;
            end
        end
    endcase
end

assign o_vld = vld_rsn[1];
assign o_word = word_out;

endmodule
