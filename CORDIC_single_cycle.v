// CORDIC with Single-Cycle Angle Normalization
// Normalizes any input angle in ONE clock cycle using combinational logic

module CORDIC_single_cycle #(
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

// CORDIC constants (scaled for 32-bit, will be adapted)
localparam signed [ANGLE_WIDTH-1:0] PI = (ANGLE_WIDTH == 32) ? 32'h6487ED51 : 
                                         (ANGLE_WIDTH < 32) ? (32'h6487ED51 >>> (32-ANGLE_WIDTH)) :
                                         (32'h6487ED51 << (ANGLE_WIDTH-32));

localparam signed [ANGLE_WIDTH-1:0] PI_2 = PI >>> 1;
localparam signed [ANGLE_WIDTH-1:0] PI_3_2 = PI + PI_2;
localparam signed [ANGLE_WIDTH-1:0] TWO_PI = PI << 1;

localparam signed [WIDTH-1:0] CORDIC_GAIN = 16'h26DD;

// Arctangent lookup table (will be initialized properly)
reg signed [ANGLE_WIDTH-1:0] ATAN_TABLE [0:ITERATIONS-1];

// Initialize arctangent table based on ANGLE_WIDTH
initial begin
    // Reference values for 32-bit (29 fractional bits)
    reg [31:0] atan_ref [0:31];
    integer i;
    integer frac_bits;
    
    frac_bits = ANGLE_WIDTH - 3;
    
    atan_ref[0] = 32'h20000000;   atan_ref[1] = 32'h12E4051E;
    atan_ref[2] = 32'h09FB385B;   atan_ref[3] = 32'h051111D4;
    atan_ref[4] = 32'h028B0D43;   atan_ref[5] = 32'h0145D7E1;
    atan_ref[6] = 32'h00A2F61E;   atan_ref[7] = 32'h00517C55;
    atan_ref[8] = 32'h0028BE53;   atan_ref[9] = 32'h00145F2F;
    atan_ref[10] = 32'h000A2F98;  atan_ref[11] = 32'h000517CC;
    atan_ref[12] = 32'h00028BE6;  atan_ref[13] = 32'h000145F3;
    atan_ref[14] = 32'h0000A2FA;  atan_ref[15] = 32'h0000517D;
    
    for (i = 0; i < ITERATIONS && i < 16; i = i + 1) begin
        if (frac_bits == 29) begin
            ATAN_TABLE[i] = atan_ref[i];
        end else if (frac_bits < 29) begin
            ATAN_TABLE[i] = atan_ref[i] >>> (29 - frac_bits);
        end else begin
            ATAN_TABLE[i] = atan_ref[i] << (frac_bits - 29);
        end
    end
    
    $display("CORDIC Single-Cycle: ANGLE_WIDTH=%0d, Frac_bits=%0d", ANGLE_WIDTH, frac_bits);
end

// **KEY INNOVATION: Combinational Angle Normalization**
// This function normalizes ANY angle to [-π/2, π/2] in ZERO clock cycles
function [WIDTH + ANGLE_WIDTH + 1:0] normalize_angle_combinational;
    input signed [ANGLE_WIDTH-1:0] input_angle;
    
    // Local variables for the function
    reg signed [ANGLE_WIDTH-1:0] temp;
    reg signed [ANGLE_WIDTH-1:0] normalized;
    reg x_neg, y_neg;
    
    begin
        temp = input_angle;
        x_neg = 0;
        y_neg = 0;
        
        // STEP 1: Reduce to [-2π, 2π] range using modulo-like operations
        // This is ALL COMBINATIONAL - happens in one clock cycle!
        
        // Handle very large positive angles
        if (temp >= (TWO_PI << 10)) temp = temp - (TWO_PI << 10);  // -2048π
        if (temp >= (TWO_PI << 9))  temp = temp - (TWO_PI << 9);   // -1024π
        if (temp >= (TWO_PI << 8))  temp = temp - (TWO_PI << 8);   // -512π
        if (temp >= (TWO_PI << 7))  temp = temp - (TWO_PI << 7);   // -256π
        if (temp >= (TWO_PI << 6))  temp = temp - (TWO_PI << 6);   // -128π
        if (temp >= (TWO_PI << 5))  temp = temp - (TWO_PI << 5);   // -64π
        if (temp >= (TWO_PI << 4))  temp = temp - (TWO_PI << 4);   // -32π
        if (temp >= (TWO_PI << 3))  temp = temp - (TWO_PI << 3);   // -16π
        if (temp >= (TWO_PI << 2))  temp = temp - (TWO_PI << 2);   // -8π
        if (temp >= (TWO_PI << 1))  temp = temp - (TWO_PI << 1);   // -4π
        if (temp >= TWO_PI)         temp = temp - TWO_PI;          // -2π
        
        // Handle very large negative angles
        if (temp <= -(TWO_PI << 10)) temp = temp + (TWO_PI << 10);  // +2048π
        if (temp <= -(TWO_PI << 9))  temp = temp + (TWO_PI << 9);   // +1024π
        if (temp <= -(TWO_PI << 8))  temp = temp + (TWO_PI << 8);   // +512π
        if (temp <= -(TWO_PI << 7))  temp = temp + (TWO_PI << 7);   // +256π
        if (temp <= -(TWO_PI << 6))  temp = temp + (TWO_PI << 6);   // +128π
        if (temp <= -(TWO_PI << 5))  temp = temp + (TWO_PI << 5);   // +64π
        if (temp <= -(TWO_PI << 4))  temp = temp + (TWO_PI << 4);   // +32π
        if (temp <= -(TWO_PI << 3))  temp = temp + (TWO_PI << 3);   // +16π
        if (temp <= -(TWO_PI << 2))  temp = temp + (TWO_PI << 2);   // +8π
        if (temp <= -(TWO_PI << 1))  temp = temp + (TWO_PI << 1);   // +4π
        if (temp <= -TWO_PI)         temp = temp + TWO_PI;          // +2π
        
        // STEP 2: Quadrant correction to [-π/2, π/2] range
        // This is also COMBINATIONAL!
        
        if ((temp > PI_2) && (temp <= PI)) begin
            // Second quadrant: cos(-), sin(+)
            normalized = PI - temp;
            x_neg = 1;
        end else if ((temp > PI) && (temp <= PI_3_2)) begin
            // Third quadrant: cos(-), sin(-)  
            normalized = temp - PI;
            x_neg = 1;
            y_neg = 1;
        end else if (temp > PI_3_2) begin
            // Fourth quadrant: cos(+), sin(-)
            normalized = TWO_PI - temp;
            y_neg = 1;
        end else if (temp < -PI_2) begin
            if (temp >= -PI) begin
                // Third quadrant (negative): cos(-), sin(-)
                normalized = -PI - temp;
                x_neg = 1;
                y_neg = 1;
            end else begin
                // Second quadrant (negative): cos(-), sin(+)
                normalized = temp + PI;
                x_neg = 1;
            end
        end else begin
            // First quadrant or small negative: no correction
            normalized = temp;
        end
        
        // Pack return value: {x_neg, y_neg, normalized_angle}
        normalize_angle_combinational = {x_neg, y_neg, normalized};
    end
endfunction

// Combinational wires for normalized angle
wire signed [ANGLE_WIDTH-1:0] normalized_angle;
wire x_sign_comb, y_sign_comb;

// **SINGLE CYCLE NORMALIZATION** - This is the key improvement!
assign {x_sign_comb, y_sign_comb, normalized_angle} = normalize_angle_combinational(angle);

// Internal CORDIC registers
reg signed [WIDTH-1:0] x [0:ITERATIONS];
reg signed [WIDTH-1:0] y [0:ITERATIONS];
reg signed [ANGLE_WIDTH-1:0] z [0:ITERATIONS];
reg [4:0] iteration_counter;

// Final sign correction registers
reg x_sign, y_sign;
reg computing;

// Simple 3-state machine (no NORMALIZE state needed!)
localparam IDLE = 2'b00, COMPUTE = 2'b01, FINISH = 2'b10;
reg [1:0] state;

always @(posedge clock or posedge reset) begin
    if (reset) begin
        state <= IDLE;
        iteration_counter <= 0;
        done <= 0;
        cosine <= 0;
        sine <= 0;
        computing <= 0;
        x_sign <= 0;
        y_sign <= 0;
    end else begin
        case (state)
            IDLE: begin
                done <= 0;
                if (start) begin
                    // **INSTANT NORMALIZATION** - angle is normalized by combinational logic!
                    // No waiting, no multiple cycles - it's ready immediately!
                    
                    x[0] <= x_start;
                    y[0] <= y_start;
                    z[0] <= normalized_angle;  // Already normalized!
                    x_sign <= x_sign_comb;     // Already calculated!
                    y_sign <= y_sign_comb;     // Already calculated!
                    
                    iteration_counter <= 0;
                    computing <= 1;
                    state <= COMPUTE;  // Skip NORMALIZE state entirely!
                end
            end
            
            COMPUTE: begin
                if (iteration_counter < ITERATIONS) begin
                    // Standard CORDIC iterations
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
                // Apply final sign correction
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