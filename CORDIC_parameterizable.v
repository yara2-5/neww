// Fully Parameterizable CORDIC Implementation
// Supports any ANGLE_WIDTH and automatically scales all constants

module CORDIC_parameterizable #(
    parameter WIDTH = 16,           // Data width for coordinates
    parameter ITERATIONS = 15,      // Number of CORDIC iterations  
    parameter ANGLE_WIDTH = 32,     // Angle width in bits (fully parameterizable)
    parameter FRAC_BITS = ANGLE_WIDTH - 3  // Fractional bits in angle representation
)(
    input wire clock,
    input wire reset,
    input wire start,
    input wire signed [WIDTH-1:0] x_start,     
    input wire signed [WIDTH-1:0] y_start,     
    input wire signed [ANGLE_WIDTH-1:0] angle, 
    output reg signed [WIDTH-1:0] cosine,      
    output reg signed [WIDTH-1:0] sine,        
    output reg done                            
);

// Generate angle scaling factor based on ANGLE_WIDTH
localparam real ANGLE_SCALE_REAL = 2.0**(FRAC_BITS);

// Generate CORDIC gain for the specified WIDTH
function real calculate_cordic_gain;
    input integer iterations;
    integer i;
    real gain;
    begin
        gain = 1.0;
        for (i = 0; i < iterations; i = i + 1) begin
            gain = gain * sqrt(1.0 + 2.0**(-2*i));
        end
        calculate_cordic_gain = 1.0 / gain;
    end
endfunction

// Calculate scaled constants based on ANGLE_WIDTH
function signed [ANGLE_WIDTH-1:0] scale_angle_constant;
    input real angle_radians;
    begin
        scale_angle_constant = $rtoi(angle_radians * ANGLE_SCALE_REAL);
    end
endfunction

// Dynamic constant generation
localparam signed [WIDTH-1:0] CORDIC_GAIN = $rtoi(calculate_cordic_gain(ITERATIONS) * (2.0**(WIDTH-2)));

// Parameterizable angle constants
localparam signed [ANGLE_WIDTH-1:0] PI = scale_angle_constant(3.14159265358979323846);
localparam signed [ANGLE_WIDTH-1:0] PI_2 = scale_angle_constant(1.57079632679489661923);
localparam signed [ANGLE_WIDTH-1:0] PI_3_2 = scale_angle_constant(4.71238898038468985769);
localparam signed [ANGLE_WIDTH-1:0] TWO_PI = scale_angle_constant(6.28318530717958647692);

// Generate arctangent lookup table dynamically
function signed [ANGLE_WIDTH-1:0] generate_atan_value;
    input integer iteration;
    real atan_val;
    begin
        atan_val = atan(2.0**(-iteration));
        generate_atan_value = $rtoi(atan_val * ANGLE_SCALE_REAL);
    end
endfunction

// Generate the lookup table for the current parameters
reg signed [ANGLE_WIDTH-1:0] ATAN_TABLE [0:ITERATIONS-1];

// Initialize lookup table in initial block
initial begin
    integer i;
    for (i = 0; i < ITERATIONS; i = i + 1) begin
        ATAN_TABLE[i] = generate_atan_value(i);
    end
    
    // Display generated constants for verification
    $display("CORDIC Parameters for ANGLE_WIDTH=%0d:", ANGLE_WIDTH);
    $display("  ANGLE_SCALE: 2^%0d = %0d", FRAC_BITS, $rtoi(ANGLE_SCALE_REAL));
    $display("  PI = 0x%0X", PI);
    $display("  TWO_PI = 0x%0X", TWO_PI);
    $display("  CORDIC_GAIN = 0x%0X", CORDIC_GAIN);
    $display("  ATAN_TABLE[0] = 0x%0X (45°)", ATAN_TABLE[0]);
end

// Calculate maximum reduction levels based on ANGLE_WIDTH
function integer get_max_reduction_levels;
    input integer angle_width;
    begin
        // Calculate how many powers of 2 we can use for reduction
        // Limited by the maximum representable angle
        get_max_reduction_levels = (angle_width - 4); // Conservative estimate
    end
endfunction

localparam MAX_REDUCTION_LEVELS = get_max_reduction_levels(ANGLE_WIDTH);

// Internal registers
reg signed [WIDTH-1:0] x [0:ITERATIONS];
reg signed [WIDTH-1:0] y [0:ITERATIONS];
reg signed [ANGLE_WIDTH-1:0] z [0:ITERATIONS];
reg [4:0] iteration_counter;

// Enhanced angle normalization
reg signed [ANGLE_WIDTH-1:0] temp_angle;
reg signed [ANGLE_WIDTH-1:0] normalized_angle;
reg x_sign, y_sign;
reg computing;

// State machine
localparam IDLE = 2'b00, NORMALIZE = 2'b01, COMPUTE = 2'b10, FINISH = 2'b11;
reg [1:0] state;

