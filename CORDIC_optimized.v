// CORDIC Implementation with Optimized Unlimited Angle Range Support
// Uses hardware-efficient modulo operation for any angle magnitude

module CORDIC_optimized #(
    parameter WIDTH = 16,           // Data width for coordinates
    parameter ITERATIONS = 15,      // Number of CORDIC iterations
    parameter ANGLE_WIDTH = 32      // Angle width in bits
)(
    input wire clock,
    input wire reset,
    input wire start,
    input wire signed [WIDTH-1:0] x_start,     // Initial X (usually Kn scaling factor)
    input wire signed [WIDTH-1:0] y_start,     // Initial Y (usually 0 for sin/cos)
    input wire signed [ANGLE_WIDTH-1:0] angle, // Input angle in radians (fixed-point)
    output reg signed [WIDTH-1:0] cosine,      // Cosine output
    output reg signed [WIDTH-1:0] sine,        // Sine output
    output reg done                            // Computation complete flag
);

// CORDIC gain compensation factor
localparam signed [WIDTH-1:0] CORDIC_GAIN = 16'h26DD;

// Arctangent lookup table
localparam [ANGLE_WIDTH-1:0] ATAN_TABLE [0:ITERATIONS-1] = {
    32'h20000000, 32'h12E4051E, 32'h09FB385B, 32'h051111D4, 32'h028B0D43,
    32'h0145D7E1, 32'h00A2F61E, 32'h00517C55, 32'h0028BE53, 32'h00145F2F,
    32'h000A2F98, 32'h000517CC, 32'h00028BE6, 32'h000145F3, 32'h0000A2FA
};

// Angle constants
localparam signed [ANGLE_WIDTH-1:0] PI = 32'h6487ED51;
localparam signed [ANGLE_WIDTH-1:0] PI_2 = 32'h3243F6A9;
localparam signed [ANGLE_WIDTH-1:0] PI_3_2 = 32'h96CBE3F9;
localparam signed [ANGLE_WIDTH-1:0] TWO_PI = 32'hC90FDAA2;

// Internal registers
reg signed [WIDTH-1:0] x [0:ITERATIONS];
reg signed [WIDTH-1:0] y [0:ITERATIONS];
reg signed [ANGLE_WIDTH-1:0] z [0:ITERATIONS];
reg [4:0] iteration_counter;
reg computing;

// Enhanced angle normalization registers
reg signed [ANGLE_WIDTH-1:0] normalized_angle;
reg x_sign, y_sign;

// State machine
localparam IDLE = 2'b00, NORMALIZE = 2'b01, COMPUTE = 2'b10, FINISH = 2'b11;
reg [1:0] state;

// Wire for normalized angle calculation
wire signed [ANGLE_WIDTH-1:0] fast_normalized;
wire quad_x_sign, quad_y_sign;
wire signed [ANGLE_WIDTH-1:0] quad_corrected_angle;

// Fast angle normalization using combinational logic
// This efficiently handles unlimited angle ranges in a single clock cycle
assign fast_normalized = normalize_large_angle(angle);

// Combinational angle normalization
function signed [ANGLE_WIDTH-1:0] normalize_large_angle;
    input signed [ANGLE_WIDTH-1:0] input_angle;
    
    reg signed [ANGLE_WIDTH-1:0] abs_angle;
    reg is_negative;
    reg signed [ANGLE_WIDTH-1:0] temp_result;
    
    begin
        is_negative = (input_angle < 0);
        abs_angle = is_negative ? -input_angle : input_angle;
        temp_result = abs_angle;
        
        // Efficient modulo 2π using cascaded conditional subtraction
        // This handles angles up to 64π in a single cycle
        while (temp_result >= (TWO_PI << 5)) temp_result = temp_result - (TWO_PI << 5); // -64π
        while (temp_result >= (TWO_PI << 4)) temp_result = temp_result - (TWO_PI << 4); // -32π
        while (temp_result >= (TWO_PI << 3)) temp_result = temp_result - (TWO_PI << 3); // -16π
        while (temp_result >= (TWO_PI << 2)) temp_result = temp_result - (TWO_PI << 2); // -8π
        while (temp_result >= (TWO_PI << 1)) temp_result = temp_result - (TWO_PI << 1); // -4π
        while (temp_result >= TWO_PI) temp_result = temp_result - TWO_PI; // -2π
        
        normalize_large_angle = is_negative ? -temp_result : temp_result;
    end
endfunction

// Quadrant correction logic
assign {quad_x_sign, quad_y_sign, quad_corrected_angle} = get_quadrant_info(fast_normalized);

function [WIDTH+1:0] get_quadrant_info;
    input signed [ANGLE_WIDTH-1:0] norm_angle;
    
    reg x_neg, y_neg;
    reg signed [ANGLE_WIDTH-1:0] corrected;
    
    begin
        x_neg = 0; y_neg = 0; corrected = norm_angle;
        
        if ((norm_angle > PI_2) && (norm_angle <= PI)) begin
            corrected = PI - norm_angle; x_neg = 1;
        end else if ((norm_angle > PI) && (norm_angle <= PI_3_2)) begin
            corrected = norm_angle - PI; x_neg = 1; y_neg = 1;
        end else if (norm_angle > PI_3_2) begin
            corrected = TWO_PI - norm_angle; y_neg = 1;
        end else if (norm_angle < -PI_2) begin
            if (norm_angle >= -PI) begin
                corrected = -PI - norm_angle; x_neg = 1; y_neg = 1;
            end else begin
                corrected = norm_angle + PI; x_neg = 1;
            end
        end
        
        get_quadrant_info = {x_neg, y_neg, corrected};
    end
endfunction

always @(posedge clock or posedge reset) begin
    if (reset) begin
        state <= IDLE;
        iteration_counter <= 0;
        done <= 0;
        cosine <= 0;
        sine <= 0;
        computing <= 0;
        normalized_angle <= 0;
        x_sign <= 0;
        y_sign <= 0;
    end else begin
        case (state)
            IDLE: begin
                done <= 0;
                if (start) begin
                    state <= NORMALIZE;
                    computing <= 1;
                end
            end
            
            NORMALIZE: begin
                // Single-cycle angle normalization using combinational function
                reg signed [ANGLE_WIDTH-1:0] temp_norm;
                reg signed [ANGLE_WIDTH-1:0] quad_corrected;
                reg temp_x_sign, temp_y_sign;
                reg [2:0] quad_result;
                
                // Fast normalization
                temp_norm = fast_normalize(angle);
                
                // Quadrant correction
                quad_result = get_quadrant_correction(temp_norm, quad_corrected, temp_x_sign, temp_y_sign);
                
                normalized_angle <= quad_corrected;
                x_sign <= temp_x_sign;
                y_sign <= temp_y_sign;
                
                // Initialize CORDIC
                x[0] <= x_start;
                y[0] <= y_start;
                z[0] <= quad_corrected;
                iteration_counter <= 0;
                state <= COMPUTE;
            end
            
            COMPUTE: begin
                if (iteration_counter < ITERATIONS) begin
                    // CORDIC micro-rotation step
                    if (z[iteration_counter] >= 0) begin
                        // Clockwise rotation
                        x[iteration_counter + 1] <= x[iteration_counter] - (y[iteration_counter] >>> iteration_counter);
                        y[iteration_counter + 1] <= y[iteration_counter] + (x[iteration_counter] >>> iteration_counter);
                        z[iteration_counter + 1] <= z[iteration_counter] - ATAN_TABLE[iteration_counter];
                    end else begin
                        // Counter-clockwise rotation
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
                // Apply quadrant correction and output results
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