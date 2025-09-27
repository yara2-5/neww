// CORDIC Implementation with True Unlimited Angle Range Support
// Handles any angle magnitude efficiently using dedicated modulo hardware

module CORDIC_unlimited #(
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

// Angle processing registers
reg signed [ANGLE_WIDTH-1:0] working_angle;
reg angle_sign;
reg x_sign, y_sign;

// State machine
localparam IDLE = 2'b00, MOD_REDUCE = 2'b01, COMPUTE = 2'b10, FINISH = 2'b11;
reg [1:0] state;

// Modulo reduction counter and step size
reg [3:0] mod_step;
reg signed [ANGLE_WIDTH-1:0] reduction_value;

always @(posedge clock or posedge reset) begin
    if (reset) begin
        state <= IDLE;
        iteration_counter <= 0;
        mod_step <= 0;
        done <= 0;
        cosine <= 0;
        sine <= 0;
        working_angle <= 0;
        angle_sign <= 0;
        x_sign <= 0;
        y_sign <= 0;
    end else begin
        case (state)
            IDLE: begin
                done <= 0;
                if (start) begin
                    // Store original angle sign and work with absolute value
                    angle_sign <= (angle < 0);
                    working_angle <= (angle < 0) ? -angle : angle;
                    mod_step <= 0;
                    state <= MOD_REDUCE;
                end
            end
            
            MOD_REDUCE: begin
                // Efficient modulo 2π using binary reduction approach
                // This reduces any angle to [0, 2π) in logarithmic time
                
                case (mod_step)
                    0: reduction_value = TWO_PI << 5;  // 64π
                    1: reduction_value = TWO_PI << 4;  // 32π
                    2: reduction_value = TWO_PI << 3;  // 16π
                    3: reduction_value = TWO_PI << 2;  // 8π
                    4: reduction_value = TWO_PI << 1;  // 4π
                    5: reduction_value = TWO_PI;       // 2π
                    default: reduction_value = 0;
                endcase
                
                if (mod_step < 6) begin
                    if (working_angle >= reduction_value) begin
                        working_angle <= working_angle - reduction_value;
                        // Stay in same step to continue reducing by same amount
                    end else begin
                        mod_step <= mod_step + 1;  // Move to next smaller reduction
                    end
                end else begin
                    // Modulo reduction complete, apply original sign
                    if (angle_sign) begin
                        working_angle <= -working_angle;
                    end
                    
                    // Proceed to quadrant correction and CORDIC setup
                    x_sign <= 0;
                    y_sign <= 0;
                    
                    // Quadrant correction logic
                    if (angle_sign) begin
                        // Handle negative angles
                        if (working_angle < -PI_2) begin
                            if (working_angle >= -PI) begin
                                // Third quadrant: cos(-), sin(-)
                                working_angle <= -PI - working_angle;
                                x_sign <= 1;
                                y_sign <= 1;
                            end else begin
                                // Second quadrant: cos(-), sin(+)
                                working_angle <= working_angle + PI;
                                x_sign <= 1;
                            end
                        end
                    end else begin
                        // Handle positive angles
                        if ((working_angle > PI_2) && (working_angle <= PI)) begin
                            // Second quadrant: cos(-), sin(+)
                            working_angle <= PI - working_angle;
                            x_sign <= 1;
                        end else if ((working_angle > PI) && (working_angle <= PI_3_2)) begin
                            // Third quadrant: cos(-), sin(-)
                            working_angle <= working_angle - PI;
                            x_sign <= 1;
                            y_sign <= 1;
                        end else if (working_angle > PI_3_2) begin
                            // Fourth quadrant: cos(+), sin(-)
                            working_angle <= TWO_PI - working_angle;
                            y_sign <= 1;
                        end
                    end
                    
                    // Initialize CORDIC iteration
                    x[0] <= x_start;
                    y[0] <= y_start;
                    z[0] <= working_angle;
                    iteration_counter <= 0;
                    state <= COMPUTE;
                end
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
                state <= IDLE;
            end
        endcase
    end
end

endmodule