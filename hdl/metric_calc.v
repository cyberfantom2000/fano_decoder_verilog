`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: STC
// Engineer: Evstigneev D.
// 
// Create Date: 10.03.2021 15:16:53
// Design Name: 
// Module Name: metric_calc
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

// Пока что сделано в лоб для 1/2
module metric_calc(
    input       clk,
    input       reset_n,
    input       i_vld,
    input       i_code_rate,     // 2'd0 - 1/2, 2'd1 - 3/4, 2'd2 - 7/8
    input [1:0] i_rib_0,         // Ребро после кодера с символом 0
    input [1:0] i_rib_1,         // Ребро после кодера с символом 1
    input [1:0] i_cur_rib,       // Текущее(принятое) ребро относительно которого ищем путь
    input       A,               // Признак того что в прошлый раз была выбрана худшая метрика
    
    output              o_vld,
    output        [1:0] o_path,        // Выбранное ребро
    output signed [5:0] o_metric,      // Метрика выбранного ребра
    output              o_decode_sym   // Символ соответствующий выбранному ребру
);

//*********** Constants and parameters ***********//
localparam mask = 2'b11;


//*********** Declaration ***********//
wire             hamm_vld;
wire       [1:0] metric_0, metric_1;
reg              sh_vld;
reg              decode_sym;
reg        [1:0] path;
reg signed [5:0] mult_coe;
reg signed [5:0] metric;
reg        [1:0] rib_0r, rib_1r, cur_rib_r;
reg              vld_rsn;

//Pipe
always@(posedge clk) begin
    vld_rsn   <= i_vld;
    rib_0r    <= i_rib_0;
    rib_1r    <= i_rib_1;
    cur_rib_r <= i_cur_rib;
end


hamming_distance hamm0(
    .clk     (clk      ),
    .reset_n (reset_n  ),
    .i_vld   (vld_rsn  ),
    .i_mask  (mask     ),
    .i_a     (rib_0r   ),
    .i_b     (cur_rib_r),
    .o_vld   (),
    .o_metric(metric_0)
);

hamming_distance hamm1(
    .clk     (clk      ),
    .reset_n (reset_n  ),
    .i_vld   (vld_rsn  ),
    .i_mask  (mask     ),
    .i_a     (rib_1r   ),
    .i_b     (cur_rib_r),
    .o_vld   (hamm_vld ),
    .o_metric(metric_1 )
);

always@(posedge clk) begin
    if(!reset_n) begin
        case(i_code_rate)
            2'd0:    mult_coe <= $signed(-4 );
            2'b1:    mult_coe <= $signed(-30);
            default: mult_coe <= $signed(-4 );
        endcase
    end
end


always@(posedge clk) begin
    if (!reset_n) begin
        path       <= 0;
        decode_sym <= 0;
        metric     <= 0;
        sh_vld     <= 0;
    end else begin
        if (hamm_vld) begin
            if (metric_0 >= metric_1) begin
                path       <= A ? rib_0r : rib_1r;
                decode_sym <= A ? 1'b0 : 1'b1;
                if(metric_1 == 2'b0)                     
                    metric <= A ? $signed(metric_0) * $signed(mult_coe) : $signed(1);                   
                else
                    metric <= A ? $signed(metric_0) * $signed(mult_coe) : $signed(metric_1) * $signed(mult_coe);  
            end else begin                
                path       <= A ? rib_1r : rib_0r;
                decode_sym <= A ? 1'b1 : 1'b0;
                if(metric_0 == 2'b0)
                    metric <= A ? $signed(metric_1) * $signed(mult_coe) : $signed(1);
                else
                    metric <= A ? $signed(metric_1) * $signed(mult_coe) : $signed(metric_0) * $signed(mult_coe);
            end
        end
        sh_vld <= hamm_vld;
    end
end

assign o_path       = path;
assign o_metric     = metric;
assign o_decode_sym = decode_sym;
assign o_vld        = sh_vld;

endmodule
