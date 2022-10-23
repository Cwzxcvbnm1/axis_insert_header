module axi_stream_insert_header #(
    parameter DATA_WD = 32,
    parameter DATA_BYTE_WD = DATA_WD / 8,
    parameter BYTE_CNT_WD = $clog2(DATA_BYTE_WD)
) (
    input clk,
    input rst_n,
    // AXI Stream input original data
    input valid_in,
    input [DATA_WD-1 : 0] data_in,
    input [DATA_BYTE_WD-1 : 0] keep_in,
    input last_in,
    output ready_in,
    // AXI Stream output with header inserted
    output valid_out,
    output [DATA_WD-1 : 0] data_out,
    output [DATA_BYTE_WD-1 : 0] keep_out,
    output last_out,
    input ready_out,
    // The header to be inserted to AXI Stream input
    input valid_insert,
    input [DATA_WD-1 : 0] header_insert,
    input [DATA_BYTE_WD-1 : 0] keep_insert,
    input [BYTE_CNT_WD : 0] byte_insert_cnt,
    output ready_insert
);

// Your code here
function [BYTE_CNT_WD:0]count_1;
    input [DATA_BYTE_WD-1:0] data_in;
    reg [BYTE_CNT_WD:0]cnt,n;
begin
    cnt=0;
    for (n=0;n<DATA_BYTE_WD; n=n+1) begin
        if(data_in[n])
            cnt = cnt+1'b1; 
            count_1 =cnt;
    end
end
endfunction

localparam IDEL = 4'b0001;
localparam HAEDER_INSERT = 4'b0010;
localparam WAIT = 4'b0100;
localparam IN_OUT = 4'b1000;

