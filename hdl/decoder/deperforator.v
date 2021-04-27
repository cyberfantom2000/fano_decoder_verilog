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
    input [1:0] i_code_rate,    // 0 - 1/2; 1 - 3/4, 2 - 7/8
    input       i_sh_pointer,
    input       i_vld,
    input       i_data,
    output      o_vld,
    output[1:0] o_data
);

wire       full, empty;
wire[10:0] data_count;
wire       dout;
reg        flag = 0;
reg        read_enable;
reg [1 :0] rden_sh;
reg        vld_out;
reg        fifo_sh[6:0];
reg [4:0]  max_cnt;
reg [4:0]  cnt;

always@(posedge clk) begin
    if     (!reset_n    ) flag <= 0;
    else if(i_sh_pointer) flag <= ~flag;
end

always@(posedge clk) begin
    case(i_code_rate)
        2'b00  : max_cnt <= 1;
        2'b01  : max_cnt <= 5;
        2'b10  : max_cnt <= 13;
        default: max_cnt <= 1;
    endcase
end


always@(posedge clk) begin
    case(i_llr_order)
        3'd1  : begin 
            if(read_enable & !rden_sh[0]) vld_out <= 1;
            else                          vld_out <= 0;
        end
        
        3'd2  : begin 
            if(rden_sh[0] & !rden_sh[1]) vld_out <= 1;
            else                         vld_out <= 0;
        end
        
        default: begin
            if(rden_sh[0] & !rden_sh[1]) vld_out <= 1;
            else                         vld_out <= 0;
        end
    endcase
end


always@(posedge clk) begin
    if     (!reset_n    ) cnt <= 0;
    else if(i_sh_pointer) cnt <= (cnt == max_cnt) ? 0 : cnt + 1;
end


fifo_hd fifo_hd_inst(
    .clk       (clk        ),
    .rst       (!reset_n   ),
    .wr_en     (i_vld      ),
    .din       (i_data     ),
    .full      (full       ),
    .rd_en     (read_enable),        
    .dout      (dout       ),        
    .empty     (empty      ),
    .data_count(data_count )
);

always@(posedge clk) begin
    if(!reset_n)
        read_enable <= 0;
    else if(data_count > 1 && !rden_sh[0])
        read_enable <= 1; 
    else
        read_enable <= 0;
end

always@(posedge clk) begin
    if(!reset_n) rden_sh[1:0] <= 0;
    else         rden_sh[1:0] <= {rden_sh[0], read_enable};
end



genvar i;
generate
    for(i=0; i<7; i=i+1) begin
        if(i==0) begin
            always@(posedge clk) begin
                if(!reset_n)         fifo_sh[i] <= 0;
                else if(read_enable) fifo_sh[i] <= dout;
            end
        end else begin
            always@(posedge clk) begin
                if(!reset_n)         fifo_sh[i] <= 0;
                else if(read_enable) fifo_sh[i] <= fifo_sh[i-1];
            end
        end
    end
endgenerate

assign o_vld  = vld_out;
assign o_data = {fifo_sh[cnt+1], fifo_sh[cnt]};


generate
    if (DEBUG) begin
        deperforator_ila deperforator_ila_inst(
        .clk   (clk),
        .probe0({reset_n,
                 rden,
                 out_vld,
                 i_vld,
                 read_enable                 
        }),
        .probe1({flag,
                 state      [2 :0],
                 rden_sh    [1 :0],
                 i_llr_order[2 :0],
                 sh_reg     [2 :0],
                 o_data     [1 :0],
                 data_count [10:0],
                 i_data,
                 dout,
                 full,
                 empty
                })
        );
    end
endgenerate

endmodule
