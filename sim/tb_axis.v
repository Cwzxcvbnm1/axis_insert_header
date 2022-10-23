`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/05/19 14:56:08
// Design Name: 
// Module Name: tb_sdma_ctrl
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


module tb_axis(

    );
    localparam DATA_WD = 16;
    localparam DATA_BYTE_WD = DATA_WD / 8;
    localparam BYTE_CNT_WD = $clog2(DATA_BYTE_WD);
    
    
reg clk=1'b0;
reg rst_n;
    reg valid_in;
    reg [DATA_WD-1 : 0] data_in;
    reg [DATA_BYTE_WD-1 : 0] keep_in;
    reg last_in;
    wire ready_in;
    
    wire valid_out;
    wire [DATA_WD-1 : 0] data_out;
    wire [DATA_BYTE_WD-1 : 0] keep_out;
    wire last_out;
    reg ready_out;

    reg valid_insert;
    reg [DATA_WD-1 : 0] header_insert;
    reg [DATA_BYTE_WD-1 : 0] keep_insert;
    reg [BYTE_CNT_WD : 0] byte_insert_cnt;
    wire ready_insert;
    
initial begin
    rst_n=1'b0;
    
    #30
    rst_n=1'b1;
    #10
    header_insert = 32'h0F0E00D0C;
    keep_insert =4'b0111;
    byte_insert_cnt = 3'b011;
    valid_insert = 1'b1;
    #10
    valid_insert=1'b0;
    #10
    ready_out = 1'b1;
    valid_in = 1'b1;
    data_in = 32'h0A0B0C0D;
    keep_in = 4'b1111;
    last_in = 1'b0;
    #10
    valid_in = 1'b1;
    data_in = 32'h0E0F0001;
    keep_in = 4'b1111;
    last_in = 1'b0;
    #10
    valid_in = 1'b1;
    data_in = 32'h02030405;
    keep_in = 4'b1111;
    last_in = 1'b0;
    #10
    valid_in = 1'b1;
    data_in = 32'h06070809;
    keep_in = 4'b1111;
    last_in = 1'b0;
    #10
    valid_in = 1'b1;
    data_in = 32'h0A0B0B0B;
    keep_in = 4'b1000;
    last_in = 1'b1;
    #10
    valid_in = 1'b0;
    data_in = 32'h0000;
end


always #5 clk <= ~clk;

axi_stream_insert_header #(
     .DATA_WD(DATA_WD),
     .DATA_BYTE_WD(DATA_BYTE_WD),
     .BYTE_CNT_WD(BYTE_CNT_WD)
) 
axi_stream_insert_header(
    .clk         (clk),
    .rst_n       (rst_n),
              
    .valid_in    (valid_in),
    .data_in     (data_in ),
    .keep_in     (keep_in ),
    .last_in     (last_in ),
    .ready_in    (ready_in),
              
    .valid_out   (valid_out),
    .data_out    (data_out ),
    .keep_out    (keep_out ),
    .last_out    (last_out ),
    .ready_out   (ready_out),
   
    .valid_insert    (valid_insert   ),
    .header_insert   (header_insert  ),
    .keep_insert     (keep_insert    ),
    .byte_insert_cnt (byte_insert_cnt),
    .ready_insert    (ready_insert   )
);

endmodule
