// ============================================================
//  assignment.v — 8-bit SPI Master / Slave (SPI Mode 0)
//
//  Author : Bhaskar Jha
//  Target : Altera Cyclone II — EP2C35F672C8 (DE2 board)
//  Tools  : Quartus II 13.0 SP1 / ModelSim-Altera
//
//  Description:
//    Single module implementing an 8-bit SPI controller.
//    Set parameter MODE = "MASTER" or "SLAVE" at instantiation.
//    Only one generate block is synthesized depending on MODE.
//
//  SPI Mode 0: CPOL=0 (clock idle low), CPHA=0 (sample on rising edge)
//    - Master drives MOSI on falling SCLK edge
//    - Master samples MISO on rising SCLK edge
//    - Slave drives MISO on falling SCLK edge
//    - Slave samples MOSI on rising SCLK edge
//
//  Transfer: 8 bits, MSB first, active-low chip select (CS)
// ============================================================

module assignment
#(parameter MODE = "MASTER")
(
    // ── Common ports ─────────────────────────────────────────
    input        clk,        // System clock (50 MHz on DE2)
    input        rst,        // Active-low synchronous reset
    input        start,      // Active-low: pulse low to begin transfer (master only)
    input  [7:0] data_in,    // Byte to transmit
    output reg [7:0] data_out, // Received byte (valid when done=1)
    output reg       done,   // Pulses high for one cycle when transfer completes

    // ── Master-mode ports ────────────────────────────────────
    output reg   sclk_out,   // SPI clock output (master generates)
    output reg   cs_out,     // Chip select output, active low
    output reg   mosi_out,   // Master Out Slave In
    input        miso,       // Master In Slave Out

    // ── Slave-mode ports ─────────────────────────────────────
    input        sclk_in,    // SPI clock input from master
    input        cs_in,      // Chip select input from master
    input        mosi_in,    // Data input from master
    output reg   miso_out    // Data output to master
);

// ── Internal registers ────────────────────────────────────────
reg [7:0]  shift_reg;   // Shift register — holds byte being sent/received
reg [2:0]  bit_cnt;     // Counts down from 7 to 0 (8 bits per transfer)
reg [49:0] clk_div;     // Clock divider counter for SCLK generation (master)
reg [1:0]  state;       // FSM state register

// ── FSM state encoding ────────────────────────────────────────
parameter IDLE     = 2'b00;  // Waiting for start signal
parameter TRANSFER = 2'b01;  // Shifting bits in/out
parameter DONE     = 2'b10;  // Transfer complete, assert done flag

// ── Clock divider threshold ───────────────────────────────────
// Divides system clock to generate SCLK.
// At 50 MHz: CLK_DIV_VAL=50_000_000 → SCLK toggles at 0.5 Hz (visible on LEDs)
// !! FOR HARDWARE: change 4 back to 50_000_000 before synthesis !!
parameter CLK_DIV_VAL = 4;

// ── Edge detection (slave uses these to track external SCLK and CS) ──
reg sclk_prev;
wire sclk_rising  = (sclk_prev == 0 && sclk_in == 1); // SCLK low→high
wire sclk_falling = (sclk_prev == 1 && sclk_in == 0); // SCLK high→low

reg cs_prev;
wire cs_falling = (cs_prev == 1 && cs_in == 0); // CS just asserted (high→low)

