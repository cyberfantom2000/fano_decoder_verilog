`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 05.12.2018 15:57:05
// Design Name: 
// Module Name: simpleFIFO
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
module simpleFIFO #(
    parameter integer DATA_W = 8,
	parameter integer ADDR_W = 2,
	parameter integer FIFO_LEN = 2**ADDR_W,
	parameter integer FWFT = 0 )
(
    input               Clk,
    input               Rst,
    
    input [DATA_W-1:0]  wrData,
    input               wrWe,
    output              wrFull,
	
    output [DATA_W-1:0] rdData,
    input               rdRe,
    output              rdEmpty,
    
    output [ADDR_W-1:0] Entries
);

// Memory Block Logic
localparam RAM_DEPTH = (1 << ADDR_W);
(*ram_style = "{block}"*) // (* ram_style = "{auto|block|distributed|pipe_distributed|block_power1|block_power2}" *)
reg [DATA_W-1:0] ram [0:RAM_DEPTH-1];
reg [DATA_W-1:0] ram_r0 = 0;

reg [DATA_W-1:0] rdData_r = 0;
wire ram_r0_re;
wire ram_re;

reg [ADDR_W-1:0] wptr = 0;
wire [ADDR_W-1:0] wptr_next;
wire we_prot;
reg [ADDR_W-1:0] rptr = 0;
wire [ADDR_W-1:0] rptr_next; 
reg ram_empty;
reg ram_r0_empty = 1;
reg ram_r1_empty = 1;

reg wrFull_r = 0;

reg [ADDR_W-1:0] Entries_r = 0;

always @(posedge Clk) begin
    if (Rst) begin
        Entries_r <= 0;
    end else begin
       Entries_r <= wptr - rptr; 
    end
end

always @(posedge Clk) begin
    if (Rst) begin
        wrFull_r <= 0;
    end else if (rptr == wptr_next) begin
        wrFull_r <= 1;
    end else begin
        wrFull_r <= 0;
    end
end

always @(posedge Clk) begin
    if (Rst) begin
        wptr <= 0;
    end else if (we_prot) begin
        wptr <= wptr_next;
    end
end

assign we_prot = wrWe & ~wrFull_r;
assign wptr_next = wptr + 1; 

always @(posedge Clk) begin
   if (we_prot) begin
      ram[wptr[ADDR_W-1:0]] <= wrData;
   end
end

always @(posedge Clk) begin
    if (Rst) begin
        rptr <= 0;
    end else if (ram_re) begin
        rptr <= rptr_next;
    end
end

assign rptr_next = rptr + 1;

assign ram_r0_re = (FWFT) ? (rdRe | ram_r1_empty) : rdRe;
assign ram_re = (FWFT) ? ~ram_empty & (ram_r0_re | ram_r0_empty) :
                         ~ram_empty & (ram_r0_re | ram_r0_empty);
assign wrFull = (FWFT) ? wrFull_r  : wrFull_r;
assign rdEmpty = (FWFT) ? ram_r1_empty : ram_r0_empty;

always @(posedge Clk) begin
    if (Rst) begin
        ram_empty <= 1;
    end else if (ram_re | we_prot) begin
        ram_empty <= (wptr == rptr_next) & ram_re & ~we_prot;
        //ram_empty <= ((wptr == 0) & (rptr == 0)) | ((wptr == rptr_next) & ram_re & ~we_prot);
    end
end

always @(posedge Clk) begin
    if (Rst) begin
        ram_r0_empty <= 1;
    end else if (ram_re) begin
        ram_r0_empty <= 0;
    end else if (ram_r0_re & ~ram_re) begin
        ram_r0_empty <= 1;
    end
end

always @(posedge Clk) begin
    if (Rst) begin
        ram_r1_empty <= 1;
    end else if (ram_r0_re) begin
        ram_r1_empty <= ram_r0_empty;
    end
end

always @(posedge Clk) begin
    if (ram_re) begin
        ram_r0 <= ram[rptr[ADDR_W-1:0]];
    end
end

always @(posedge Clk) begin
    if (Rst) begin
        rdData_r <= {DATA_W{1'b0}};
    end else if (ram_r0_re) begin
        rdData_r <= ram_r0;
    end
end

assign rdData = rdData_r;
assign Entries = Entries_r;
  	
endmodule