// Parameterizable angle reduction
always @(posedge clock or posedge reset) begin
    if (reset) begin
        state <= IDLE;
        iteration_counter <= 0;
        done <= 0;
        cosine <= 0;
        sine <= 0;
        computing <= 0;
        temp_angle <= 0;
        x_sign <= 0;
        y_sign <= 0;
    end else begin
        case (state)
            IDLE: begin
                done <= 0;
                if (start) begin
                    temp_angle <= angle;
                    state <= NORMALIZE;
                    computing <= 1;
                end
            end
            
            NORMALIZE: begin
                // Parameterizable angle normalization
                // Dynamically determine reduction based on ANGLE_WIDTH
                
                // Generate reduction values dynamically
                reg signed [ANGLE_WIDTH-1:0] reduction_16_pi;
                reg signed [ANGLE_WIDTH-1:0] reduction_8_pi;
                reg signed [ANGLE_WIDTH-1:0] reduction_4_pi;
                reg signed [ANGLE_WIDTH-1:0] reduction_2_pi;
                
                reduction_16_pi = TWO_PI << 3;  // 16π
                reduction_8_pi = TWO_PI << 2;   // 8π  
                reduction_4_pi = TWO_PI << 1;   // 4π
                reduction_2_pi = TWO_PI;        // 2π
                
                // Apply largest possible reduction first
                if (MAX_REDUCTION_LEVELS >= 4 && temp_angle >= reduction_16_pi) begin
                    temp_angle <= temp_angle - reduction_16_pi;
                end else if (MAX_REDUCTION_LEVELS >= 4 && temp_angle <= -reduction_16_pi) begin
                    temp_angle <= temp_angle + reduction_16_pi;
                end else if (MAX_REDUCTION_LEVELS >= 3 && temp_angle >= reduction_8_pi) begin
                    temp_angle <= temp_angle - reduction_8_pi;
                end else if (MAX_REDUCTION_LEVELS >= 3 && temp_angle <= -reduction_8_pi) begin
                    temp_angle <= temp_angle + reduction_8_pi;
                end else if (MAX_REDUCTION_LEVELS >= 2 && temp_angle >= reduction_4_pi) begin
                    temp_angle <= temp_angle - reduction_4_pi;
                end else if (MAX_REDUCTION_LEVELS >= 2 && temp_angle <= -reduction_4_pi) begin
                    temp_angle <= temp_angle + reduction_4_pi;
                end else if (temp_angle >= reduction_2_pi) begin
                    temp_angle <= temp_angle - reduction_2_pi;
                end else if (temp_angle <= -reduction_2_pi) begin
                    temp_angle <= temp_angle + reduction_2_pi;
                end else begin
                    // Angle normalized to [-2π, 2π], apply quadrant correction
                    x_sign <= 0;
                    y_sign <= 0;
                    
                    if ((temp_angle > PI_2) && (temp_angle <= PI)) begin
                        normalized_angle <= PI - temp_angle;
                        x_sign <= 1;
                    end else if ((temp_angle > PI) && (temp_angle <= PI_3_2)) begin
                        normalized_angle <= temp_angle - PI;
                        x_sign <= 1;
                        y_sign <= 1;
                    end else if (temp_angle > PI_3_2) begin
                        normalized_angle <= TWO_PI - temp_angle;
                        y_sign <= 1;
                    end else if (temp_angle < -PI_2) begin
                        if (temp_angle >= -PI) begin
                            normalized_angle <= -PI - temp_angle;
                            x_sign <= 1;
                            y_sign <= 1;
                        end else begin
                            normalized_angle <= temp_angle + PI;
                            x_sign <= 1;
                        end
                    end else begin
                        normalized_angle <= temp_angle;
                    end
                    
                    // Initialize CORDIC
                    x[0] <= x_start;
                    y[0] <= y_start;
                    z[0] <= normalized_angle;
                    iteration_counter <= 0;
                    state <= COMPUTE;
                end
            end
            
            COMPUTE: begin
                if (iteration_counter < ITERATIONS) begin
                    if (z[iteration_counter] >= 0) begin
                        x[iteration_counter + 1] <= x[iteration_counter] - (y[iteration_counter] >>> iteration_counter);
                        y[iteration_counter + 1] <= y[iteration_counter] + (x[iteration_counter] >>> iteration_counter);
                        z[iteration_counter + 1] <= z[iteration_counter] - ATAN_TABLE[iteration_counter];
                    end else begin
                        x[iteration_counter + 1] <= x[iteration_counter] + (y[iteration_counter] >>> iteration_counter);
                        y[iteration_counter + 1] <= y[iteration_counter] - (x[iteration_counter] >>> iteration_counter);
                        z[iteration_counter + 1] <= z[iteration_counter] + ATAN_TABLE[iteration_counter];
                    end
                    iteration_counter <= iteration_counter + 1;
                end else begin
                    state <= FINISH;
                end
            end
            
            FINISH: begin
                cosine <= x_sign ? -x[ITERATIONS] : x[ITERATIONS];
                sine <= y_sign ? -y[ITERATIONS] : y[ITERATIONS];
                done <= 1;
                computing <= 0;
                state <= IDLE;
            end
        endcase
    end
end

endmodule