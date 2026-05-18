// ============================================================
//  assignment.v — 8-bit SPI Master / Slave (SPI Mode 0)
//
//  Author : Bhaskar Jha
//  Target : Altera Cyclone II — EP2C35F672C8 (DE2 board)
//  Tools  : Quartus II 13.0 SP1 / ModelSim-Altera
//
//  SPI Mode 0 (CPOL=0, CPHA=0), MSB first, active-low CS:
//    - SCLK idles low
//    - MOSI/MISO must be valid before each rising edge
//    - MOSI/MISO are sampled on rising edges
//    - MOSI/MISO change on falling edges (next bit)
// ============================================================

module assignment
#(parameter MODE = "MASTER")
(
    input        clk,
    input        rst,              // Active-low reset
    input        start,            // Master: active-low starts transfer
    input  [7:0] data_in,
    output reg [7:0] data_out,
    output reg       done,

    output reg   sclk_out,
    output reg   cs_out,
    output reg   mosi_out,
    input        miso,

    input        sclk_in,
    input        cs_in,
    input        mosi_in,
    output reg   miso_out
);

reg [7:0]  shift_reg;
reg [2:0]  bit_cnt;
reg [49:0] clk_div;
reg [1:0]  state;

parameter IDLE     = 2'b00;
parameter TRANSFER = 2'b01;
parameter DONE     = 2'b10;

// Simulation: fast divider. Synthesis on DE2: use 50_000_000 at 50 MHz clk.
`ifdef SIMULATION
    parameter CLK_DIV_VAL = 4;
`else
    parameter CLK_DIV_VAL = 50_000_000;
`endif

reg sclk_prev;
wire sclk_rising  = (sclk_prev == 1'b0 && sclk_in == 1'b1);
wire sclk_falling = (sclk_prev == 1'b1 && sclk_in == 1'b0);

reg cs_prev;
wire cs_falling = (cs_prev == 1'b1 && cs_in == 1'b0);

// ============================================================
//  MASTER
// ============================================================
generate
if (MODE == "MASTER")
begin : master_logic
    always @(posedge clk or negedge rst)
    begin
        if (!rst)
        begin
            state     <= IDLE;
            cs_out    <= 1'b1;
            sclk_out  <= 1'b0;
            done      <= 1'b0;
            mosi_out  <= 1'b0;
            clk_div   <= 50'd0;
            bit_cnt   <= 3'd0;
            shift_reg <= 8'd0;
            data_out  <= 8'd0;
        end
        else
        begin
            case (state)

            IDLE:
            begin
                done     <= 1'b0;
                cs_out   <= 1'b1;
                sclk_out <= 1'b0;
                mosi_out <= 1'b0;
                if (!start)
                begin
                    cs_out    <= 1'b0;
                    shift_reg <= data_in;
                    bit_cnt   <= 3'd7;
                    clk_div   <= 50'd0;
                    // MSB must be valid before the first rising SCLK edge
                    mosi_out  <= data_in[7];
                    state     <= TRANSFER;
                end
            end

            TRANSFER:
            begin
                clk_div <= clk_div + 50'd1;
                if (clk_div == CLK_DIV_VAL)
                begin
                    clk_div  <= 50'd0;
                    sclk_out <= ~sclk_out;

                    if (sclk_out == 1'b0)
                    begin
                        // Rising edge: sample MISO into LSB, MSB-first shift
                        shift_reg <= {shift_reg[6:0], miso};
                        if (bit_cnt == 3'd0)
                        begin
                            data_out <= {shift_reg[6:0], miso};
                            state    <= DONE;
                        end
                        else
                            bit_cnt <= bit_cnt - 3'd1;
                    end
                    else
                    begin
                        // Falling edge: drive next bit for the following rising edge
                        mosi_out <= shift_reg[7];
                    end
                end
            end

            DONE:
            begin
                cs_out   <= 1'b1;
                sclk_out <= 1'b0;
                done     <= 1'b1;
                state    <= IDLE;
            end

            endcase
        end
    end
end
endgenerate

// ============================================================
//  SLAVE
// ============================================================
generate
if (MODE == "SLAVE")
begin : slave_logic
    always @(posedge clk or negedge rst)
    begin
        if (!rst)
        begin
            shift_reg <= 8'd0;
            bit_cnt   <= 3'd7;
            data_out  <= 8'd0;
            done      <= 1'b0;
            miso_out  <= 1'b0;
            sclk_prev <= 1'b0;
            cs_prev   <= 1'b1;
        end
        else
        begin
            sclk_prev <= sclk_in;
            cs_prev   <= cs_in;
            done      <= 1'b0;

            if (cs_in == 1'b0)
            begin
                if (cs_falling)
                    // First bit (MSB) ready before first rising edge
                    miso_out <= shift_reg[7];

                if (sclk_rising)
                begin
                    shift_reg <= {shift_reg[6:0], mosi_in};
                    if (bit_cnt == 3'd0)
                    begin
                        data_out <= {shift_reg[6:0], mosi_in};
                        done     <= 1'b1;
                        bit_cnt  <= 3'd7;
                    end
                    else
                        bit_cnt <= bit_cnt - 3'd1;
                end

                if (sclk_falling)
                    // Next transmit bit after shift on rising edge
                    miso_out <= shift_reg[7];
            end
            else
            begin
                shift_reg <= data_in;
                bit_cnt   <= 3'd7;
            end
        end
    end
end
endgenerate

endmodule
