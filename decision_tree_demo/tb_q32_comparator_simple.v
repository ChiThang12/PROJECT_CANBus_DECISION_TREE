// ============================================================================
// Simple Testbench for Q32.32 Fixed-Point Comparator
// Quick test with basic functionality
// ============================================================================

`timescale 1ns/1ps

module tb_q32_comparator_simple;

    // Clock and reset signals
    reg         clk;
    reg         rst_n;
    reg         en;
    
    // Testbench signals
    reg  [63:0] feature;      // Feature value (Q32.32)
    reg  [63:0] threshold;    // Threshold value (Q32.32)
    wire        go_left;      // Output from DUT
    wire        compare_done; // Comparison done signal
    
    // Clock generation (10ns period = 100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Instantiate the Device Under Test (DUT)
    q32_comparator dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .en           (en),
        .feature      (feature),
        .threshold    (threshold),
        .go_left      (go_left),
        .compare_done (compare_done)
    );
    
    // Main test sequence
    initial begin
        $display("==========================================");
        $display("Simple Q32.32 Comparator Test");
        $display("==========================================");
        
        // Initialize signals
        rst_n = 1'b0;
        en = 1'b0;
        feature = 64'd0;
        threshold = 64'd0;
        
        // Reset sequence
        $display("Applying reset...");
        @(posedge clk);
        @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);
        $display("Reset completed");
        
        // Test 1: Simple positive comparison
        $display("Test 1: 1.5 <= 2.0");
        feature = 64'h00000001_80000000;    // 1.5 in Q32.32
        threshold = 64'h00000002_00000000;  // 2.0 in Q32.32
        en = 1'b1;
        @(posedge clk);
        wait(compare_done);
        @(posedge clk);
        if (go_left == 1'b1) begin
            $display("PASS: 1.5 <= 2.0");
        end else begin
            $display("FAIL: 1.5 <= 2.0, got go_left = %b", go_left);
        end
        en = 1'b0;
        @(posedge clk);
        
        // Test 2: Simple negative comparison
        $display("Test 2: -1.0 <= 1.0");
        feature = 64'hFFFFFFFF_00000000;    // -1.0 in Q32.32
        threshold = 64'h00000001_00000000;  // 1.0 in Q32.32
        en = 1'b1;
        @(posedge clk);
        wait(compare_done);
        @(posedge clk);
        if (go_left == 1'b1) begin
            $display("PASS: -1.0 <= 1.0");
        end else begin
            $display("FAIL: -1.0 <= 1.0, got go_left = %b", go_left);
        end
        en = 1'b0;
        @(posedge clk);
        
        // Test 3: Equal values
        $display("Test 3: 2.0 <= 2.0");
        feature = 64'h00000002_00000000;    // 2.0 in Q32.32
        threshold = 64'h00000002_00000000;  // 2.0 in Q32.32
        en = 1'b1;
        @(posedge clk);
        wait(compare_done);
        @(posedge clk);
        if (go_left == 1'b1) begin
            $display("PASS: 2.0 <= 2.0");
        end else begin
            $display("FAIL: 2.0 <= 2.0, got go_left = %b", go_left);
        end
        en = 1'b0;
        @(posedge clk);
        
        // Test 4: Greater than
        $display("Test 4: 3.0 > 2.0");
        feature = 64'h00000003_00000000;    // 3.0 in Q32.32
        threshold = 64'h00000002_00000000;  // 2.0 in Q32.32
        en = 1'b1;
        @(posedge clk);
        wait(compare_done);
        @(posedge clk);
        if (go_left == 1'b0) begin
            $display("PASS: 3.0 > 2.0");
        end else begin
            $display("FAIL: 3.0 > 2.0, got go_left = %b", go_left);
        end
        en = 1'b0;
        @(posedge clk);
        
        // Test 5: Reset behavior
        $display("Test 5: Reset behavior");
        feature = 64'h00000005_00000000;    // 5.0 in Q32.32
        threshold = 64'h00000003_00000000;  // 3.0 in Q32.32
        en = 1'b1;
        @(posedge clk);
        wait(compare_done);
        @(posedge clk);
        
        // Apply reset
        rst_n = 1'b0;
        @(posedge clk);
        @(posedge clk);
        
        if (go_left == 1'b0 && compare_done == 1'b0) begin
            $display("PASS: Reset behavior");
        end else begin
            $display("FAIL: Reset behavior, go_left = %b, compare_done = %b", go_left, compare_done);
        end
        
        // Restore reset
        rst_n = 1'b1;
        @(posedge clk);
        
        $display("==========================================");
        $display("Simple test completed!");
        $display("==========================================");
        
        $finish;
    end
    
    // Generate VCD file for waveform viewing
    initial begin
        $dumpfile("tb_q32_comparator_simple.vcd");
        $dumpvars(0, tb_q32_comparator_simple);
    end

endmodule