// ============================================================
//  MASTER LOGIC
//  Generates SCLK and CS, shifts data_in out on MOSI,
//  captures MISO into data_out.
//  State machine: IDLE → TRANSFER → DONE → IDLE
// ============================================================
generate
if (MODE == "MASTER")
begin : master_logic
    always @(posedge clk or negedge rst)
    begin
        if (!rst)  // Active-low reset — initialise all outputs
        begin
            state     <= IDLE;
            cs_out    <= 1;    // CS deasserted (idle high)
            sclk_out  <= 0;    // SCLK idle low (Mode 0)
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

            // ── IDLE: wait for active-low start pulse ─────────
            IDLE:
            begin
                done      <= 0;
                cs_out    <= 1;  // Keep CS deasserted while idle
                sclk_out  <= 0;
                mosi_out  <= 0;
                if(!start)       // start is active-low
                begin
                    cs_out    <= 0;        // Assert CS to select slave
                    shift_reg <= data_in;  // Load byte to transmit
                    bit_cnt   <= 7;        // 8 bits: count 7 down to 0
                    clk_div   <= 0;
                    state     <= TRANSFER;
                end
            end

            // ── TRANSFER: shift 8 bits using clock divider ────
            // On each SCLK falling edge: drive next MOSI bit
            // On each SCLK rising edge:  sample MISO into shift_reg
            TRANSFER:
            begin
                clk_div <= clk_div + 1;
                if(clk_div == CLK_DIV_VAL)  // Time to toggle SCLK
                begin
                    sclk_out <= ~sclk_out;   // Toggle SCLK
                    clk_div  <= 0;

                    if(sclk_out == 0)        // Was low → now going high (rising)
                    begin
                        // Drive MOSI with current MSB before rising edge
                        mosi_out <= shift_reg[7];
                    end

                    if(sclk_out == 1)        // Was high → now going low (falling)
                    begin
                        // Sample MISO on falling edge, shift into LSB
                        shift_reg <= {shift_reg[6:0], miso};
                        if(bit_cnt == 0)
                        begin
                            // Last bit — capture final received byte
                            data_out <= {shift_reg[6:0], miso};
                            state    <= DONE;
                        end
                        else
                            bit_cnt <= bit_cnt - 1;
                    end
                end
            end

            // ── DONE: deassert CS, signal completion ──────────
            DONE:
            begin
                cs_out   <= 1;   // Release chip select
                sclk_out <= 0;   // Return SCLK to idle
                done     <= 1;   // Pulse done for one cycle
                state    <= IDLE;
            end

            endcase
        end
    end
end
endgenerate

// ============================================================
//  SLAVE LOGIC
//  Follows master's SCLK and CS.
//  Preloads shift_reg from data_in while CS is high (idle).
//  Shifts MOSI into shift_reg on rising SCLK edges.
//  Drives MISO from shift_reg MSB on falling SCLK edges.
// ============================================================
generate
if (MODE == "SLAVE")
begin : slave_logic
    always @(posedge clk or negedge rst)
    begin
        if (!rst)  // Active-low reset
        begin
            shift_reg <= 0;
            bit_cnt   <= 7;
            data_out  <= 0;
            done      <= 0;
            miso_out  <= 0;
            sclk_prev <= 0;
            cs_prev   <= 1;
        end
        else
        begin
            // Track previous values for edge detection
            sclk_prev <= sclk_in;
            cs_prev   <= cs_in;
            done      <= 0;  // done is a one-cycle pulse, clear every cycle

            if(cs_in == 0)   // Transfer in progress (CS asserted)
            begin
                // Pre-drive MISO with MSB the moment CS goes low,
                // so the first bit is ready before the first SCLK rising edge
                if(cs_falling)
                    miso_out <= shift_reg[7];

                // Rising SCLK edge: sample MOSI into shift_reg LSB
                if(sclk_rising)
                begin
                    shift_reg <= {shift_reg[6:0], mosi_in};
                    if(bit_cnt == 0)
                    begin
                        // All 8 bits received — latch to data_out
                        data_out <= {shift_reg[6:0], mosi_in};
                        done     <= 1;
                        bit_cnt  <= 7;  // Reset for next transfer
                    end
                    else
                        bit_cnt <= bit_cnt - 1;
                end

                // Falling SCLK edge: drive next MISO bit (next MSB of shift_reg)
                if(sclk_falling)
                    miso_out <= shift_reg[7];
            end
            else             // CS deasserted — idle, preload shift_reg
            begin
                shift_reg <= data_in;  // Load byte to send in next transfer
                bit_cnt   <= 7;
            end
        end
    end
end
endgenerate

endmodule
