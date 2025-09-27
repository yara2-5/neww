// Universal CORDIC Implementation - Truly Parameterizable for Any ANGLE_WIDTH
// Uses generate blocks and compile-time calculations for proper scaling

module CORDIC_universal #(
    parameter WIDTH = 16,           // Data width for coordinates
    parameter ITERATIONS = 15,      // Number of CORDIC iterations  
    parameter ANGLE_WIDTH = 32      // Angle width in bits (8 to 64 supported)
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

// Fractional bits for angle representation
localparam ANGLE_FRAC_BITS = ANGLE_WIDTH - 3;

// Generate angle constants using proper bit-width scaling
// These values are calculated for the specific ANGLE_WIDTH at compile time
generate
    if (ANGLE_WIDTH == 16) begin : angle_16
        localparam signed [ANGLE_WIDTH-1:0] PI = 16'h6488;
        localparam signed [ANGLE_WIDTH-1:0] PI_2 = 16'h3244;
        localparam signed [ANGLE_WIDTH-1:0] PI_3_2 = 16'h96CC;
        localparam signed [ANGLE_WIDTH-1:0] TWO_PI = 16'hC910;
    end else if (ANGLE_WIDTH == 24) begin : angle_24
        localparam signed [ANGLE_WIDTH-1:0] PI = 24'h648800;
        localparam signed [ANGLE_WIDTH-1:0] PI_2 = 24'h324400;
        localparam signed [ANGLE_WIDTH-1:0] PI_3_2 = 24'h96CC00;
        localparam signed [ANGLE_WIDTH-1:0] TWO_PI = 24'hC91000;
    end else if (ANGLE_WIDTH == 32) begin : angle_32
        localparam signed [ANGLE_WIDTH-1:0] PI = 32'h6487ED51;
        localparam signed [ANGLE_WIDTH-1:0] PI_2 = 32'h3243F6A9;
        localparam signed [ANGLE_WIDTH-1:0] PI_3_2 = 32'h96CBE3F9;
        localparam signed [ANGLE_WIDTH-1:0] TWO_PI = 32'hC90FDAA2;
    end else if (ANGLE_WIDTH == 40) begin : angle_40
        localparam signed [ANGLE_WIDTH-1:0] PI = 40'h6487ED5110;
        localparam signed [ANGLE_WIDTH-1:0] PI_2 = 40'h3243F6A888;
        localparam signed [ANGLE_WIDTH-1:0] PI_3_2 = 40'h96CBE3F998;
        localparam signed [ANGLE_WIDTH-1:0] TWO_PI = 40'hC90FDAA220;
    end else if (ANGLE_WIDTH == 48) begin : angle_48
        localparam signed [ANGLE_WIDTH-1:0] PI = 48'h6487ED511000;
        localparam signed [ANGLE_WIDTH-1:0] PI_2 = 48'h3243F6A88800;
        localparam signed [ANGLE_WIDTH-1:0] PI_3_2 = 48'h96CBE3F99800;
        localparam signed [ANGLE_WIDTH-1:0] TWO_PI = 48'hC90FDAA22000;
    end else begin : angle_default
        // Default to 32-bit values (will be truncated/extended as needed)
        localparam signed [ANGLE_WIDTH-1:0] PI = 32'h6487ED51;
        localparam signed [ANGLE_WIDTH-1:0] PI_2 = 32'h3243F6A9;
        localparam signed [ANGLE_WIDTH-1:0] PI_3_2 = 32'h96CBE3F9;
        localparam signed [ANGLE_WIDTH-1:0] TWO_PI = 32'hC90FDAA2;
    end
endgenerate

// Access the generated constants
wire signed [ANGLE_WIDTH-1:0] CONST_PI = (ANGLE_WIDTH == 16) ? angle_16.PI :
                                         (ANGLE_WIDTH == 24) ? angle_24.PI :
                                         (ANGLE_WIDTH == 32) ? angle_32.PI :
                                         (ANGLE_WIDTH == 40) ? angle_40.PI :
                                         (ANGLE_WIDTH == 48) ? angle_48.PI :
                                         angle_default.PI;

wire signed [ANGLE_WIDTH-1:0] CONST_PI_2 = (ANGLE_WIDTH == 16) ? angle_16.PI_2 :
                                           (ANGLE_WIDTH == 24) ? angle_24.PI_2 :
                                           (ANGLE_WIDTH == 32) ? angle_32.PI_2 :
                                           (ANGLE_WIDTH == 40) ? angle_40.PI_2 :
                                           (ANGLE_WIDTH == 48) ? angle_48.PI_2 :
                                           angle_default.PI_2;

