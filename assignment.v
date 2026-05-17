
module assignment
#(parameter MODE = "MASTER")
(
    input        clk,
    input        rst,
    input        start,
    input  [7:0] data_in,
    input        miso,
    input        mosi_in,
    output reg   mosi_out,
    output reg   miso_out,
    input        sclk_in,
    input        cs_in,
    output reg   sclk_out,
    output reg   cs_out,
    output reg [7:0] data_out,
    output reg       done
);

reg [7:0]  shift_reg;
reg [2:0]  bit_cnt;
reg [49:0] clk_div;       
reg [1:0]  state;

parameter IDLE     = 2'b00;
parameter TRANSFER = 2'b01;
parameter DONE     = 2'b10;

reg sclk_prev;
wire sclk_rising  = (sclk_prev == 0 && sclk_in == 1);
wire sclk_falling = (sclk_prev == 1 && sclk_in == 0);


generate
if (MODE == "MASTER")
begin : master_logic
    always @(posedge clk or negedge rst)
    begin
        if (!rst)
        begin
            state     <= IDLE;
            cs_out    <= 1;
            sclk_out  <= 0;
            done      <= 0;
            mosi_out  <= 0;
            clk_div   <= 0;
            bit_cnt   <= 0;
            shift_reg <= 0;
            data_out  <= 0;
        end
        else
        begin
            case(state)
            IDLE:
            begin
                done      <= 0;
                cs_out    <= 1;
                sclk_out  <= 0;
                mosi_out  <= 0;
                if(!start)             
                begin
                    cs_out    <= 0;
                    shift_reg <= data_in;
                    bit_cnt   <= 7;
                    clk_div   <= 0;
                    state     <= TRANSFER;
                end
            end
            TRANSFER:
            begin
                clk_div <= clk_div + 1;
                if(clk_div == 50_000_000)
                begin
                    sclk_out <= ~sclk_out;
                    clk_div  <= 0;
                    if(sclk_out == 0)       
                    begin
                        mosi_out <= shift_reg[7];
                    end
                    if(sclk_out == 1)       
                    begin
                        shift_reg <= {shift_reg[6:0], miso};
                        if(bit_cnt == 0)
                            state <= DONE;
                        else
                            bit_cnt <= bit_cnt - 1;
                    end
                end
            end
            DONE:
            begin
                cs_out   <= 1;
                sclk_out <= 0;
                data_out <= shift_reg;
                done     <= 1;
                state    <= IDLE;
            end
            endcase
        end
    end
end
endgenerate


generate
if (MODE == "SLAVE")
begin : slave_logic
    always @(posedge clk or negedge rst)
    begin
        if (!rst)
        begin
            shift_reg <= 0;
            bit_cnt   <= 7;
            data_out  <= 0;
            done      <= 0;
            miso_out  <= 0;
            sclk_prev <= 0;
        end
        else
        begin
            sclk_prev <= sclk_in;
            done      <= 0;
            if(cs_in == 0)
            begin
                if(sclk_rising)
                begin
                    shift_reg <= {shift_reg[6:0], mosi_in};
                    if(bit_cnt == 0)
                    begin
                        data_out <= {shift_reg[6:0], mosi_in};
                        done     <= 1;
                        bit_cnt  <= 7;
                    end
                    else
                        bit_cnt <= bit_cnt - 1;
                end
                if(sclk_falling)
                    miso_out <= shift_reg[7];
            end
            else
            begin
                shift_reg <= data_in;
                bit_cnt   <= 7;
            end
        end
    end
end
endgenerate

endmodule
