// ============================================================================
// Testbench for Q32.32 Fixed-Point Comparator with Clock and Reset
// Tests the q32_comparator module with various floating point inputs
// ============================================================================

`timescale 1ns/1ps

module tb_q32_comparator;

    // Clock and reset signals
    reg         clk;
    reg         rst_n;
    reg         en;
    
    // Testbench signals
    reg  [63:0] feature;      // Feature value (Q32.32)
    reg  [63:0] threshold;    // Threshold value (Q32.32)
    wire        go_left;      // Output from DUT
    wire        compare_done; // Comparison done signal
    
    // Expected results for verification
    reg         expected_result;
    reg         test_passed;
    integer     test_count;
    integer     passed_count;
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock (10ns period)
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
    
    // Function to convert floating point to Q32.32 format
    function [63:0] fp_to_q32_32;
        input real fp_value;
        reg signed [31:0] int_part;
        reg [31:0] frac_part;
        begin
            int_part = $rtoi(fp_value);
            frac_part = $rtoi((fp_value - int_part) * (2.0**32));
            fp_to_q32_32 = {int_part, frac_part};
        end
    endfunction
    
    // Function to convert Q32.32 to floating point for display
    function real q32_32_to_fp;
        input [63:0] q32_32_value;
        reg signed [31:0] int_part;
        reg [31:0] frac_part;
        begin
            int_part = q32_32_value[63:32];
            frac_part = q32_32_value[31:0];
            q32_32_to_fp = int_part + (frac_part / (2.0**32));
        end
    endfunction
    
    // Reset task
    task reset_dut;
        begin
            rst_n = 1'b0;
            en = 1'b0;
            feature = 64'd0;
            threshold = 64'd0;
            @(posedge clk);
            @(posedge clk);
            rst_n = 1'b1;
            @(posedge clk);
            $display("DUT Reset completed");
        end
    endtask
    
    // Test task with clock synchronization
    task test_case;
        input real fp_feature;
        input real fp_threshold;
        input expected_go_left;
        input [255:0] test_name;
        begin
            // Convert floating point to Q32.32
            feature = fp_to_q32_32(fp_feature);
            threshold = fp_to_q32_32(fp_threshold);
            expected_result = expected_go_left;
            
            // Apply inputs and enable
            en = 1'b1;
            @(posedge clk);
            
            // Wait for comparison to complete
            wait(compare_done);
            @(posedge clk);
            
            // Check result
            test_passed = (go_left == expected_result);
            test_count = test_count + 1;
            if (test_passed) begin
                passed_count = passed_count + 1;
                $display("PASS: %s", test_name);
            end else begin
                $display("FAIL: %s", test_name);
                $display("  Feature: %f (0x%016h)", q32_32_to_fp(feature), feature);
                $display("  Threshold: %f (0x%016h)", q32_32_to_fp(threshold), threshold);
                $display("  Expected go_left: %b, Got: %b", expected_result, go_left);
            end
            
            // Disable for next test
            en = 1'b0;
            @(posedge clk);
        end
    endtask
    
    // Main test sequence
    initial begin
        $display("==========================================");
        $display("Q32.32 Comparator Testbench (with Clock/Reset)");
        $display("==========================================");
        
        // Initialize counters
        test_count = 0;
        passed_count = 0;
        
        // Reset the DUT
        reset_dut;
        
        // Test Case 1: Positive numbers - feature < threshold
        test_case(1.5, 2.0, 1'b1, "Positive: 1.5 <= 2.0");
        
        // Test Case 2: Positive numbers - feature > threshold
        test_case(2.5, 2.0, 1'b0, "Positive: 2.5 > 2.0");
        
        // Test Case 3: Positive numbers - feature = threshold
        test_case(2.0, 2.0, 1'b1, "Positive: 2.0 <= 2.0");
        
        // Test Case 4: Negative numbers - feature < threshold
        test_case(-2.5, -1.0, 1'b1, "Negative: -2.5 <= -1.0");
        
        // Test Case 5: Negative numbers - feature > threshold
        test_case(-1.0, -2.0, 1'b0, "Negative: -1.0 > -2.0");
        
        // Test Case 6: Mixed signs - negative feature, positive threshold
        test_case(-1.0, 1.0, 1'b1, "Mixed: -1.0 <= 1.0");
        
        // Test Case 7: Mixed signs - positive feature, negative threshold
        test_case(1.0, -1.0, 1'b0, "Mixed: 1.0 > -1.0");
        
        // Test Case 8: Zero cases
        test_case(0.0, 0.0, 1'b1, "Zero: 0.0 <= 0.0");
        test_case(0.0, 1.0, 1'b1, "Zero: 0.0 <= 1.0");
        test_case(1.0, 0.0, 1'b0, "Zero: 1.0 > 0.0");
        
        // Test Case 9: Small fractional differences
        test_case(1.0000001, 1.0000002, 1'b1, "Small frac: 1.0000001 <= 1.0000002");
        test_case(1.0000002, 1.0000001, 1'b0, "Small frac: 1.0000002 > 1.0000001");
        
        // Test Case 10: Large numbers
        test_case(1000000.5, 1000001.0, 1'b1, "Large: 1000000.5 <= 1000001.0");
        test_case(1000001.5, 1000001.0, 1'b0, "Large: 1000001.5 > 1000001.0");
        
        // Test Case 11: Very small numbers
        test_case(0.0000001, 0.0000002, 1'b1, "Very small: 0.0000001 <= 0.0000002");
        test_case(0.0000002, 0.0000001, 1'b0, "Very small: 0.0000002 > 0.0000001");
        
        // Test Case 12: Edge case - maximum positive
        test_case(2147483647.999999, 2147483647.999999, 1'b1, "Max positive equal");
        test_case(2147483647.999999, 2147483647.999998, 1'b0, "Max positive greater");
        
        // Test Case 13: Edge case - minimum negative
        test_case(-2147483648.0, -2147483648.0, 1'b1, "Min negative equal");
        test_case(-2147483647.0, -2147483648.0, 1'b0, "Min negative greater");
        
        // Test Case 14: Fractional precision test
        test_case(1.0, 1.00000000023283064365386962890625, 1'b1, "Frac precision: 1.0 <= 1.0+1LSB");
        test_case(1.00000000023283064365386962890625, 1.0, 1'b0, "Frac precision: 1.0+1LSB > 1.0");
        
        // Test Case 15: Reset behavior test
        $display("Testing reset behavior...");
        feature = fp_to_q32_32(5.0);
        threshold = fp_to_q32_32(3.0);
        en = 1'b1;
        @(posedge clk);
        wait(compare_done);
        @(posedge clk);
        
        // Apply reset
        rst_n = 1'b0;
        @(posedge clk);
        @(posedge clk);
        
        // Check if outputs are reset
        if (go_left == 1'b0 && compare_done == 1'b0) begin
            $display("PASS: Reset behavior test");
            test_count = test_count + 1;
            passed_count = passed_count + 1;
        end else begin
            $display("FAIL: Reset behavior test");
            $display("  Expected go_left: 0, Got: %b", go_left);
            $display("  Expected compare_done: 0, Got: %b", compare_done);
            test_count = test_count + 1;
        end
        
        // Restore reset
        rst_n = 1'b1;
        @(posedge clk);
        
        // Test Case 16: Enable/Disable behavior
        $display("Testing enable/disable behavior...");
        feature = fp_to_q32_32(2.0);
        threshold = fp_to_q32_32(1.0);
        en = 1'b0; // Disabled
        @(posedge clk);
        @(posedge clk);
        
        if (go_left == 1'b0 && compare_done == 1'b0) begin
            $display("PASS: Disabled state test");
            test_count = test_count + 1;
            passed_count = passed_count + 1;
        end else begin
            $display("FAIL: Disabled state test");
            $display("  Expected go_left: 0, Got: %b", go_left);
            $display("  Expected compare_done: 0, Got: %b", compare_done);
            test_count = test_count + 1;
        end
        
        // Wait a bit more for final propagation
        @(posedge clk);
        @(posedge clk);
        
        // Print test summary
        $display("==========================================");
        $display("Test Summary:");
        $display("Total tests: %d", test_count);
        $display("Passed: %d", passed_count);
        $display("Failed: %d", test_count - passed_count);
        if (passed_count == test_count) begin
            $display("ALL TESTS PASSED!");
        end else begin
            $display("SOME TESTS FAILED!");
        end
        $display("==========================================");
        
        $finish;
    end
    
    // Generate VCD file for waveform viewing
    initial begin
        $dumpfile("tb_q32_comparator.vcd");
        $dumpvars(0, tb_q32_comparator);
    end

endmodule