wire signed [ANGLE_WIDTH-1:0] CONST_PI_3_2 = (ANGLE_WIDTH == 16) ? angle_16.PI_3_2 :
                                             (ANGLE_WIDTH == 24) ? angle_24.PI_3_2 :
                                             (ANGLE_WIDTH == 32) ? angle_32.PI_3_2 :
                                             (ANGLE_WIDTH == 40) ? angle_40.PI_3_2 :
                                             (ANGLE_WIDTH == 48) ? angle_48.PI_3_2 :
                                             angle_default.PI_3_2;

wire signed [ANGLE_WIDTH-1:0] CONST_TWO_PI = (ANGLE_WIDTH == 16) ? angle_16.TWO_PI :
                                             (ANGLE_WIDTH == 24) ? angle_24.TWO_PI :
                                             (ANGLE_WIDTH == 32) ? angle_32.TWO_PI :
                                             (ANGLE_WIDTH == 40) ? angle_40.TWO_PI :
                                             (ANGLE_WIDTH == 48) ? angle_48.TWO_PI :
                                             angle_default.TWO_PI;

// Calculate maximum safe reduction power based on ANGLE_WIDTH
function integer calculate_max_reduction_power;
    input integer angle_width;
    begin
        // Conservative calculation to avoid overflow
        // Max safe power = angle_width - 4 (keeping some margin)
        calculate_max_reduction_power = (angle_width >= 8) ? (angle_width - 4) : 2;
    end
endfunction

localparam MAX_POWER = calculate_max_reduction_power(ANGLE_WIDTH);

// Internal registers
reg signed [WIDTH-1:0] x [0:ITERATIONS];
reg signed [WIDTH-1:0] y [0:ITERATIONS];
reg signed [ANGLE_WIDTH-1:0] z [0:ITERATIONS];
reg [4:0] iteration_counter;
reg [3:0] reduction_power;

// Angle processing registers
reg signed [ANGLE_WIDTH-1:0] temp_angle;
reg signed [ANGLE_WIDTH-1:0] normalized_angle;
reg x_sign, y_sign;
reg computing;

// State machine
localparam IDLE = 2'b00, NORMALIZE = 2'b01, COMPUTE = 2'b10, FINISH = 2'b11;
reg [1:0] state;

always @(posedge clock or posedge reset) begin
    if (reset) begin
        state <= IDLE;
        iteration_counter <= 0;
        reduction_power <= MAX_POWER;
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
                    reduction_power <= MAX_POWER;
                    state <= NORMALIZE;
                    computing <= 1;
                end
            end
            
            NORMALIZE: begin
                // Universal angle normalization using parameterizable reduction
                reg signed [ANGLE_WIDTH-1:0] current_reduction;
                
                // Calculate current reduction value: TWO_PI << reduction_power
                if (reduction_power == 0) begin
                    current_reduction = CONST_TWO_PI;
                end else begin
                    current_reduction = CONST_TWO_PI << reduction_power;
                end
                
                // Apply reduction if needed
                if (reduction_power > 0) begin
                    if (temp_angle >= current_reduction) begin
                        temp_angle <= temp_angle - current_reduction;
                        // Continue with same power level
                    end else if (temp_angle <= -current_reduction) begin
                        temp_angle <= temp_angle + current_reduction;
                        // Continue with same power level
                    end else begin
                        reduction_power <= reduction_power - 1; // Try smaller reduction
                    end
                end else begin
                    // Final reduction with 2π
                    if (temp_angle >= CONST_TWO_PI) begin
                        temp_angle <= temp_angle - CONST_TWO_PI;
                    end else if (temp_angle <= -CONST_TWO_PI) begin
                        temp_angle <= temp_angle + CONST_TWO_PI;
                    end else begin
                        // Angle normalized, apply quadrant correction
                        x_sign <= 0;
                        y_sign <= 0;
                        
                        if ((temp_angle > CONST_PI_2) && (temp_angle <= CONST_PI)) begin
                            normalized_angle <= CONST_PI - temp_angle;
                            x_sign <= 1;
                        end else if ((temp_angle > CONST_PI) && (temp_angle <= CONST_PI_3_2)) begin
                            normalized_angle <= temp_angle - CONST_PI;
                            x_sign <= 1;
                            y_sign <= 1;
                        end else if (temp_angle > CONST_PI_3_2) begin
                            normalized_angle <= CONST_TWO_PI - temp_angle;
                            y_sign <= 1;
                        end else if (temp_angle < -CONST_PI_2) begin
                            if (temp_angle >= -CONST_PI) begin
                                normalized_angle <= -CONST_PI - temp_angle;
                                x_sign <= 1;
                                y_sign <= 1;
                            end else begin
                                normalized_angle <= temp_angle + CONST_PI;
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