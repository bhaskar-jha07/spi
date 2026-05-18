// ============================================================
//  tb_assignment.v — Self-checking SPI master/slave loopback tests
//
//  Instantiates one MASTER and one SLAVE, wired to the same bus.
//  Compile assignment.v with +define+SIMULATION for CLK_DIV_VAL=4.
//
//  Run:  cd simulation/modelsim && do assignment_run_msim_rtl_verilog.do
// ============================================================

`timescale 1ns/1ps

module tb_assignment;

    parameter CLK_PERIOD   = 20;   // 50 MHz system clock
    parameter DONE_TIMEOUT = 2000; // max clk cycles to wait for m_done

    reg clk, rst;
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    reg        m_start;
    reg  [7:0] m_data_in;
    reg  [7:0] s_data_in;

    wire       sclk_bus, cs_bus, mosi_bus, miso_bus;
    wire [7:0] m_data_out, s_data_out;
    wire       m_done, s_done;
    wire       m_miso_out_nc;

    // ── DUT: master drives SCLK/CS/MOSI; slave drives MISO ─────────────
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

    // ── Reset both DUTs ───────────────────────────────────────────────
    task apply_reset;
        begin
            rst       = 1'b0;
            m_start   = 1'b1;
            m_data_in = 8'h00;
            s_data_in = 8'h00;
            repeat (5) @(posedge clk);
            rst = 1'b1;
            repeat (3) @(posedge clk);
        end
    endtask

    // ── Compare one byte; increment pass/fail counters ────────────────
    task check_byte;
        input [7:0]  actual;
        input [7:0]  expected;
        input [255:0] label;
        begin
            if (actual === expected) begin
                $display("  PASS %s: 0x%02h", label, actual);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL %s: got 0x%02h, expected 0x%02h", label, actual, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ── One full-duplex 8-bit transfer ────────────────────────────────
    task run_transfer;
        input [7:0]   master_tx;
        input [7:0]   slave_tx;
        input integer test_num;
        reg    [7:0]  exp_master_rx;
        reg    [7:0]  exp_slave_rx;
        integer       timeout;
        begin
            exp_master_rx = slave_tx;  // master receives what slave sent
            exp_slave_rx  = master_tx; // slave receives what master sent

            s_data_in = slave_tx;
            repeat (5) @(posedge clk);

            m_data_in = master_tx;
            @(posedge clk);

            m_start = 1'b0;
            @(posedge clk);
            m_start = 1'b1;

            timeout = 0;
            while (!m_done && timeout < DONE_TIMEOUT) begin
                @(posedge clk);
                timeout = timeout + 1;
            end
            @(posedge clk);

            if (timeout >= DONE_TIMEOUT) begin
                $display("  FAIL [Test %0d] TIMEOUT waiting for master done", test_num);
                fail_count = fail_count + 2;
            end else begin
                check_byte(m_data_out, exp_master_rx, "master RX");
                check_byte(s_data_out, exp_slave_rx,  "slave RX ");
            end

            repeat (10) @(posedge clk);
        end
    endtask

    // ── Watchdog ──────────────────────────────────────────────────────
    initial begin
        #2_000_000;
        $display("WATCHDOG: simulation timed out");
        $finish;
    end

    // ── Test sequence ─────────────────────────────────────────────────
    initial begin
        $display("================================================");
        $display("  SPI Mode 0 — Master <-> Slave loopback");
        $display("================================================");

        apply_reset;

        $display("\n[Test 1] Basic exchange");
        run_transfer(8'hA5, 8'h5A, 1);

        $display("\n[Test 2] MSB-only patterns (catches first-bit bugs)");
        run_transfer(8'h80, 8'h01, 2);  // master MSB=1, slave MSB=0
        run_transfer(8'h01, 8'h80, 3);

        $display("\n[Test 3] All zeros / all ones");
        run_transfer(8'h00, 8'h00, 4);
        run_transfer(8'hFF, 8'hFF, 5);

        $display("\n[Test 4] Alternating bits");
        run_transfer(8'hAA, 8'h55, 6);

        $display("\n[Test 5] Walking-one / walking-zero on MSB side");
        run_transfer(8'h80, 8'h40, 7);
        run_transfer(8'h08, 8'h04, 8);

        $display("\n[Test 6] Reset then recovery");
        apply_reset;
        run_transfer(8'hBE, 8'hEF, 9);

        $display("\n[Test 7] Back-to-back transfers");
        run_transfer(8'h12, 8'h34, 10);
        run_transfer(8'h56, 8'h78, 11);
        run_transfer(8'h9A, 8'hBC, 12);

        $display("\n================================================");
        $display("  RESULTS: %0d checks passed, %0d failed", pass_count, fail_count);
        if (fail_count == 0)
            $display("  *** ALL TESTS PASSED ***");
        else
            $display("  *** SOME TESTS FAILED ***");
        $display("================================================\n");

        if (fail_count != 0)
            $fatal(1, "Testbench reported failures");

        $finish;
    end

    initial begin
        $dumpfile("tb_assignment.vcd");
        $dumpvars(0, tb_assignment);
    end

endmodule
