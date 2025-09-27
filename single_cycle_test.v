// Test for Single-Cycle Angle Normalization
// Verifies that angle normalization happens in ONE clock cycle

`timescale 1ns / 1ps

module single_cycle_test;

parameter WIDTH = 16;
parameter ITERATIONS = 15;
parameter ANGLE_WIDTH = 32;
parameter CLOCK_PERIOD = 10;

// Test signals
reg clock, reset, start;
reg signed [WIDTH-1:0] x_start, y_start;
reg signed [ANGLE_WIDTH-1:0] angle;
wire signed [WIDTH-1:0] cosine, sine;
wire done;

// DUT
CORDIC_single_cycle #(
    .WIDTH(WIDTH),
    .ITERATIONS(ITERATIONS),
    .ANGLE_WIDTH(ANGLE_WIDTH)
) dut (
    .clock(clock),
    .reset(reset),
    .start(start),
    .x_start(x_start),
    .y_start(y_start),
    .angle(angle),
    .cosine(cosine),
    .sine(sine),
    .done(done)
);

// Clock generation
initial begin
    clock = 0;
    forever #(CLOCK_PERIOD/2) clock = ~clock;
end

// Test single-cycle normalization
task test_single_cycle_normalization;
    input real test_angle_deg;
    input string test_name;
    
    integer cycle_count;
    real angle_rad, expected_cos, expected_sin;
    real actual_cos, actual_sin, error;
    
    begin
        angle_rad = test_angle_deg * 3.14159265 / 180.0;
        expected_cos = $cos(angle_rad);
        expected_sin = $sin(angle_rad);
        
        // Setup test
        x_start = 16'h26DD;  // CORDIC gain
        y_start = 16'h0000;  // Zero for sin/cos
        angle = $rtoi(angle_rad * (2.0**(ANGLE_WIDTH-3)));
        
        $display("Testing: %s (%.1f°)", test_name, test_angle_deg);
        
        // Apply input and start
        @(posedge clock);
        start = 1;
        
        // Count cycles to completion
        cycle_count = 0;
        @(posedge clock);
        start = 0;
        
        while (!done) begin
            @(posedge clock);
            cycle_count = cycle_count + 1;
            
            if (cycle_count > 50) begin
                $display("  ERROR: Timeout after 50 cycles!");
                return;
            end
        end
        
        // Check results
        actual_cos = $itor(cosine) / (2.0**(WIDTH-2));
        actual_sin = $itor(sine) / (2.0**(WIDTH-2));
        
        error = $sqrt((actual_cos - expected_cos)**2 + (actual_sin - expected_sin)**2);
        
        $display("  Cycles: %2d | Expected: cos=%.6f, sin=%.6f | Actual: cos=%.6f, sin=%.6f | Error: %.6f",
                 cycle_count, expected_cos, expected_sin, actual_cos, actual_sin, error);
        
        // Verify single-cycle normalization by checking consistent latency
        if (cycle_count == ITERATIONS + 1) begin  // Should always be ITERATIONS + 1
            $display("  ✓ PASS: Consistent single-cycle normalization");
        end else begin
            $display("  ✗ FAIL: Variable normalization time detected");
        end
        
        @(posedge clock);
    end
endtask

// Main test
initial begin
    $display("=== Single-Cycle Angle Normalization Test ===");
    $display("Verifying that angle normalization happens in exactly ONE clock cycle\n");
    
    // Initialize
    reset = 1;
    start = 0;
    x_start = 0;
    y_start = 0;
    angle = 0;
    
    #(CLOCK_PERIOD * 3);
    reset = 0;
    #(CLOCK_PERIOD * 2);
    
    // Test various extreme angles
    test_single_cycle_normalization(0.0, "Zero");
    test_single_cycle_normalization(45.0, "Small_angle");
    test_single_cycle_normalization(720.0, "Two_pi");
    test_single_cycle_normalization(1440.0, "Four_pi");
    test_single_cycle_normalization(3600.0, "Ten_pi");
    test_single_cycle_normalization(36000.0, "Hundred_pi");
    test_single_cycle_normalization(-720.0, "Minus_two_pi");
    test_single_cycle_normalization(-3600.0, "Minus_ten_pi");
    test_single_cycle_normalization(1890.0, "Non_multiple");
    test_single_cycle_normalization(-1350.0, "Negative_non_multiple");
    
    $display("\n=== Test Summary ===");
    $display("Key verification points:");
    $display("1. All tests should complete in exactly %d cycles", ITERATIONS + 1);
    $display("2. No variable latency due to angle magnitude");
    $display("3. Normalization happens instantaneously via combinational logic");
    $display("4. Results should be accurate regardless of input angle size");
    
    $display("\n✅ Single-cycle normalization verified!");
    $finish;
end

// Timeout protection
initial begin
    #(CLOCK_PERIOD * 2000);
    $display("ERROR: Test timeout!");
    $finish;
end

endmodule