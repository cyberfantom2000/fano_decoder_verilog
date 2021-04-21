`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: STC
// Engineer: Evstigneev D.
// 
// Create Date: 15.04.2021 09:27:05
// Design Name: 
// Module Name: sequence_decoder
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

module sequence_decoder#(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 32,
    parameter integer N_CHS              = 1,              // Количество каналов. Максимально допустимое значение - 16.
    parameter         SYNC_PERIOD_WIDTH  = 24,
    parameter         MAX_SH_W           = 180,
    parameter         IQ_WIDTH           = 10,
    parameter         DEBUG              = 1
)(
    input                clk,
    input [N_CHS-1   :0] i_vld,
    input [10*N_CHS-1:0] i_data_I,
    input [10*N_CHS-1:0] i_data_Q,
    output[N_CHS-1   :0] o_vld,
    output[N_CHS-1   :0] o_dec_sym,
    // ctrl stream
    input        i_ctrl_clk,
    input        i_ctrl_vld,
    input [23:0] i_ctrl_data,    
    // AXI-Lite
    input                              s_axi_aclk,
    input                              s_axi_aresetn,
    input [C_S_AXI_ADDR_WIDTH-1    :0] s_axi_awaddr,
    input [2                       :0] s_axi_awprot,
    input                              s_axi_awvalid,
    output                             s_axi_awready, 
    input [C_S_AXI_DATA_WIDTH-1    :0] s_axi_wdata,
    input [(C_S_AXI_DATA_WIDTH/8)-1:0] s_axi_wstrb,
    input                              s_axi_wvalid,
    output                             s_axi_wready,
    output[1                       :0] s_axi_bresp,
    output                             s_axi_bvalid,
    input                              s_axi_bready,
    input [C_S_AXI_ADDR_WIDTH-1    :0] s_axi_araddr,
    input [2                       :0] s_axi_arprot,
    input                              s_axi_arvalid,
    output                             s_axi_arready,
    output[C_S_AXI_DATA_WIDTH-1    :0] s_axi_rdata,
    output[1                       :0] s_axi_rresp,
    output                             s_axi_rvalid,
    input                              s_axi_rready
);

wire [N_CHS-1      :0] reset;
wire [N_CHS-1      :0] ctrl_reset;
wire [N_CHS-1      :0] diff_en;
wire [2*N_CHS-1    :0] code_rate;
wire [3*N_CHS-1    :0] llr_order;
wire [3*N_CHS-1    :0] angle_step;
wire [24*N_CHS-1   :0] sync_period;
wire [24*N_CHS-1   :0] sync_threshold;
wire [8*N_CHS-1    :0] delta_T;
wire [16*N_CHS-1   :0] forward_step;
wire [N_CHS-1      :0] sync;
wire [log2(N_CHS)-1:0] ctrl_ch_sel;
wire [24*N_CHS-1   :0] ctrl_data;
wire [N_CHS-1      :0] ctrl_vld;
wire [2*N_CHS-1    :0] offset_mod_en;

genvar ch_idx;
generate
    for(ch_idx = 0; ch_idx < N_CHS; ch_idx ++) begin: ch
        fano_decoder#(
            .SYNC_PERIOD_WIDTH(SYNC_PERIOD_WIDTH),
            .MAX_SH_W         (MAX_SH_W         ),
            .IQ_WIDTH         (IQ_WIDTH         ),
            .DEBUG            (DEBUG            )            
        )fano_decoder_inst(
            .clk             (clk                                ),
            .reset_n         (~reset        [ch_idx             ]),
            .i_diff_en       (diff_en       [ch_idx             ]),
            .i_llr_offset_mod(offset_mod_en [2*(ch_idx+1)-1-:  2]),
            .i_angle_step    (llr_order     [3*(ch_idx+1)-1-:  3]),
            .i_llr_order     (llr_order     [3*(ch_idx+1)-1-:  3]),
            .i_code_rate     (code_rate     [2*(ch_idx+1)-1-:  2]),
            .i_sync_period   (sync_period   [24*(ch_idx+1)-1-:24]),
            .i_sync_threshold(sync_threshold[24*(ch_idx+1)-1-:24]),
            .i_vld           (i_vld         [ch_idx             ]),
            .i_data_I        (i_data_I      [10*(ch_idx+1)-1-:10]),
            .i_data_Q        (i_data_Q      [10*(ch_idx+1)-1-:10]),
            .i_delta_T       (delta_T       [8*(ch_idx+1)-1-:  8]),
            .i_forward_step  (forward_step  [16*(ch_idx+1)-1-:16]),
            .o_vld           (o_vld         [ch_idx             ]),
            .o_dec_sym       (o_dec_sym     [ch_idx             ]),
            .o_is_sync       (sync          [ch_idx             ]),
            // ctrl channel stream
            .i_ctrl_rst (ctrl_reset[ch_idx            ]),
            .i_ctrl_clk (i_ctrl_clk                    ),
            .i_ctrl_vld (ctrl_vld [ch_idx             ]),
            .i_ctrl_data(ctrl_data[24*(ch_idx+1)-1-:24])
        );
    end
endgenerate


stream_crossbar#(
    .DATA_WIDTH(24   ),
    .N_CHS     (N_CHS)
)stream_crossbar_inst(
    .i_clk    (i_ctrl_clk                  ),
    .i_valid  (i_ctrl_vld                  ),
    .i_data   (i_ctrl_data[23           :0]),
    .i_dev_sel(ctrl_ch_sel[log2(N_CHS)-1:0]),
    .o_valid  (ctrl_vld   [N_CHS-1      :0]),
    .o_data   (ctrl_data  [24*N_CHS-1   :0])
);


/****************************************************************/
/*                      axi_clock_converter                     */
/****************************************************************/
wire 			                  s_axi_aclk_cc;
wire 			                  s_axi_aresetn_cc;
wire [C_S_AXI_ADDR_WIDTH-1   : 0] s_axi_awaddr_cc;
wire [2                      : 0] s_axi_awprot_cc;
wire 	                     	  s_axi_awvalid_cc;
wire 	                     	  s_axi_awready_cc;
wire [C_S_AXI_DATA_WIDTH-1   : 0] s_axi_wdata_cc;
wire [(C_S_AXI_DATA_WIDTH/8)-1:0] s_axi_wstrb_cc;
wire 			                  s_axi_wvalid_cc;
wire 			                  s_axi_wready_cc;
wire [1                      : 0] s_axi_bresp_cc;
wire 			                  s_axi_bvalid_cc;
wire 			                  s_axi_bready_cc;
wire [C_S_AXI_ADDR_WIDTH-1    :0] s_axi_araddr_cc;
wire [2                      : 0] s_axi_arprot_cc;
wire 	                     	  s_axi_arvalid_cc;
wire 	                     	  s_axi_arready_cc;
wire [C_S_AXI_DATA_WIDTH-1   :0]  s_axi_rdata_cc;
wire [1                     : 0]  s_axi_rresp_cc;
wire 	                    	  s_axi_rvalid_cc;
wire 	                    	  s_axi_rready_cc;

ff_sync ff_sync_s_axi_aresetn_inst (
  .i_clka(s_axi_aclk      ),    // input wire i_clka
  .i_clkb(clk             ),    // input wire i_clkb
  .i_siga(s_axi_aresetn   ),  	// input wire [0 : 0] i_strobe
  .o_sigb(s_axi_aresetn_cc)  	// output wire [0 : 0] o_strobe
);

assign s_axi_aclk_cc = clk;

axi_clock_converter_fano axi_clock_converter_fano_inst (
  .s_axi_aclk   (s_axi_aclk	  ),    // input  wire s_axi_aclk
  .s_axi_aresetn(s_axi_aresetn),    // input  wire s_axi_aresetn
  .s_axi_awaddr (s_axi_awaddr ),    // input  wire [31 : 0] s_axi_awaddr
  .s_axi_awprot (s_axi_awprot ),    // input  wire [2 : 0] s_axi_awprot
  .s_axi_awvalid(s_axi_awvalid),    // input  wire s_axi_awvalid
  .s_axi_awready(s_axi_awready),    // output wire s_axi_awready
  .s_axi_wdata  (s_axi_wdata  ),    // input  wire [31 : 0] s_axi_wdata
  .s_axi_wstrb  (s_axi_wstrb  ),    // input  wire [3 : 0] s_axi_wstrb
  .s_axi_wvalid (s_axi_wvalid ),    // input  wire s_axi_wvalid
  .s_axi_wready (s_axi_wready ),    // output wire s_axi_wready
  .s_axi_bresp  (s_axi_bresp  ),    // output wire [1 : 0] s_axi_bresp
  .s_axi_bvalid (s_axi_bvalid ),    // output wire s_axi_bvalid
  .s_axi_bready (s_axi_bready ),    // input  wire s_axi_bready
  .s_axi_araddr (s_axi_araddr ),    // input  wire [31 : 0] s_axi_araddr
  .s_axi_arprot (s_axi_arprot ),    // input  wire [2 : 0] s_axi_arprot
  .s_axi_arvalid(s_axi_arvalid),    // input  wire s_axi_arvalid
  .s_axi_arready(s_axi_arready),    // output wire s_axi_arready
  .s_axi_rdata  (s_axi_rdata  ),    // output wire [31 : 0] s_axi_rdata
  .s_axi_rresp  (s_axi_rresp  ),    // output wire [1 : 0] s_axi_rresp
  .s_axi_rvalid (s_axi_rvalid ),    // output wire s_axi_rvalid
  .s_axi_rready (s_axi_rready ),    // input  wire s_axi_rready
  
  .m_axi_aclk   (s_axi_aclk_cc   ), // input  wire m_axi_aclk
  .m_axi_aresetn(s_axi_aresetn_cc), // input  wire m_axi_aresetn
  .m_axi_awaddr (s_axi_awaddr_cc ), // output wire [31 : 0] m_axi_awaddr
  .m_axi_awprot (s_axi_awprot_cc ), // output wire [2 : 0] m_axi_awprot
  .m_axi_awvalid(s_axi_awvalid_cc), // output wire m_axi_awvalid
  .m_axi_awready(s_axi_awready_cc), // input  wire m_axi_awready
  .m_axi_wdata  (s_axi_wdata_cc  ), // output wire [31 : 0] m_axi_wdata
  .m_axi_wstrb  (s_axi_wstrb_cc  ), // output wire [3 : 0] m_axi_wstrb
  .m_axi_wvalid (s_axi_wvalid_cc ), // output wire m_axi_wvalid
  .m_axi_wready (s_axi_wready_cc ), // input  wire m_axi_wready
  .m_axi_bresp  (s_axi_bresp_cc  ), // input  wire [1 : 0] m_axi_bresp
  .m_axi_bvalid (s_axi_bvalid_cc ), // input  wire m_axi_bvalid
  .m_axi_bready (s_axi_bready_cc ), // output wire m_axi_bready
  .m_axi_araddr (s_axi_araddr_cc ), // output wire [31 : 0] m_axi_araddr
  .m_axi_arprot (s_axi_arprot_cc ), // output wire [2 : 0] m_axi_arprot
  .m_axi_arvalid(s_axi_arvalid_cc), // output wire m_axi_arvalid
  .m_axi_arready(s_axi_arready_cc), // input  wire m_axi_arready
  .m_axi_rdata  (s_axi_rdata_cc  ), // input  wire [31 : 0] m_axi_rdata
  .m_axi_rresp  (s_axi_rresp_cc  ), // input  wire [1 : 0] m_axi_rresp
  .m_axi_rvalid (s_axi_rvalid_cc ), // input  wire m_axi_rvalid
  .m_axi_rready (s_axi_rready_cc )  // output  wire m_axi_rready
);

fano_decoder_axi #(
    .N_CHS(N_CHS),
    .DEBUG(DEBUG)
) fano_decoder_axi_inst (
    .o_reset         (reset         [N_CHS-1   :0]),
    .o_ctrl_reset    (ctrl_reset    [N_CHS-1   :0]),
    .o_diff_en       (diff_en       [N_CHS-1   :0]),
    .o_offset_mod_en (offset_mod_en [2*N_CHS-1 :0]),
    .o_llr_order     (llr_order     [3*N_CHS-1 :0]),
    .o_angle_step    (angle_step    [3*N_CHS-1 :0]),
    .o_code_rate     (code_rate     [2*N_CHS-1 :0]),
    .o_sync_period   (sync_period   [24*N_CHS-1:0]),
    .o_sync_threshold(sync_threshold[24*N_CHS-1:0]),
    .o_delta_T       (delta_T       [8*N_CHS-1 :0]),
    .o_forward_step  (forward_step  [16*N_CHS-1:0]),
    .o_stream_ch_sel (ctrl_ch_sel[log2(N_CHS)-1:0]),
    .i_sync          (sync          [N_CHS-1   :0]),
    // AXI-Lite
    .s_axi_aclk   (s_axi_aclk_cc   ),
    .s_axi_aresetn(s_axi_aresetn_cc),
    .s_axi_awaddr (s_axi_awaddr_cc ),
    .s_axi_awprot (s_axi_awprot_cc ),
    .s_axi_awvalid(s_axi_awvalid_cc),
    .s_axi_awready(s_axi_awready_cc), 
    .s_axi_wdata  (s_axi_wdata_cc  ),
    .s_axi_wstrb  (s_axi_wstrb_cc  ),
    .s_axi_wvalid (s_axi_wvalid_cc ),
    .s_axi_wready (s_axi_wready_cc ),
    .s_axi_bresp  (s_axi_bresp_cc  ),
    .s_axi_bvalid (s_axi_bvalid_cc ),
    .s_axi_bready (s_axi_bready_cc ),
    .s_axi_araddr (s_axi_araddr_cc ),
    .s_axi_arprot (s_axi_arprot_cc ),
    .s_axi_arvalid(s_axi_arvalid_cc),
    .s_axi_arready(s_axi_arready_cc),
    .s_axi_rdata  (s_axi_rdata_cc  ),
    .s_axi_rresp  (s_axi_rresp_cc  ),
    .s_axi_rvalid (s_axi_rvalid_cc ),
    .s_axi_rready (s_axi_rready_cc )
);

endmodule
