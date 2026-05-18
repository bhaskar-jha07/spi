// ============================================================
//  tb_assignment.v  —  Self-checking testbench for SPI master/slave
//
//  Compile with +define+SIMULATION so assignment.v uses CLK_DIV_VAL=4
// ============================================================

`timescale 1ns/1ps

module tb_assignment;

parameter CLK_PERIOD = 20;

reg clk, rst;
initial clk = 0;
always #(CLK_PERIOD/2) clk = ~clk;

reg        m_start;
reg  [7:0] m_data_in;
reg  [7:0] s_data_in;

wire        sclk_bus;
wire        cs_bus;
wire        mosi_bus;
wire        miso_bus;

wire [7:0]  m_data_out;
wire        m_done;
wire [7:0]  s_data_out;
wire        s_done;
wire        m_miso_out_nc;

// MASTER
assignment #(.MODE("MASTER")) uut_master (
    .clk      (clk),
    .rst      (rst),
    .start    (m_start),
    .data_in  (m_data_in),
    .sclk_out (sclk_bus),
    .cs_out   (cs_bus),
    .mosi_out (mosi_bus),
    .miso     (miso_bus),
    .mosi_in  (1'b0),
    .sclk_in  (1'b0),
    .cs_in    (1'b1),
    .miso_out (m_miso_out_nc),
    .data_out (m_data_out),
    .done     (m_done)
);

// SLAVE
assignment #(.MODE("SLAVE")) uut_slave (
    .clk      (clk),
    .rst      (rst),
    .sclk_in  (sclk_bus),
    .cs_in    (cs_bus),
    .mosi_in  (mosi_bus),
    .miso_out (miso_bus),
    .data_in  (s_data_in),
    .start    (1'b1),
    .miso     (1'b0),
    .sclk_out (),
    .cs_out   (),
    .mosi_out (),
    .data_out (s_data_out),
    .done     (s_done)
);

integer pass_count;
integer fail_count;
initial begin
    pass_count = 0;
    fail_count = 0;
end

task apply_reset;
    begin
        rst       = 0;
        m_start   = 1;
        m_data_in = 8'h00;
        s_data_in = 8'h00;
        repeat(5) @(posedge clk);
        rst = 1;
        repeat(3) @(posedge clk);
    end
endtask

task run_transfer;
    input [7:0]  master_sends;
    input [7:0]  slave_sends;
    input integer test_num;
    reg   [7:0]  exp_m, exp_s;
    integer      timeout;
    begin
        exp_m = slave_sends;
        exp_s = master_sends;

        // Preload slave shift_reg before transfer
        s_data_in = slave_sends;
        repeat(5) @(posedge clk); #1;

        m_data_in = master_sends;
        @(posedge clk); #1;

        m_start = 0;
        @(posedge clk); #1;
        m_start = 1;

        timeout = 0;
        while (!m_done && timeout < 500) begin
            @(posedge clk);
            timeout = timeout + 1;
        end
        @(posedge clk); #1;

        if (m_data_out === exp_m) begin
            $display("  PASS [Test %0d] Master RX: got 0x%02h, expected 0x%02h", test_num, m_data_out, exp_m);
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL [Test %0d] Master RX: got 0x%02h, expected 0x%02h", test_num, m_data_out, exp_m);
            fail_count = fail_count + 1;
        end

        if (s_data_out === exp_s) begin
            $display("  PASS [Test %0d] Slave  RX: got 0x%02h, expected 0x%02h", test_num, s_data_out, exp_s);
            pass_count = pass_count + 1;
        end else begin
            $display("  FAIL [Test %0d] Slave  RX: got 0x%02h, expected 0x%02h", test_num, s_data_out, exp_s);
            fail_count = fail_count + 1;
        end

        if (timeout >= 2000) begin
            $display("  FAIL [Test %0d] TIMEOUT", test_num);
            fail_count = fail_count + 1;
        end

        repeat(10) @(posedge clk);
    end
endtask

initial begin
    #500_000;
    $display("WATCHDOG: timed out");
    $finish;
end

initial begin
    $display("================================================");
    $display("  SPI Master <-> Slave Loopback Testbench");
    $display("================================================");

    apply_reset;

    $display("\n[Test 1] Basic: master=0xA5, slave=0x5A");
    run_transfer(8'hA5, 8'h5A, 1);

    $display("\n[Test 2] All zeros");
    run_transfer(8'h00, 8'h00, 2);

    $display("\n[Test 3] All ones");
    run_transfer(8'hFF, 8'hFF, 3);

    $display("\n[Test 4] Alternating bits: master=0xAA, slave=0x55");
    run_transfer(8'hAA, 8'h55, 4);

    $display("\n[Test 5] Single bit: master=0x01, slave=0x80");
    run_transfer(8'h01, 8'h80, 5);

    $display("\n[Test 6] Reset mid-transfer then recovery");
    s_data_in = 8'hAD;
    repeat(5) @(posedge clk);
    m_data_in = 8'hDE;
    m_start   = 0;
    @(posedge clk); #1;
    m_start   = 1;
    repeat(5) @(posedge clk);
    apply_reset;
    repeat(5) @(posedge clk);
    run_transfer(8'hBE, 8'hEF, 6);

    $display("\n[Test 7] Back-to-back transfers");
    run_transfer(8'h12, 8'h34, 7);
    run_transfer(8'h56, 8'h78, 8);
    run_transfer(8'h9A, 8'hBC, 9);

    $display("\n================================================");
    $display("  RESULTS: %0d passed, %0d failed", pass_count, fail_count);
    if (fail_count == 0)
        $display("  ALL TESTS PASSED");
    else
        $display("  SOME TESTS FAILED");
    $display("================================================\n");

    $finish;
end

initial begin
    $dumpfile("tb_assignment.vcd");
    $dumpvars(0, tb_assignment);
end

endmodule
