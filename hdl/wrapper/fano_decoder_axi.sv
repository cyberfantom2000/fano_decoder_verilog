`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: STC
// Engineer: Evstigneev D.
// 
// Create Date: 15.04.2021 09:21:33
// Design Name: 
// Module Name: fano_decoder_axi
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
import math_pkg::*;

module fano_decoder_axi #(
    // Количество каналов.
    parameter integer N_CHS = 8,
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 32,
    // Общее количество регистров в канале.
    parameter integer N_REGS = 12,
    // Количество регистров только записи.
    parameter integer N_WR_REGS = 10,
    // Количество регистров только чтения.
    parameter integer N_RD_REGS = 2,
    // Отладка.
    parameter integer DEBUG = 0 )
(
    output [N_CHS-1      :0] o_reset,
    output [N_CHS-1      :0] o_ctrl_reset,
    output [N_CHS-1      :0] o_diff_en,
    output [2*N_CHS-1    :0] o_offset_mod_en,
    output [3*N_CHS-1    :0] o_llr_order,
    output [3*N_CHS-1    :0] o_angle_step,    
    output [2*N_CHS-1    :0] o_code_rate,
    output [24*N_CHS-1   :0] o_sync_period,
    output [24*N_CHS-1   :0] o_sync_threshold,
    output [8*N_CHS-1    :0] o_delta_T,
    output [16*N_CHS-1   :0] o_forward_step,
    output [log2(N_CHS)-1:0] o_stream_ch_sel,
    input  [N_CHS-1      :0] i_sync,
	
    // AXI-Lite
    input                               s_axi_aclk,
    input                               s_axi_aresetn,
    input  [C_S_AXI_ADDR_WIDTH-1    :0] s_axi_awaddr,
    input  [2                       :0] s_axi_awprot,
    input                               s_axi_awvalid,
    output                              s_axi_awready, 
    input  [C_S_AXI_DATA_WIDTH-1    :0] s_axi_wdata,
    input  [(C_S_AXI_DATA_WIDTH/8)-1:0] s_axi_wstrb,
    input                               s_axi_wvalid,
    output                              s_axi_wready,
    output [1                       :0] s_axi_bresp,
    output                              s_axi_bvalid,
    input                               s_axi_bready,
    input  [C_S_AXI_ADDR_WIDTH-1    :0] s_axi_araddr,
    input  [2                       :0] s_axi_arprot,
    input                               s_axi_arvalid,
    output                              s_axi_arready,
    output [C_S_AXI_DATA_WIDTH-1    :0] s_axi_rdata,
    output [1                       :0] s_axi_rresp,
    output                              s_axi_rvalid,
    input                               s_axi_rready
);

// AXI4LITE signals
reg [C_S_AXI_ADDR_WIDTH-1:0] axi_awaddr;
reg axi_awready;
reg axi_wready;
reg [1:0] axi_bresp;
reg axi_bvalid;
reg [C_S_AXI_ADDR_WIDTH-1:0] axi_araddr;
reg axi_arready;
reg [C_S_AXI_DATA_WIDTH-1:0] axi_rdata;
reg [1:0] axi_rresp;
reg axi_rvalid;

localparam integer ADDR_LSB          = (C_S_AXI_DATA_WIDTH/32) + 1;
localparam integer OPT_MEM_ADDR_BITS = 4;
localparam integer ADDR_CHS_MUX      = 4;
localparam integer N_BYTES           = (C_S_AXI_DATA_WIDTH/8);

(* dont_touch = "true" *) reg [C_S_AXI_DATA_WIDTH-1:0] slv_regs [0:N_CHS*N_REGS-1];
wire slv_reg_rst;
(* dont_touch = "true" *) reg [0:N_CHS*N_WR_REGS-1] slv_reg_wr_en_reg = 0;
wire [0:N_CHS*N_WR_REGS-1] slv_reg_wr_en;
wire [0:N_CHS*N_REGS-1] slv_reg_rd_en;
reg [15:0] reset_sreg [0:N_CHS-1];
wire [N_CHS-1:0] reset;
wire slv_reg_rden;
wire slv_reg_wren;
reg [C_S_AXI_DATA_WIDTH-1:0] reg_data_out;
integer byte_idx;
reg	aw_en;

// I/O Connections assignments
assign s_axi_awready = axi_awready;
assign s_axi_wready	 = axi_wready;
assign s_axi_bresp   = axi_bresp;
assign s_axi_bvalid  = axi_bvalid;
assign s_axi_arready = axi_arready;
assign s_axi_rdata   = axi_rdata;
assign s_axi_rresp   = axi_rresp;
assign s_axi_rvalid	 = axi_rvalid;

// Implement axi_awready generation
// axi_awready is asserted for one s_axi_aclk clock cycle when both
// s_axi_awvalid and s_axi_wvalid are asserted. axi_awready is
// de-asserted when reset is low.
always @(posedge s_axi_aclk) begin
    if (s_axi_aresetn == 1'b0) begin
        axi_awready <= 1'b0;
        aw_en <= 1'b1;
    end else begin    
        if (~axi_awready && s_axi_awvalid && s_axi_wvalid && aw_en) begin
            // slave is ready to accept write address when 
            // there is a valid write address and write data
            // on the write address and data bus. This design 
            // expects no outstanding transactions. 
            axi_awready <= 1'b1;
            aw_en <= 1'b0;
        end else if (s_axi_bready && axi_bvalid) begin
            aw_en <= 1'b1;
            axi_awready <= 1'b0;
        end else begin
            axi_awready <= 1'b0;
        end
    end 
end       

// Implement axi_awaddr latching
// This process is used to latch the address when both 
// s_axi_awvalid and s_axi_wvalid are valid.
always @(posedge s_axi_aclk) begin
    if (s_axi_aresetn == 1'b0) begin
        axi_awaddr <= 0;
    end else begin    
        if (~axi_awready && s_axi_awvalid && s_axi_wvalid && aw_en) begin
            // Write Address latching 
            axi_awaddr <= s_axi_awaddr;
        end
    end 
end       

// Implement axi_wready generation
// axi_wready is asserted for one s_axi_aclk clock cycle when both
// s_axi_awvalid and s_axi_wvalid are asserted. axi_wready is 
// de-asserted when reset is low. 
always @(posedge s_axi_aclk) begin
    if (s_axi_aresetn == 1'b0) begin
        axi_wready <= 1'b0;
    end else begin    
        if (~axi_wready && s_axi_wvalid && s_axi_awvalid && aw_en ) begin
            // slave is ready to accept write data when 
            // there is a valid write address and write data
            // on the write address and data bus. This design 
            // expects no outstanding transactions. 
            axi_wready <= 1'b1;
        end else begin
            axi_wready <= 1'b0;
        end
    end 
end       

// Implement memory mapped register select and write logic generation
// The write data is accepted and written to memory mapped registers when
// axi_awready, s_axi_wvalid, axi_wready and s_axi_wvalid are asserted. Write strobes are used to
// select byte enables of slave registers while writing.
// These registers are cleared when reset (active low) is applied.
// Slave register write enable is asserted when valid address and data are available
// and the slave is ready to accept the write address and write data.
assign slv_reg_wren = axi_wready && s_axi_wvalid && axi_awready && s_axi_awvalid;

// Implement write response logic generation
// The write response and response valid signals are asserted by the slave 
// when axi_wready, s_axi_wvalid, axi_wready and s_axi_wvalid are asserted.  
// This marks the acceptance of address and indicates the status of 
// write transaction.
always @(posedge s_axi_aclk) begin
    if (s_axi_aresetn == 1'b0) begin
        axi_bvalid <= 0;
        axi_bresp <= 2'b0;
    end else begin    
        if (axi_awready && s_axi_awvalid && ~axi_bvalid && axi_wready && s_axi_wvalid) begin
            // indicates a valid write response is available
            axi_bvalid <= 1'b1;
            axi_bresp  <= 2'b0; // 'OKAY' response 
                                // work error responses in future
        end else begin
            if (s_axi_bready && axi_bvalid) begin
                //check if bready is asserted while bvalid is high) 
                //(there is a possibility that bready is always asserted high)   
                axi_bvalid <= 1'b0; 
            end  
        end
    end
end   

// Implement axi_arready generation
// axi_arready is asserted for one S_AXI_ACLK clock cycle when
// S_AXI_ARVALID is asserted. axi_awready is 
// de-asserted when reset (active low) is asserted. 
// The read address is also latched when S_AXI_ARVALID is 
// asserted. axi_araddr is reset to zero on reset assertion.
always @(posedge s_axi_aclk) begin
    if (s_axi_aresetn == 1'b0) begin
        axi_arready <= 1'b0;
        axi_araddr  <= 32'b0;
    end else begin    
        if (~axi_arready && s_axi_arvalid) begin
            // indicates that the slave has acceped the valid read address
            axi_arready <= 1'b1;
            // Read address latching
            axi_araddr  <= s_axi_araddr;
        end else begin
            axi_arready <= 1'b0;
        end
    end 
end       

// Implement axi_arvalid generation
// axi_rvalid is asserted for one s_axi_aclk clock cycle when both 
// s_axi_arvalid and axi_arready are asserted. The slave registers 
// data are available on the axi_rdata bus at this instance. The 
// assertion of axi_rvalid marks the validity of read data on the 
// bus and axi_rresp indicates the status of read transaction.axi_rvalid 
// is deasserted on reset (active low). axi_rresp and axi_rdata are 
// cleared to zero on reset (active low).   
always @(posedge s_axi_aclk) begin
    if (s_axi_aresetn == 1'b0) begin
        axi_rvalid <= 0;
        axi_rresp  <= 0;
    end else begin    
        if (axi_arready && s_axi_arvalid && ~axi_rvalid) begin
            // Valid read data is available at the read data bus
            axi_rvalid <= 1'b1;
            axi_rresp  <= 2'b0; // 'OKAY' response
        end else if (axi_rvalid && s_axi_rready) begin
            // Read data is accepted by the master
            axi_rvalid <= 1'b0;
        end                
    end
end

// Implement memory mapped register select and read logic generation
// Slave register read enable is asserted when valid address is available
// and the slave is ready to accept the read address.
assign slv_reg_rden = axi_arready & s_axi_arvalid & ~axi_rvalid;

genvar ch_idx;
genvar wr_reg_idx;
genvar reg_idx;
//------------------------------------------------------------------------------
// Запись регистров.
generate
    for (ch_idx = 0; ch_idx < N_CHS; ch_idx = ch_idx + 1) begin : wr_chs
        for (wr_reg_idx = 0; wr_reg_idx < N_WR_REGS; wr_reg_idx = wr_reg_idx + 1) begin : wr_regs
            always @(posedge s_axi_aclk) begin
                if (slv_reg_rst) begin
                    slv_regs[ch_idx*N_REGS+wr_reg_idx][C_S_AXI_DATA_WIDTH-1:0] <= 0;     
                end else if (slv_reg_wr_en[ch_idx*N_WR_REGS+wr_reg_idx]) begin
                    for (byte_idx = 0; byte_idx < N_BYTES; byte_idx = byte_idx + 1) begin
                        if (s_axi_wstrb[byte_idx] == 1) begin 
                            slv_regs[ch_idx*N_REGS+wr_reg_idx][(byte_idx*8)+:8] <= s_axi_wdata[(byte_idx*8)+:8];
                        end
                    end
                end
            end
        
            assign slv_reg_wr_en[ch_idx*N_WR_REGS+wr_reg_idx] =
                    slv_reg_wren & (axi_awaddr[C_S_AXI_ADDR_WIDTH-1-:ADDR_CHS_MUX] == ch_idx) &
                    (axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS-1-:OPT_MEM_ADDR_BITS] == wr_reg_idx);
        end
    end
    
    assign slv_reg_rst = ~s_axi_aresetn;
endgenerate

always @(posedge s_axi_aclk) begin
    slv_reg_wr_en_reg[0:N_CHS*N_WR_REGS-1] <= slv_reg_wr_en[0:N_CHS*N_WR_REGS-1];
end

//------------------------------------------------------------------------------
// Чтение регистров.
generate
    for (ch_idx = 0; ch_idx < N_CHS; ch_idx = ch_idx + 1) begin : rd_chs
        for (reg_idx = 0; reg_idx < N_REGS; reg_idx = reg_idx + 1) begin : rd_regs
            assign slv_reg_rd_en[ch_idx*N_REGS+reg_idx] =
                    (axi_araddr[C_S_AXI_ADDR_WIDTH-1-:ADDR_CHS_MUX] == ch_idx) &
                    (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS-1:ADDR_LSB] == reg_idx);
        end
    end
endgenerate

integer i;
always @* begin
    reg_data_out[C_S_AXI_DATA_WIDTH-1:0] = 0;
    for (i = 0; i < N_CHS*N_REGS; i = i + 1) begin
        if (slv_reg_rd_en[i]) begin
            reg_data_out[C_S_AXI_DATA_WIDTH-1:0] = slv_regs[i];
        end
    end
end

//------------------------------------------------------------------------------
// Формирование сброса.
generate
    for (ch_idx = 0; ch_idx < N_CHS; ch_idx = ch_idx + 1) begin : reset_chs
        always @(posedge s_axi_aclk) begin
            if (reset[ch_idx]) begin
                reset_sreg[ch_idx][15:0] <= 16'hFFFF;
            end else begin
                reset_sreg[ch_idx][15:0] <= (reset_sreg[ch_idx][15:0] << 1);
            end
        end
        
        assign reset[ch_idx] = slv_reg_wr_en[ch_idx*N_WR_REGS];
    end
endgenerate

//------------------------------------------------------------------------------        
// Вход.
generate
    for (ch_idx = 0; ch_idx < N_CHS; ch_idx = ch_idx + 1) begin : in
        always @(posedge s_axi_aclk) begin            
            slv_regs[ch_idx*N_REGS+10][31:0] <= {{30{1'b0}}, i_sync[ch_idx]};
            slv_regs[ch_idx*N_REGS+11][31:0] <= N_CHS;
        end
    end
endgenerate

//------------------------------------------------------------------------------        
// Выход.

generate 
    for (ch_idx = 0; ch_idx < N_CHS; ch_idx = ch_idx + 1) begin : out
        assign o_reset         [ch_idx             ] = reset_sreg       [ch_idx][15];           
        assign o_ctrl_reset    [ch_idx             ] = slv_reg_wr_en_reg[ch_idx*N_WR_REGS+2];
        assign o_diff_en       [ch_idx             ] = slv_regs         [ch_idx*N_REGS+3][0];
        assign o_offset_mod_en [2*(ch_idx+1)-1-:  2] = slv_regs         [ch_idx*N_REGS+4][1 :0];
        assign o_llr_order     [3*(ch_idx+1)-1-:  3] = slv_regs         [ch_idx*N_REGS+4][6 :4];        
        assign o_angle_step    [3*(ch_idx+1)-1-:  3] = slv_regs         [ch_idx*N_REGS+4][10:8];        
        assign o_code_rate     [2*(ch_idx+1)-1-:  2] = slv_regs         [ch_idx*N_REGS+5][1 :0];        
        assign o_sync_period   [24*(ch_idx+1)-1-:24] = slv_regs         [ch_idx*N_REGS+6][23:0];
        assign o_sync_threshold[24*(ch_idx+1)-1-:24] = slv_regs         [ch_idx*N_REGS+7][23:0];        
        assign o_delta_T       [8*(ch_idx+1)-1-:  8] = slv_regs         [ch_idx*N_REGS+8][7 :0];
        assign o_forward_step  [16*(ch_idx+1)-1-:16] = slv_regs         [ch_idx*N_REGS+9][15:0];
    end
    
    assign o_stream_ch_sel[log2(N_CHS)-1:0] = slv_regs[1][log2(N_CHS)-1:0];
    
endgenerate

// Output register or memory read data
always @(posedge s_axi_aclk) begin
    if (s_axi_aresetn == 1'b0) begin
        axi_rdata <= 0;
    end else begin    
        // When there is a valid read address (s_axi_arvalid) with 
        // acceptance of read address by the slave (axi_arready), 
        // output the read dada 
        if (slv_reg_rden) begin
            axi_rdata <= reg_data_out;     // register read data
        end   
    end
end

generate
    if (DEBUG) begin
        params_ila params_ila_inst(
        .clk   (s_axi_aclk),
        .probe0({o_reset         [0   ],
                 o_ctrl_reset    [0   ],
                 o_diff_en       [0   ],
                 o_llr_order     [2 :0],
                 o_angle_step    [2 :0], 
                 o_code_rate     [1 :0],
                 o_sync_period   [23:0],
                 o_sync_threshold[15:0],
                 o_delta_T       [7 :0],
                 o_forward_step  [15:0]
                })
        );
    end
endgenerate

endmodule
