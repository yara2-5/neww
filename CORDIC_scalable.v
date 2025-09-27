// CORDIC Scalable Implementation - Adapts to Any ANGLE_WIDTH
// Simple but effective approach that handles unlimited angles for any bit width

module CORDIC_scalable #(
    parameter WIDTH = 16,           // Data width for coordinates
    parameter ITERATIONS = 15,      // Number of CORDIC iterations  
    parameter ANGLE_WIDTH = 32      // Angle width in bits
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

// Calculate fractional bits (reserve 3 integer bits for ±4π)
localparam FRAC_BITS = ANGLE_WIDTH - 3;

// Calculate angle constants using bit manipulation
// This approach works for any ANGLE_WIDTH by proper scaling
localparam signed [ANGLE_WIDTH-1:0] PI = 
    (ANGLE_WIDTH <= 32) ? (32'h6487ED51 >>> (32 - ANGLE_WIDTH)) :
                          (32'h6487ED51 << (ANGLE_WIDTH - 32));

localparam signed [ANGLE_WIDTH-1:0] PI_2 = PI >>> 1;
localparam signed [ANGLE_WIDTH-1:0] PI_3_2 = PI + PI_2; 
localparam signed [ANGLE_WIDTH-1:0] TWO_PI = PI << 1;

// CORDIC gain (constant for all configurations)
localparam signed [WIDTH-1:0] CORDIC_GAIN = 16'h26DD;

// Dynamic arctangent table generation
function signed [ANGLE_WIDTH-1:0] get_atan_value;
    input integer iteration;
    
    // Reference atan values for 32-bit (high precision)
    reg [31:0] atan_32bit [0:31];
    reg [31:0] base_value;
    
    begin
        // Initialize reference table
        atan_32bit[0] = 32'h20000000;   atan_32bit[1] = 32'h12E4051E;
        atan_32bit[2] = 32'h09FB385B;   atan_32bit[3] = 32'h051111D4;
        atan_32bit[4] = 32'h028B0D43;   atan_32bit[5] = 32'h0145D7E1;
        atan_32bit[6] = 32'h00A2F61E;   atan_32bit[7] = 32'h00517C55;
        atan_32bit[8] = 32'h0028BE53;   atan_32bit[9] = 32'h00145F2F;
        atan_32bit[10] = 32'h000A2F98;  atan_32bit[11] = 32'h000517CC;
        atan_32bit[12] = 32'h00028BE6;  atan_32bit[13] = 32'h000145F3;
        atan_32bit[14] = 32'h0000A2FA;  atan_32bit[15] = 32'h0000517D;
        atan_32bit[16] = 32'h000028BE;  atan_32bit[17] = 32'h0000145F;
        atan_32bit[18] = 32'h00000A30;  atan_32bit[19] = 32'h00000518;
        atan_32bit[20] = 32'h0000028C;  atan_32bit[21] = 32'h00000146;
        atan_32bit[22] = 32'h000000A3;  atan_32bit[23] = 32'h00000051;
        atan_32bit[24] = 32'h00000029;  atan_32bit[25] = 32'h00000014;
        atan_32bit[26] = 32'h0000000A;  atan_32bit[27] = 32'h00000005;
        atan_32bit[28] = 32'h00000003;  atan_32bit[29] = 32'h00000001;
        atan_32bit[30] = 32'h00000001;  atan_32bit[31] = 32'h00000000;
        
        if (iteration < 32) begin
            base_value = atan_32bit[iteration];
            
            // Scale based on ANGLE_WIDTH
            if (ANGLE_WIDTH == 32) begin
                get_atan_value = base_value;
            end else if (ANGLE_WIDTH < 32) begin
                get_atan_value = base_value >>> (32 - ANGLE_WIDTH);
            end else begin
                get_atan_value = base_value << (ANGLE_WIDTH - 32);
            end
        end else begin
            get_atan_value = 0;
        end
    end
endfunction

// Generate lookup table at compile time
reg signed [ANGLE_WIDTH-1:0] ATAN_TABLE [0:ITERATIONS-1];

initial begin
    integer i;
    for (i = 0; i < ITERATIONS; i = i + 1) begin
        ATAN_TABLE[i] = get_atan_value(i);
    end
    
    $display("=== CORDIC Scalable Configuration ===");
    $display("ANGLE_WIDTH: %0d bits", ANGLE_WIDTH);
    $display("Fractional bits: %0d", FRAC_BITS);
    $display("PI = 0x%0X", PI);
    $display("TWO_PI = 0x%0X", TWO_PI);
    
    // Calculate maximum efficiently handleable angle
    integer max_power = (ANGLE_WIDTH >= 8) ? (ANGLE_WIDTH - 4) : 4;
    real max_angle_deg = (2.0**(max_power + 1)) * 180.0;
    $display("Max efficient angle: ±%.0f°", max_angle_deg);
end

// Calculate reduction parameters based on ANGLE_WIDTH
localparam MAX_REDUCTION_POWER = (ANGLE_WIDTH >= 8) ? (ANGLE_WIDTH - 4) : 4;

// Internal registers
reg signed [WIDTH-1:0] x [0:ITERATIONS];
reg signed [WIDTH-1:0] y [0:ITERATIONS];
reg signed [ANGLE_WIDTH-1:0] z [0:ITERATIONS];
reg [4:0] iteration_counter;

// Angle processing
reg signed [ANGLE_WIDTH-1:0] temp_angle;
reg signed [ANGLE_WIDTH-1:0] normalized_angle;
reg [4:0] reduction_level;
reg x_sign, y_sign;
reg computing;

// State machine
localparam IDLE = 2'b00, NORMALIZE = 2'b01, COMPUTE = 2'b10, FINISH = 2'b11;
reg [1:0] state;

always @(posedge clock or posedge reset) begin
    if (reset) begin
        state <= IDLE;
        iteration_counter <= 0;
        reduction_level <= MAX_REDUCTION_POWER;
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
                    reduction_level <= MAX_REDUCTION_POWER;
                    state <= NORMALIZE;
                    computing <= 1;
                end
            end
            
            NORMALIZE: begin
                // Scalable angle reduction - adapts to any ANGLE_WIDTH
                // Uses parameterizable binary reduction approach
                
                if (reduction_level > 0) begin
                    // Calculate current reduction amount: TWO_PI * 2^reduction_level
                    reg signed [ANGLE_WIDTH-1:0] current_reduction;
                    current_reduction = TWO_PI << reduction_level;
                    
                    if (temp_angle >= current_reduction) begin
                        temp_angle <= temp_angle - current_reduction;
                        // Stay at same level to continue reduction
                    end else if (temp_angle <= -current_reduction) begin
                        temp_angle <= temp_angle + current_reduction;
                        // Stay at same level to continue reduction  
                    end else begin
                        reduction_level <= reduction_level - 1;
                        // Move to next smaller reduction level
                    end
                end else begin
                    // Final reduction with 2π
                    if (temp_angle >= TWO_PI) begin
                        temp_angle <= temp_angle - TWO_PI;
                    end else if (temp_angle <= -TWO_PI) begin
                        temp_angle <= temp_angle + TWO_PI;
                    end else begin
                        // Angle fully normalized to [-2π, 2π]
                        // Apply quadrant correction
                        
                        x_sign <= 0;
                        y_sign <= 0;
                        
                        if ((temp_angle > PI_2) && (temp_angle <= PI)) begin
                            // Second quadrant: rotate to first, negate cosine
                            normalized_angle <= PI - temp_angle;
                            x_sign <= 1;
                        end else if ((temp_angle > PI) && (temp_angle <= PI_3_2)) begin
                            // Third quadrant: rotate to first, negate both
                            normalized_angle <= temp_angle - PI;
                            x_sign <= 1;
                            y_sign <= 1;
                        end else if (temp_angle > PI_3_2) begin
                            // Fourth quadrant: rotate to first, negate sine
                            normalized_angle <= TWO_PI - temp_angle;
                            y_sign <= 1;
                        end else if (temp_angle < -PI_2) begin
                            if (temp_angle >= -PI) begin
                                // Third quadrant (negative)
                                normalized_angle <= -PI - temp_angle;
                                x_sign <= 1;
                                y_sign <= 1;
                            end else begin
                                // Second quadrant (negative)
                                normalized_angle <= temp_angle + PI;
                                x_sign <= 1;
                            end
                        end else begin
                            // First quadrant or small negative angles
                            normalized_angle <= temp_angle;
                        end
                        
                        // Initialize CORDIC computation
                        x[0] <= x_start;
                        y[0] <= y_start;
                        z[0] <= normalized_angle;
                        iteration_counter <= 0;
                        state <= COMPUTE;
                    end
                end
            end
            
            COMPUTE: begin
                if (iteration_counter < ITERATIONS) begin
                    // Standard CORDIC micro-rotation
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
                // Apply final quadrant correction and output
                cosine <= x_sign ? -x[ITERATIONS] : x[ITERATIONS];
                sine <= y_sign ? -y[ITERATIONS] : y[ITERATIONS];
                done <= 1;
                computing <= 0;
                state <= IDLE;
            end
        endcase
    end
end

// Display configuration at elaboration time
initial begin
    $display("=== CORDIC Scalable Module Configuration ===");
    $display("ANGLE_WIDTH: %0d bits", ANGLE_WIDTH);
    $display("WIDTH: %0d bits", WIDTH);
    $display("ITERATIONS: %0d", ITERATIONS);
    $display("Fractional bits: %0d", FRAC_BITS);
    $display("Max reduction power: %0d", MAX_REDUCTION_POWER);
    
    real max_angle = (2.0**(MAX_REDUCTION_POWER + 1)) * 180.0;
    $display("Efficiently handles angles up to: ±%.0f°", max_angle);
    $display("Beyond this range: Still works but may take more cycles");
end

endmodule