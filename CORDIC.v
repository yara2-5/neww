// CORDIC (COordinate Rotation DIgital Computer) Implementation
// Parameterized design for sine and cosine calculation
// Handles angles beyond ±π/2 through quadrant correction

module CORDIC #(
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

// CORDIC gain compensation factor (Kn ≈ 0.6072529350088812561694)
// For 16-bit fixed point with 14 fractional bits: 0.6072529350088812561694 * 2^14 ≈ 9949
localparam signed [WIDTH-1:0] CORDIC_GAIN = 16'h26DD; // 9949 in hex

// Arctangent lookup table for CORDIC iterations
// Values are in radians, scaled for fixed-point representation
// atan(2^-i) * 2^(ANGLE_WIDTH-3) for i = 0 to ITERATIONS-1
localparam [ANGLE_WIDTH-1:0] ATAN_TABLE [0:ITERATIONS-1] = {
    32'h20000000,  // atan(2^0)  = 45.000000° = 0.785398 rad
    32'h12E4051E,  // atan(2^-1) = 26.565051° = 0.463648 rad
    32'h09FB385B,  // atan(2^-2) = 14.036243° = 0.244979 rad
    32'h051111D4,  // atan(2^-3) = 7.125016°  = 0.124355 rad
    32'h028B0D43,  // atan(2^-4) = 3.576334°  = 0.062419 rad
    32'h0145D7E1,  // atan(2^-5) = 1.789911°  = 0.031240 rad
    32'h00A2F61E,  // atan(2^-6) = 0.895174°  = 0.015624 rad
    32'h00517C55,  // atan(2^-7) = 0.447614°  = 0.007812 rad
    32'h0028BE53,  // atan(2^-8) = 0.223811°  = 0.003906 rad
    32'h00145F2F,  // atan(2^-9) = 0.111906°  = 0.001953 rad
    32'h000A2F98,  // atan(2^-10) = 0.055953° = 0.000977 rad
    32'h000517CC,  // atan(2^-11) = 0.027977° = 0.000488 rad
    32'h00028BE6,  // atan(2^-12) = 0.013988° = 0.000244 rad
    32'h000145F3,  // atan(2^-13) = 0.006994° = 0.000122 rad
    32'h0000A2FA   // atan(2^-14) = 0.003497° = 0.000061 rad
};

// Constants for angle normalization
localparam signed [ANGLE_WIDTH-1:0] PI        = 32'h6487ED51; // π scaled
localparam signed [ANGLE_WIDTH-1:0] PI_2      = 32'h3243F6A9; // π/2 scaled  
localparam signed [ANGLE_WIDTH-1:0] PI_3_2    = 32'h96CBE3F9; // 3π/2 scaled
localparam signed [ANGLE_WIDTH-1:0] TWO_PI    = 32'hC90FDAA2; // 2π scaled

// Internal registers
reg signed [WIDTH-1:0] x [0:ITERATIONS];
reg signed [WIDTH-1:0] y [0:ITERATIONS];
reg signed [ANGLE_WIDTH-1:0] z [0:ITERATIONS];
reg [4:0] iteration_counter;
reg computing;

// Quadrant correction variables
reg signed [ANGLE_WIDTH-1:0] normalized_angle;
reg x_sign, y_sign;

// State machine states
localparam IDLE = 2'b00, NORMALIZE = 2'b01, COMPUTE = 2'b10, FINISH = 2'b11;
reg [1:0] state;

// Registers for enhanced angle normalization
reg signed [ANGLE_WIDTH-1:0] temp_angle;
reg angle_negative;

always @(posedge clock or posedge reset) begin
    if (reset) begin
        state <= IDLE;
        iteration_counter <= 0;
        done <= 0;
        cosine <= 0;
        sine <= 0;
        computing <= 0;
        temp_angle <= 0;
        angle_negative <= 0;
    end else begin
        case (state)
            IDLE: begin
                done <= 0;
                if (start) begin
                    // Initialize with input angle
                    temp_angle <= angle;
                    angle_negative <= (angle < 0);
                    state <= NORMALIZE;
                    computing <= 1;
                end
            end
            
            NORMALIZE: begin
                // Multi-cycle angle normalization for unlimited range support
                // Efficiently reduces any angle to [-2π, 2π] range
                
                // Large reduction step: subtract multiples of 2π
                if (temp_angle >= (TWO_PI << 4)) begin  // >= 32π (11520°)
                    temp_angle <= temp_angle - (TWO_PI << 4);
                end else if (temp_angle >= (TWO_PI << 3)) begin  // >= 16π (5760°)
                    temp_angle <= temp_angle - (TWO_PI << 3);
                end else if (temp_angle >= (TWO_PI << 2)) begin  // >= 8π (2880°)
                    temp_angle <= temp_angle - (TWO_PI << 2);
                end else if (temp_angle >= (TWO_PI << 1)) begin  // >= 4π (1440°)
                    temp_angle <= temp_angle - (TWO_PI << 1);
                end else if (temp_angle >= TWO_PI) begin         // >= 2π (720°)
                    temp_angle <= temp_angle - TWO_PI;
                end else if (temp_angle <= -(TWO_PI << 4)) begin // <= -32π
                    temp_angle <= temp_angle + (TWO_PI << 4);
                end else if (temp_angle <= -(TWO_PI << 3)) begin // <= -16π
                    temp_angle <= temp_angle + (TWO_PI << 3);
                end else if (temp_angle <= -(TWO_PI << 2)) begin // <= -8π
                    temp_angle <= temp_angle + (TWO_PI << 2);
                end else if (temp_angle <= -(TWO_PI << 1)) begin // <= -4π
                    temp_angle <= temp_angle + (TWO_PI << 1);
                end else if (temp_angle <= -TWO_PI) begin        // <= -2π
                    temp_angle <= temp_angle + TWO_PI;
                end else begin
                    // Angle is now in [-2π, 2π] range
                    // Apply quadrant correction
                    x_sign <= 0;
                    y_sign <= 0;
                    
                    if ((temp_angle > PI_2) && (temp_angle <= PI)) begin
                        // Second quadrant: cos(-), sin(+)
                        normalized_angle <= PI - temp_angle;
                        x_sign <= 1;
                    end else if ((temp_angle > PI) && (temp_angle <= PI_3_2)) begin
                        // Third quadrant: cos(-), sin(-)
                        normalized_angle <= temp_angle - PI;
                        x_sign <= 1;
                        y_sign <= 1;
                    end else if (temp_angle > PI_3_2) begin
                        // Fourth quadrant: cos(+), sin(-)
                        normalized_angle <= TWO_PI - temp_angle;
                        y_sign <= 1;
                    end else if (temp_angle < -PI_2) begin
                        if (temp_angle >= -PI) begin
                            // Third quadrant (negative): cos(-), sin(-)
                            normalized_angle <= -PI - temp_angle;
                            x_sign <= 1;
                            y_sign <= 1;
                        end else begin
                            // Second quadrant (negative): cos(-), sin(+)
                            normalized_angle <= temp_angle + PI;
                            x_sign <= 1;
                        end
                    end else begin
                        // First quadrant or small negative angles: no correction
                        normalized_angle <= temp_angle;
                    end
                    
                    // Initialize CORDIC variables
                    x[0] <= x_start;
                    y[0] <= y_start;
                    z[0] <= normalized_angle;
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
                computing <= 0;
                state <= IDLE;
            end
        endcase
    end
end

endmodule