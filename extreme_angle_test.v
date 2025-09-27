// Extreme Angle Test for CORDIC - Testing angles beyond ±720°
// This testbench specifically targets very large angle inputs

`timescale 1ns / 1ps

module extreme_angle_test;

// Parameters
parameter WIDTH = 16;
parameter ITERATIONS = 15;
parameter ANGLE_WIDTH = 32;
parameter CLOCK_PERIOD = 10;

// Testbench signals
reg clock, reset, start;
reg signed [WIDTH-1:0] x_start, y_start;
reg signed [ANGLE_WIDTH-1:0] angle;
wire signed [WIDTH-1:0] cosine, sine;
wire done;

// Test parameters
localparam signed [WIDTH-1:0] CORDIC_GAIN = 16'h26DD;
localparam real PI = 3.14159265359;
localparam real ANGLE_SCALE = 2.0**(ANGLE_WIDTH-3);
localparam real COORD_SCALE = 2.0**(WIDTH-2);

// Extreme test angles in degrees
real extreme_angles [0:19] = {
    // Very large positive angles
    720.0,    // 2π (should = 0°)
    1080.0,   // 3π (should = 180°)
    1440.0,   // 4π (should = 0°)
    1800.0,   // 5π (should = 180°)
    3600.0,   // 10π (should = 0°)
    7200.0,   // 20π (should = 0°)
    
    // Very large negative angles  
    -720.0,   // -2π (should = 0°)
    -1080.0,  // -3π (should = 180°)
    -1440.0,  // -4π (should = 0°)
    -1800.0,  // -5π (should = 180°)
    -3600.0,  // -10π (should = 0°)
    
    // Mixed large angles
    1890.0,   // 5.25π (should = 90°)
    2250.0,   // 6.25π (should = 90°)
    -1350.0,  // -3.75π (should = 90°)
    -2610.0,  // -7.25π (should = 90°)
    
    // Extreme values near bit limits
    5760.0,   // 16π
    -5760.0,  // -16π
    11520.0,  // 32π
    -11520.0  // -32π
};

// Expected results (equivalent angles in [0°, 360°))
real expected_equivalent [0:19] = {
    0.0, 180.0, 0.0, 180.0, 0.0, 0.0,           // Large positive
    0.0, 180.0, 0.0, 180.0, 0.0,                // Large negative
    90.0, 90.0, 90.0, 90.0,                     // Mixed large
    0.0, 0.0, 0.0, 0.0                         // Extreme values
};

// DUT instantiation
CORDIC #(
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

// Convert fixed-point to real
function real fixed_to_real;
    input signed [WIDTH-1:0] fixed_val;
    begin
        fixed_to_real = $itor(fixed_val) / COORD_SCALE;
    end
endfunction

// Convert degrees to fixed-point angle
function signed [ANGLE_WIDTH-1:0] deg_to_angle;
    input real deg_val;
    real rad_val;
    begin
        rad_val = deg_val * PI / 180.0;
        deg_to_angle = $rtoi(rad_val * ANGLE_SCALE);
    end
endfunction

// Test task for extreme angles
task test_extreme_angle;
    input real test_angle_deg;
    input real expected_equiv_deg;
    input integer test_num;
    
    real expected_cos, expected_sin;
    real actual_cos, actual_sin;
    real error_cos, error_sin, max_error;
    real equiv_rad;
    integer cycle_count;
    
    begin
        equiv_rad = expected_equiv_deg * PI / 180.0;
        expected_cos = $cos(equiv_rad);
        expected_sin = $sin(equiv_rad);
        
        // Setup test
        x_start = CORDIC_GAIN;
        y_start = 0;
        angle = deg_to_angle(test_angle_deg);
        
        $display("Test %0d: Input=%.1f° (Expected equivalent=%.1f°)", 
                 test_num, test_angle_deg, expected_equiv_deg);
        $display("  Angle fixed-point: 0x%08X", angle);
        
        // Start computation
        cycle_count = 0;
        @(posedge clock);
        start = 1;
        @(posedge clock);
        start = 0;
        
        // Wait for completion with cycle counting
        while (!done) begin
            @(posedge clock);
            cycle_count = cycle_count + 1;
            if (cycle_count > 100) begin
                $display("  ERROR: Timeout waiting for computation!");
                $finish;
            end
        end
        
        // Get results
        actual_cos = fixed_to_real(cosine);
        actual_sin = fixed_to_real(sine);
        
        error_cos = $abs(actual_cos - expected_cos);
        error_sin = $abs(actual_sin - expected_sin);
        max_error = (error_cos > error_sin) ? error_cos : error_sin;
        
        // Report results
        $display("  Cycles: %0d | Cos: Exp=%.6f, Act=%.6f, Err=%.6f | Sin: Exp=%.6f, Act=%.6f, Err=%.6f", 
                 cycle_count, expected_cos, actual_cos, error_cos, expected_sin, actual_sin, error_sin);
        
        if (max_error < 0.01) begin
            $display("  PASS: Maximum error %.6f < 0.01", max_error);
        end else begin
            $display("  FAIL: Maximum error %.6f >= 0.01", max_error);
        end
        $display("");
        
        @(posedge clock);
    end
endtask

// Main test sequence
initial begin
    integer i;
    
    // Initialize
    reset = 1;
    start = 0;
    x_start = 0;
    y_start = 0;
    angle = 0;
    
    $display("=== CORDIC Extreme Angle Test ===");
    $display("Testing angles beyond ±720° for unlimited range support");
    $display("Parameters: WIDTH=%0d, ITERATIONS=%0d, ANGLE_WIDTH=%0d\n", WIDTH, ITERATIONS, ANGLE_WIDTH);
    
    // Reset sequence
    #(CLOCK_PERIOD * 5);
    reset = 0;
    #(CLOCK_PERIOD * 2);
    
    // Run extreme angle tests
    for (i = 0; i < 20; i = i + 1) begin
        test_extreme_angle(extreme_angles[i], expected_equivalent[i], i + 1);
    end
    
    // Test some truly extreme cases
    $display("=== Ultra-Extreme Angle Tests ===");
    test_extreme_angle(36000.0, 0.0, 21);    // 100π
    test_extreme_angle(-36000.0, 0.0, 22);   // -100π
    test_extreme_angle(64800.0, 0.0, 23);    // 180π  
    test_extreme_angle(-64800.0, 0.0, 24);   // -180π
    
    $display("=== Test Complete ===");
    $display("All extreme angle tests finished!");
    $display("Check individual test results above for pass/fail status.");
    
    $finish;
end

// Timeout protection
initial begin
    #(CLOCK_PERIOD * 50000);
    $display("ERROR: Simulation timeout!");
    $finish;
end

endmodule