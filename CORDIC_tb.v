// CORDIC Testbench - Comprehensive self-checking verification
// Tests corner cases, overflow/underflow, random angles, and boundary conditions

`timescale 1ns / 1ps

module CORDIC_tb;

// Parameters matching the DUT
parameter WIDTH = 16;
parameter ITERATIONS = 15;
parameter ANGLE_WIDTH = 32;
parameter CLOCK_PERIOD = 10; // 100 MHz clock

// Testbench signals
reg clock;
reg reset;
reg start;
reg signed [WIDTH-1:0] x_start;
reg signed [WIDTH-1:0] y_start;
reg signed [ANGLE_WIDTH-1:0] angle;
wire signed [WIDTH-1:0] cosine;
wire signed [WIDTH-1:0] sine;
wire done;

// Test control variables
integer test_count;
integer pass_count;
integer fail_count;
real tolerance;
real angle_degrees;
real expected_cos, expected_sin;
real actual_cos, actual_sin;
real error_cos, error_sin;

// CORDIC gain factor for x_start initialization
localparam signed [WIDTH-1:0] CORDIC_GAIN = 16'h26DD; // ≈ 0.6072529350 * 2^14

// Angle conversion constants
localparam real PI = 3.14159265359;
localparam real ANGLE_SCALE = 2.0**(ANGLE_WIDTH-3); // Scale factor for fixed-point angles
localparam real COORD_SCALE = 2.0**(WIDTH-2);       // Scale factor for coordinates

// Test angles in degrees
real test_angles_deg [0:19] = {
    0.0, 30.0, 45.0, 60.0, 90.0,     // First quadrant
    120.0, 135.0, 150.0, 180.0,      // Second quadrant  
    210.0, 225.0, 240.0, 270.0,      // Third quadrant
    300.0, 315.0, 330.0, 360.0,      // Fourth quadrant
    450.0, -90.0, -180.0             // Overflow/underflow tests
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

// Convert real to fixed-point angle
function signed [ANGLE_WIDTH-1:0] real_to_angle;
    input real real_val;
    begin
        real_to_angle = $rtoi(real_val * ANGLE_SCALE);
    end
endfunction

// Test procedure
task run_test;
    input real test_angle_deg;
    input string test_name;
    
    real angle_rad;
    real max_error;
    
    begin
        angle_rad = test_angle_deg * PI / 180.0;
        
        // Set up test inputs
        x_start = CORDIC_GAIN;
        y_start = 0;
        angle = real_to_angle(angle_rad);
        
        // Start computation
        @(posedge clock);
        start = 1;
        @(posedge clock);
        start = 0;
        
        // Wait for completion
        wait(done);
        @(posedge clock);
        
        // Calculate expected values
        expected_cos = $cos(angle_rad);
        expected_sin = $sin(angle_rad);
        
        // Get actual values from DUT
        actual_cos = fixed_to_real(cosine);
        actual_sin = fixed_to_real(sine);
        
        // Calculate errors
        error_cos = $abs(actual_cos - expected_cos);
        error_sin = $abs(actual_sin - expected_sin);
        max_error = (error_cos > error_sin) ? error_cos : error_sin;
        
        // Check if test passes
        test_count = test_count + 1;
        if (max_error < tolerance) begin
            pass_count = pass_count + 1;
            $display("PASS: %s | Angle: %0.1f° | Cos: Expected=%0.6f, Actual=%0.6f, Error=%0.6f | Sin: Expected=%0.6f, Actual=%0.6f, Error=%0.6f", 
                     test_name, test_angle_deg, expected_cos, actual_cos, error_cos, expected_sin, actual_sin, error_sin);
        end else begin
            fail_count = fail_count + 1;
            $display("FAIL: %s | Angle: %0.1f° | Cos: Expected=%0.6f, Actual=%0.6f, Error=%0.6f | Sin: Expected=%0.6f, Actual=%0.6f, Error=%0.6f", 
                     test_name, test_angle_deg, expected_cos, actual_cos, error_cos, expected_sin, actual_sin, error_sin);
        end
    end
endtask

// Random test generation
task run_random_tests;
    input integer num_tests;
    
    integer i;
    real random_angle;
    string test_name;
    
    begin
        $display("\n=== Random Angle Tests ===");
        for (i = 0; i < num_tests; i = i + 1) begin
            random_angle = ($random % 7200) / 10.0 - 360.0; // Random angle from -360° to +360°
            $sformat(test_name, "Random_%0d", i);
            run_test(random_angle, test_name);
        end
    end
endtask

// Boundary condition tests
task run_boundary_tests;
    real max_angle, min_angle;
    begin
        $display("\n=== Boundary Condition Tests ===");
        
        // Test maximum representable angle
        max_angle = (2.0**(ANGLE_WIDTH-1) - 1) / ANGLE_SCALE * 180.0 / PI;
        run_test(max_angle, "Max_Angle");
        
        // Test minimum representable angle  
        min_angle = -(2.0**(ANGLE_WIDTH-1)) / ANGLE_SCALE * 180.0 / PI;
        run_test(min_angle, "Min_Angle");
        
        // Test near-zero angles
        run_test(0.001, "Near_Zero_Pos");
        run_test(-0.001, "Near_Zero_Neg");
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
    test_count = 0;
    pass_count = 0;
    fail_count = 0;
    tolerance = 0.01; // 1% tolerance for CORDIC approximation
    
    $display("=== CORDIC Testbench Starting ===");
    $display("Parameters: WIDTH=%0d, ITERATIONS=%0d, ANGLE_WIDTH=%0d", WIDTH, ITERATIONS, ANGLE_WIDTH);
    $display("Tolerance: %0.4f", tolerance);
    
    // Reset sequence
    #(CLOCK_PERIOD * 5);
    reset = 0;
    #(CLOCK_PERIOD * 2);
    
    // Corner cases test
    $display("\n=== Corner Cases Tests ===");
    for (i = 0; i < 20; i = i + 1) begin
        $sformat(test_name, "Corner_%0d", i);
        run_test(test_angles_deg[i], test_name);
    end
    
    // Random tests
    run_random_tests(50);
    
    // Boundary tests
    run_boundary_tests();
    
    // Final results
    $display("\n=== Test Results Summary ===");
    $display("Total Tests: %0d", test_count);
    $display("Passed: %0d", pass_count);
    $display("Failed: %0d", fail_count);
    $display("Pass Rate: %0.1f%%", (pass_count * 100.0) / test_count);
    
    if (fail_count == 0) begin
        $display("*** ALL TESTS PASSED ***");
    end else begin
        $display("*** SOME TESTS FAILED ***");
    end
    
    // Calculate accuracy metrics
    $display("\n=== Accuracy Analysis ===");
    $display("CORDIC provides approximately %0d bits of accuracy", $clog2($rtoi(1.0/tolerance)));
    $display("Expected accuracy for %0d iterations: ~%0.1f bits", ITERATIONS, ITERATIONS * 0.5);
    
    $finish;
end

// Simulation timeout
initial begin
    #(CLOCK_PERIOD * 100000);
    $display("ERROR: Simulation timeout!");
    $finish;
end

// Waveform dump (for debugging)
initial begin
    $dumpfile("cordic_tb.vcd");
    $dumpvars(0, CORDIC_tb);
end

endmodule