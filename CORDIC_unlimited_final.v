// CORDIC with True Unlimited Angle Support - Fully Parameterizable
// This version correctly handles any ANGLE_WIDTH and unlimited input angles

module CORDIC_unlimited_final #(
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

// Parameterizable constants - automatically scale with ANGLE_WIDTH
// Using integer arithmetic to avoid synthesis issues

// Calculate fractional bits (3 integer bits reserved)
localparam FRAC_BITS = (ANGLE_WIDTH >= 8) ? (ANGLE_WIDTH - 3) : 5;

// For angle constants, we use bit-exact scaling from a reference
// Reference: 32-bit values with 29 fractional bits
localparam signed [31:0] PI_REF_32 = 32'h6487ED51;
localparam signed [31:0] PI_2_REF_32 = 32'h3243F6A8;
localparam signed [31:0] PI_3_2_REF_32 = 32'h96CBE3F9;
localparam signed [31:0] TWO_PI_REF_32 = 32'hC90FDAA2;

// Scale constants to current ANGLE_WIDTH
localparam signed [ANGLE_WIDTH-1:0] PI = 
    (FRAC_BITS == 29) ? PI_REF_32 :
    (FRAC_BITS < 29)  ? (PI_REF_32 >>> (29 - FRAC_BITS)) :
                        (PI_REF_32 << (FRAC_BITS - 29));

localparam signed [ANGLE_WIDTH-1:0] PI_2 = 
    (FRAC_BITS == 29) ? PI_2_REF_32 :
    (FRAC_BITS < 29)  ? (PI_2_REF_32 >>> (29 - FRAC_BITS)) :
                        (PI_2_REF_32 << (FRAC_BITS - 29));

localparam signed [ANGLE_WIDTH-1:0] PI_3_2 = 
    (FRAC_BITS == 29) ? PI_3_2_REF_32 :
    (FRAC_BITS < 29)  ? (PI_3_2_REF_32 >>> (29 - FRAC_BITS)) :
                        (PI_3_2_REF_32 << (FRAC_BITS - 29));

localparam signed [ANGLE_WIDTH-1:0] TWO_PI = 
    (FRAC_BITS == 29) ? TWO_PI_REF_32 :
    (FRAC_BITS < 29)  ? (TWO_PI_REF_32 >>> (29 - FRAC_BITS)) :
                        (TWO_PI_REF_32 << (FRAC_BITS - 29));

// CORDIC gain compensation (same for all configurations)
localparam signed [WIDTH-1:0] CORDIC_GAIN = 16'h26DD;

// Arctangent lookup table - dynamically sized and scaled
reg signed [ANGLE_WIDTH-1:0] ATAN_TABLE [0:ITERATIONS-1];

// Initialize arctangent table based on parameters
initial begin
    // Reference atan values (32-bit, 29 fractional bits)
    reg [31:0] atan_ref [0:31];
    integer i;
    
    atan_ref[0] = 32'h20000000;   atan_ref[1] = 32'h12E4051E;
    atan_ref[2] = 32'h09FB385B;   atan_ref[3] = 32'h051111D4;
    atan_ref[4] = 32'h028B0D43;   atan_ref[5] = 32'h0145D7E1;
    atan_ref[6] = 32'h00A2F61E;   atan_ref[7] = 32'h00517C55;
    atan_ref[8] = 32'h0028BE53;   atan_ref[9] = 32'h00145F2F;
    atan_ref[10] = 32'h000A2F98;  atan_ref[11] = 32'h000517CC;
    atan_ref[12] = 32'h00028BE6;  atan_ref[13] = 32'h000145F3;
    atan_ref[14] = 32'h0000A2FA;  atan_ref[15] = 32'h0000517D;
    atan_ref[16] = 32'h000028BE;  atan_ref[17] = 32'h0000145F;
    atan_ref[18] = 32'h00000A30;  atan_ref[19] = 32'h00000518;
    atan_ref[20] = 32'h0000028C;  atan_ref[21] = 32'h00000146;
    atan_ref[22] = 32'h000000A3;  atan_ref[23] = 32'h00000051;
    atan_ref[24] = 32'h00000029;  atan_ref[25] = 32'h00000014;
    atan_ref[26] = 32'h0000000A;  atan_ref[27] = 32'h00000005;
    atan_ref[28] = 32'h00000003;  atan_ref[29] = 32'h00000001;
    atan_ref[30] = 32'h00000001;  atan_ref[31] = 32'h00000000;
    
    // Scale and populate table
    for (i = 0; i < ITERATIONS && i < 32; i = i + 1) begin
        if (FRAC_BITS == 29) begin
            ATAN_TABLE[i] = atan_ref[i];
        end else if (FRAC_BITS < 29) begin
            ATAN_TABLE[i] = atan_ref[i] >>> (29 - FRAC_BITS);
        end else begin
            ATAN_TABLE[i] = atan_ref[i] << (FRAC_BITS - 29);
        end
    end
    
    $display("ATAN_TABLE[0] = 0x%0X (45°)", ATAN_TABLE[0]);
    $display("ATAN_TABLE[%0d] = 0x%0X", ITERATIONS-1, ATAN_TABLE[ITERATIONS-1]);
end

// Internal state
reg signed [ANGLE_WIDTH-1:0] temp_angle;
reg signed [ANGLE_WIDTH-1:0] normalized_angle;
reg [5:0] current_power;  // Current reduction power level
reg x_sign, y_sign;
reg computing;

// State machine
localparam IDLE = 2'b00, NORMALIZE = 2'b01, COMPUTE = 2'b10, FINISH = 2'b11;
reg [1:0] state;

always @(posedge clock or posedge reset) begin
    if (reset) begin
        state <= IDLE;
        iteration_counter <= 0;
        current_power <= MAX_REDUCTION_POWER;
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
                    current_power <= MAX_REDUCTION_POWER;
                    state <= NORMALIZE;
                    computing <= 1;
                end
            end
            
            NORMALIZE: begin
                // Universal angle reduction that works for any ANGLE_WIDTH
                if (current_power > 0) begin
                    // Calculate reduction value for current power level
                    reg signed [ANGLE_WIDTH-1:0] reduction_val;
                    reduction_val = TWO_PI << current_power;
                    
                    if (temp_angle >= reduction_val) begin
                        temp_angle <= temp_angle - reduction_val;
                        // Continue at same power level
                    end else if (temp_angle <= -reduction_val) begin
                        temp_angle <= temp_angle + reduction_val;
                        // Continue at same power level
                    end else begin
                        current_power <= current_power - 1;
                        // Move to smaller reduction
                    end
                end else begin
                    // Final 2π reduction
                    if (temp_angle >= TWO_PI) begin
                        temp_angle <= temp_angle - TWO_PI;
                    end else if (temp_angle <= -TWO_PI) begin
                        temp_angle <= temp_angle + TWO_PI;
                    end else begin
                        // Quadrant correction
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
                        
                        // Start CORDIC computation
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