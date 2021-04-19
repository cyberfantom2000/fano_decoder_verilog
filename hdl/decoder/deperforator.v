`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: STC
// Engineer: Evstigneev D.
// 
// Create Date: 10.03.2021 11:37:25
// Design Name: 
// Module Name: deperforator
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

// Пока что только для 1/2
module deperforator#(
    parameter DEBUG   = 0
)(
    input       clk,
    input       reset_n,
    input [2:0] i_llr_order,
    input       i_sh_pointer,
    input       i_vld,
    input       i_data,
    output      o_vld,
    output[1:0] o_data
);
    
reg [1 :0] rden_sh;
reg        rden;
reg        flag = 0;
wire       full, empty;
wire       dout;
wire[10:0] data_count;
reg [3 :0] sh_reg;
reg        out_vld;
wire       read_enable = i_llr_order == 3'd2 ?  rden_sh[0] : rden_sh[1];

fifo_hd fifo_hd_inst(
    .clk       (clk       ),
    .rst       (!reset_n  ),
    .wr_en     (i_vld     ),
    .din       (i_data    ),
    .full      (full      ),
    .rd_en     (read_enable),        
    .dout      (dout      ),        
    .empty     (empty     ),
    .data_count(data_count)
);

always@(posedge clk) begin
    if     (!reset_n    ) flag <= 0;        
    else if(i_sh_pointer) flag <= ~flag;
end

always@(posedge clk) begin
    if(!reset_n        ) sh_reg[3:0] <= 0;
    else if(read_enable) sh_reg[3:0] <= {sh_reg[2:0], dout};  // FIXME. rden_sh[0]
end

always@(posedge clk) begin
    if(!reset_n) rden_sh[1:0] <= 0;
    else         rden_sh[1:0] <= {rden_sh[0], rden};
end


//---------   FSM    -----------//
reg[2:0] state, nextstate;

localparam IDLE    = 0;
localparam RD_FIFO = 1;
localparam WAIT    = 2;

always@(posedge clk) begin
    if(!reset_n) state <= IDLE;
    else         state <= nextstate;
end

always@(*) begin
    nextstate = 'hX;
    rden      = 0;
    out_vld   = 0;
    
    case(state)
        IDLE: begin
            nextstate = IDLE;
            if(data_count >= 2 && !i_vld) begin
                rden      = 1;
                nextstate = RD_FIFO;
            end
        end
        
        RD_FIFO: begin
            nextstate = RD_FIFO;
            rden      = 1;
            if(rden_sh[1]) begin
                rden      = 0;
                nextstate = WAIT;
            end
        end
        
        WAIT: begin
            nextstate = IDLE;
            out_vld   = 1;
        end
    endcase
end

assign o_vld  = out_vld;
assign o_data = flag ? sh_reg[2:1] : sh_reg[1:0]; 
 
endmodule
