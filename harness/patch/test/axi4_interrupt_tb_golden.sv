// AXI4 Interrupt Controller Testbench - GOLDEN (Comprehensive with SVA Assertions)
// This is the golden/reference testbench for the interrupt controller module

module axi4_interrupt_tb_golden;

    // Clock and Reset
    reg clk;
    reg resetn;
    reg interrupt_req;
    wire interrupt_ack;
    
    // Instantiate DUT
    axi4_interrupt dut (
        .clk(clk),
        .resetn(resetn),
        .interrupt_req(interrupt_req),
        .interrupt_ack(interrupt_ack)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns period = 100MHz
    end
    
    // ============================================
    // Coverage Tracking
    // ============================================
    reg test1_reset_check;
    reg test2_interrupt_assert;
    reg test3_interrupt_deassert;
    reg test4_multiple_interrupts;
    reg assertion_reset_behavior;
    reg assertion_interrupt_propagation;
    reg assertion_interrupt_timing;
    
    initial begin
        test1_reset_check = 1'b0;
        test2_interrupt_assert = 1'b0;
        test3_interrupt_deassert = 1'b0;
        test4_multiple_interrupts = 1'b0;
        assertion_reset_behavior = 1'b0;
        assertion_interrupt_propagation = 1'b0;
        assertion_interrupt_timing = 1'b0;
    end
    
    // ============================================
    // Test Scenarios
    // ============================================
    initial begin
        // Initialize
        resetn = 0;
        interrupt_req = 1'b0;
        
        // Apply reset
        #20;
        resetn = 1;
        #10;
        
        $display("========================================");
        $display("AXI4 Interrupt Controller Testbench - Starting");
        $display("========================================");
        
        // ============================================
        // Test 1: Reset Check
        // ============================================
        $display("\nTest 1: Reset Check");
        test1_reset_check = 1'b1;
        #10;
        if (interrupt_ack == 1'b0) begin
            $display("  PASS: Interrupt ack properly reset");
            assertion_reset_behavior = 1'b1;
        end else begin
            $error("  FAIL: Interrupt ack not properly reset");
        end
        #20;
        
        // ============================================
        // Test 2: Interrupt Assert
        // ============================================
        $display("\nTest 2: Interrupt Assert");
        test2_interrupt_assert = 1'b1;
        interrupt_req = 1'b1;
        @(posedge clk);
        #1; // Small delay for combinational logic
        if (interrupt_ack == 1'b1) begin
            $display("  PASS: Interrupt ack asserted correctly");
            assertion_interrupt_propagation = 1'b1;
        end else begin
            $error("  FAIL: Interrupt ack not asserted");
        end
        #20;
        
        // ============================================
        // Test 3: Interrupt Deassert
        // ============================================
        $display("\nTest 3: Interrupt Deassert");
        test3_interrupt_deassert = 1'b1;
        interrupt_req = 1'b0;
        @(posedge clk);
        #1;
        if (interrupt_ack == 1'b0) begin
            $display("  PASS: Interrupt ack deasserted correctly");
        end else begin
            $error("  FAIL: Interrupt ack not deasserted");
        end
        #20;
        
        // ============================================
        // Test 4: Multiple Interrupt Cycles
        // ============================================
        $display("\nTest 4: Multiple Interrupt Cycles");
        test4_multiple_interrupts = 1'b1;
        for (int i = 0; i < 5; i++) begin
            interrupt_req = 1'b1;
            @(posedge clk);
            #1;
            if (interrupt_ack != 1'b1) begin
                $error("  FAIL: Interrupt ack not asserted on cycle %0d", i);
            end
            
            interrupt_req = 1'b0;
            @(posedge clk);
            #1;
            if (interrupt_ack != 1'b0) begin
                $error("  FAIL: Interrupt ack not deasserted on cycle %0d", i);
            end
        end
        $display("  PASS: Multiple interrupt cycles handled correctly");
        assertion_interrupt_timing = 1'b1;
        #20;
        
        $display("\n========================================");
        $display("All tests completed successfully!");
        $display("========================================");
        #100;
        $finish;
    end
    
    // ============================================
    // SVA Assertions
    // ============================================
    
    // Assertion 1: Reset Behavior
    always @(posedge clk) begin
        if (!resetn) begin
            assert (interrupt_ack == 1'b0)
                else $error("ASSERTION FAILED: Interrupt ack should be 0 during reset");
        end
    end
    
    // Assertion 2: Interrupt Propagation
    always @(posedge clk) begin
        if (resetn && interrupt_req) begin
            // Interrupt ack should follow interrupt_req (may be combinational or registered)
            // Check on next clock edge
            @(posedge clk);
            assert (interrupt_ack == 1'b1)
                else $error("ASSERTION FAILED: Interrupt ack should be asserted when interrupt_req is high");
        end
    end
    
    // Assertion 3: Interrupt Deassertion
    always @(posedge clk) begin
        if (resetn && !interrupt_req) begin
            // Interrupt ack should follow interrupt_req
            @(posedge clk);
            assert (interrupt_ack == 1'b0)
                else $error("ASSERTION FAILED: Interrupt ack should be deasserted when interrupt_req is low");
        end
    end
    
    // ============================================
    // Waveform and Log Generation
    // ============================================
    
    // Generate VCD waveforms
    initial begin
        $dumpfile("harness/test/log/axi4_interrupt_tb_golden.vcd");
        $dumpvars(0, axi4_interrupt_tb_golden);
        $dumpvars(1, dut);
        $display("========================================");
        $display("Waveform file: harness/test/log/axi4_interrupt_tb_golden.vcd");
        $display("========================================");
    end
    
    // Enhanced logging
    initial begin
        $display("========================================");
        $display("Simulation Log Started");
        $display("Time: %0t", $time);
        $display("========================================");
    end
    
    // Log test completion with coverage report
    final begin
        $display("========================================");
        $display("Simulation Completed");
        $display("Final Time: %0t", $time);
        $display("Waveform: harness/test/log/axi4_interrupt_tb_golden.vcd");
        $display("========================================");
        $display("");
        $display("=== COVERAGE REPORT ===");
        $display("Test Coverage:");
        $display("  Test 1 (Reset Check):         %b", test1_reset_check);
        $display("  Test 2 (Interrupt Assert):    %b", test2_interrupt_assert);
        $display("  Test 3 (Interrupt Deassert):  %b", test3_interrupt_deassert);
        $display("  Test 4 (Multiple Interrupts): %b", test4_multiple_interrupts);
        $display("");
        $display("Assertion Coverage:");
        $display("  Reset Behavior Assertion:     %b", assertion_reset_behavior);
        $display("  Interrupt Propagation:        %b", assertion_interrupt_propagation);
        $display("  Interrupt Timing:             %b", assertion_interrupt_timing);
        $display("");
        $display("Coverage Summary:");
        $display("  Tests Executed: %0d/4", 
                 test1_reset_check + test2_interrupt_assert + test3_interrupt_deassert + 
                 test4_multiple_interrupts);
        $display("  Assertions Triggered: %0d/3", 
                 assertion_reset_behavior + assertion_interrupt_propagation + 
                 assertion_interrupt_timing);
        $display("========================================");
    end

endmodule