reg [3:0] current_state;
reg [3:0] next_state;
reg [BYTE_CNT_WD : 0] byte_insert_cnt_temp;
reg [DATA_BYTE_WD-1 : 0] keep_insert_temp;
reg [DATA_WD-1:0] mem [0:4];
reg [1:0] addr_in;
reg [1:0] addr_out;
reg[4:0] cnt_temp;
reg [DATA_BYTE_WD-1 : 0] keepin_last;
wire [BYTE_CNT_WD:0] keepin_last_count;
wire [4:0] out_cnt ;
reg [2*DATA_WD-1 : 0] data_out_reg;
reg [2*DATA_BYTE_WD-1 : 0] keep_out_reg;
reg last_out_reg;
reg [4:0]cnt_out_temp;

    assign keepin_last_count = count_1(keepin_last);//输入最后一个keep中有多少个1的函数实现
    assign ready_in = (current_state == HAEDER_INSERT || current_state==IN_OUT)?1'b1:1'b0;
    assign ready_insert = (current_state == IDEL)?1'b1:1'b0;
    assign valid_out = (current_state == IN_OUT)?1'b1:1'b0;
    assign out_cnt = (keepin_last_count+byte_insert_cnt_temp>DATA_BYTE_WD)?cnt_temp+1'b1:cnt_temp;//表示输出多少有效数据的计数器
                                                                                                //若header keep=4‘b0111 数据last keep = 4'b1100，则代表输出数据量比输入数据多一个，需要加一
                                                                                                //若header keep=4‘b0111 数据last keep = 4'b1000，则代表输出数据量跟输入数据一样，不需要加一
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)begin
            current_state <= IDEL;
        end else begin
            current_state <= next_state;
        end
    end

    always @(*) begin
        next_state = IDEL;
        case (current_state)
            IDEL:begin
                if(valid_insert && ready_insert)//header准备好后，接受header
                    next_state = HAEDER_INSERT;
                else 
                    next_state = IDEL;     
            end

            HAEDER_INSERT:begin
                if(ready_out && addr_in == 2'd3)//在输出都准备好并且缓存满时时，启动输入输出流水
                    next_state = IN_OUT;
                else if(addr_in == 2'd3)
                    next_state = WAIT;//在header接受后拉高ready_in，表示可以接受输入数据，使用1个深度为5的RAM暂存输入和header，若RAM存满输出还没准备好，就拉低ready_in等待流水启动
                else
                    next_state = HAEDER_INSERT;     
            end

            WAIT:begin
                if(valid_in && ready_out)//等待输出ready
                    next_state = IN_OUT;
                else 
                    next_state = WAIT;     
            end

            IN_OUT:begin
                if(last_out)//输入输出流水
                    next_state = IDEL;
                else 
                    next_state = IN_OUT;     
            end

            default: next_state = IDEL;
        endcase    
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)begin
            byte_insert_cnt_temp <= 'b0;
            keep_insert_temp <= 'b0;
        end else if(valid_insert && ready_insert) begin
            byte_insert_cnt_temp <= byte_insert_cnt;//对byte_insert_cnt和keep_insert的暂存
            keep_insert_temp <= keep_insert;
        end else begin
            byte_insert_cnt_temp <= byte_insert_cnt_temp;
            keep_insert_temp <= keep_insert_temp;
        end
    end

    integer k;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)begin
            addr_in <= 2'd0;
            cnt_temp <= 5'b0;
            keepin_last <= 'b0; 
            for(k=0;k<=4;k=k+1) 
               mem[k] <= 32'b0;        
        end else if(valid_insert && ready_insert && addr_in==2'd0) begin//第一个放入RAM的数据，header
            addr_in <= addr_in + 1'b1;
            mem[addr_in] <= header_insert;
            cnt_temp <= 5'b0;
            keepin_last <= 'b0;
        end else if (valid_in && ready_in && last_in) begin//输入流水的最后一个数，并且cnt对输入数据量进行存储，并保存最后一个数据的keep
            addr_in <= addr_in + 1'b1;
            mem[addr_in] <= data_in;
            cnt_temp <= cnt_temp + 1'b1;
            keepin_last <= keep_in;
        end else if (valid_in && ready_in) begin//输入流水
            addr_in <= addr_in + 1'b1;
            mem[addr_in] <= data_in;
            cnt_temp <= cnt_temp + 1'b1;
            keepin_last <= keepin_last;
        end else begin
            addr_in <= addr_in;
            cnt_temp <= cnt_temp;
            keepin_last <= keepin_last;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)begin
            data_out_reg <= 'b0;
            keep_out_reg <= 'b0;
            last_out_reg <= 1'b0;
            addr_out <= 'b0;
            cnt_out_temp <= 'b0;
        end else if((current_state==HAEDER_INSERT || current_state==WAIT) && next_state == IN_OUT) begin//输出的第一个数
            data_out_reg <= {mem[addr_out],mem[addr_out+1]} << (DATA_BYTE_WD - byte_insert_cnt)*8;
            keep_out_reg <= {DATA_BYTE_WD{1'b1}};
            last_out_reg <= 1'b0;
            addr_out <= addr_out + 1'b1;
            cnt_out_temp <= cnt_out_temp+1'b1;
        end else if (valid_out && ready_out) begin
            data_out_reg <= {mem[addr_out],mem[addr_out+1]} << (DATA_BYTE_WD - byte_insert_cnt)*8;//输出流水，最后一个数时拉高last，并且对keep进行赋值
            addr_out <= addr_out + 1'b1;
            cnt_out_temp <= cnt_out_temp+1'b1;
            if (cnt_out_temp == out_cnt-1'b1) begin
            last_out_reg <= 1'b1;
            keep_out_reg <= (out_cnt==cnt_temp)?keepin_last<<(DATA_BYTE_WD - byte_insert_cnt):({keep_insert_temp,keepin_last} << (DATA_BYTE_WD - byte_insert_cnt));//根据输出数据量是否比输入多一            
            end else begin                                                                                                                                         //对最后一个keep的两种赋值方式  
            last_out_reg <= 1'b0;
            keep_out_reg <= {DATA_BYTE_WD{1'b1}};               
            end
        end else begin
            data_out_reg <= data_out_reg;
            keep_out_reg <= keep_out_reg;
            last_out_reg <= 1'b0;
            addr_out <= 'b0;
            cnt_out_temp <= 'b0;
        end
    end

    assign data_out = data_out_reg[2*DATA_WD-1:DATA_WD];
    assign keep_out = keep_out_reg[DATA_BYTE_WD-1:0];
    assign last_out = last_out_reg;

endmodule