// Truly Parameterizable CORDIC - Handles Any ANGLE_WIDTH
// Uses systematic scaling approach that works for any bit width

module CORDIC_truly_parameterizable #(
    parameter WIDTH = 16,           // Data width for coordinates
    parameter ITERATIONS = 15,      // Number of CORDIC iterations  
    parameter ANGLE_WIDTH = 32      // Angle width in bits (any value 8-64)
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

// Calculate fractional bits (3 integer bits reserved for ±4π range)
localparam FRAC_BITS = (ANGLE_WIDTH >= 8) ? (ANGLE_WIDTH - 3) : 5;

// Calculate scaling factors
localparam integer ANGLE_SCALE_INT = (1 << FRAC_BITS);
localparam real ANGLE_SCALE = 2.0**(FRAC_BITS);

// Calculate CORDIC gain compensation (1/K_n) scaled for WIDTH
localparam real CORDIC_GAIN_REAL = 0.6072529350088812561694;
localparam signed [WIDTH-1:0] CORDIC_GAIN = $rtoi(CORDIC_GAIN_REAL * (2.0**(WIDTH-2)));

// Universal constant calculation using integer arithmetic
// This avoids floating-point issues in synthesis
function signed [ANGLE_WIDTH-1:0] calc_pi_scaled;
    input integer frac_bits;
    begin
        // π ≈ 3.141592653589793, scaled by 2^frac_bits
        // Using high-precision integer representation
        if (frac_bits <= 14) begin
            calc_pi_scaled = (51472 * (1 << frac_bits)) / 16384; // High precision π approximation
        end else if (frac_bits <= 28) begin
            calc_pi_scaled = (3373259426 * (1 << (frac_bits-14))) / 1073741824; // For larger bit widths
        end else begin
            // For very large bit widths, use truncation of maximum precision
            calc_pi_scaled = 32'h6487ED51 << (frac_bits - 29);
        end
    end
endfunction

// Generate angle constants dynamically
localparam signed [ANGLE_WIDTH-1:0] PI = calc_pi_scaled(FRAC_BITS);
localparam signed [ANGLE_WIDTH-1:0] PI_2 = PI >>> 1;  // π/2
localparam signed [ANGLE_WIDTH-1:0] PI_3_2 = PI + PI_2; // 3π/2
localparam signed [ANGLE_WIDTH-1:0] TWO_PI = PI << 1;   // 2π

// Generate arctangent lookup table dynamically
function signed [ANGLE_WIDTH-1:0] calc_atan_scaled;
    input integer iteration;
    input integer frac_bits;
    
    // Pre-calculated atan(2^-i) values * 2^29 (high precision reference)
    reg [31:0] atan_table_ref [0:31];
    begin
        atan_table_ref[0] = 32'h20000000;   atan_table_ref[1] = 32'h12E4051E;
        atan_table_ref[2] = 32'h09FB385B;   atan_table_ref[3] = 32'h051111D4;
        atan_table_ref[4] = 32'h028B0D43;   atan_table_ref[5] = 32'h0145D7E1;
        atan_table_ref[6] = 32'h00A2F61E;   atan_table_ref[7] = 32'h00517C55;
        atan_table_ref[8] = 32'h0028BE53;   atan_table_ref[9] = 32'h00145F2F;
        atan_table_ref[10] = 32'h000A2F98;  atan_table_ref[11] = 32'h000517CC;
        atan_table_ref[12] = 32'h00028BE6;  atan_table_ref[13] = 32'h000145F3;
        atan_table_ref[14] = 32'h0000A2FA;  atan_table_ref[15] = 32'h0000517D;
        atan_table_ref[16] = 32'h000028BE;  atan_table_ref[17] = 32'h0000145F;
        atan_table_ref[18] = 32'h00000A30;  atan_table_ref[19] = 32'h00000518;
        atan_table_ref[20] = 32'h0000028C;  atan_table_ref[21] = 32'h00000146;
        atan_table_ref[22] = 32'h000000A3;  atan_table_ref[23] = 32'h00000051;
        atan_table_ref[24] = 32'h00000029;  atan_table_ref[25] = 32'h00000014;
        atan_table_ref[26] = 32'h0000000A;  atan_table_ref[27] = 32'h00000005;
        atan_table_ref[28] = 32'h00000003;  atan_table_ref[29] = 32'h00000001;
        atan_table_ref[30] = 32'h00000001;  atan_table_ref[31] = 32'h00000000;
        
        if (iteration < 32) begin
            if (frac_bits == 29) begin
                calc_atan_scaled = atan_table_ref[iteration];
            end else if (frac_bits < 29) begin
                calc_atan_scaled = atan_table_ref[iteration] >>> (29 - frac_bits);
            end else begin
                calc_atan_scaled = atan_table_ref[iteration] << (frac_bits - 29);
            end
        end else begin
            calc_atan_scaled = 0; // Beyond available precision
        end
    end
endfunction

// Generate ATAN lookup table
reg signed [ANGLE_WIDTH-1:0] ATAN_TABLE [0:ITERATIONS-1];

initial begin
    integer i;
    for (i = 0; i < ITERATIONS; i = i + 1) begin
        ATAN_TABLE[i] = calc_atan_scaled(i, FRAC_BITS);
    end
    
    $display("=== CORDIC Universal Parameters (ANGLE_WIDTH=%0d) ===", ANGLE_WIDTH);
    $display("Fractional bits: %0d", FRAC_BITS);
    $display("Angle scale: 2^%0d = %0d", FRAC_BITS, ANGLE_SCALE_INT);
    $display("PI = 0x%0X (%0d)", PI, PI);
    $display("TWO_PI = 0x%0X (%0d)", TWO_PI, TWO_PI);
    $display("Max reduction power: %0d (up to %0dπ)", MAX_POWER, (1 << MAX_POWER));
    $display("CORDIC gain: 0x%0X", CORDIC_GAIN);
end

// Calculate maximum reduction levels that fit in current ANGLE_WIDTH
function integer calc_max_reduction_levels;
    input integer angle_width;
    begin
        calc_max_reduction_levels = (angle_width >= 8) ? (angle_width - 5) : 3;
    end
endfunction

localparam MAX_REDUCTION_LEVELS = calc_max_reduction_levels(ANGLE_WIDTH);

// Internal state registers
reg signed [ANGLE_WIDTH-1:0] temp_angle;
reg signed [ANGLE_WIDTH-1:0] normalized_angle;
reg [4:0] iteration_counter;
reg [3:0] current_reduction_level;
reg x_sign, y_sign;
reg computing;

// State machine
localparam IDLE = 2'b00, NORMALIZE = 2'b01, COMPUTE = 2'b10, FINISH = 2'b11;
reg [1:0] state;

always @(posedge clock or posedge reset) begin
    if (reset) begin
        state <= IDLE;
        iteration_counter <= 0;
        current_reduction_level <= MAX_REDUCTION_LEVELS;
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
                    current_reduction_level <= MAX_REDUCTION_LEVELS;
                    state <= NORMALIZE;
                    computing <= 1;
                end
            end
            
            NORMALIZE: begin
                // Universal angle reduction that adapts to any ANGLE_WIDTH
                reg signed [ANGLE_WIDTH-1:0] reduction_value;
                
                if (current_reduction_level > 0) begin
                    // Calculate reduction value: TWO_PI * 2^current_reduction_level
                    reduction_value = CONST_TWO_PI << current_reduction_level;
                    
                    if (temp_angle >= reduction_value) begin
                        temp_angle <= temp_angle - reduction_value;
                        // Continue with same level for multiple reductions
                    end else if (temp_angle <= -reduction_value) begin
                        temp_angle <= temp_angle + reduction_value;
                        // Continue with same level for multiple reductions
                    end else begin
                        current_reduction_level <= current_reduction_level - 1;
                        // Move to smaller reduction level
                    end
                end else begin
                    // Final 2π reduction
                    if (temp_angle >= CONST_TWO_PI) begin
                        temp_angle <= temp_angle - CONST_TWO_PI;
                    end else if (temp_angle <= -CONST_TWO_PI) begin
                        temp_angle <= temp_angle + CONST_TWO_PI;
                    end else begin
                        // Angle fully normalized, apply quadrant correction
                        x_sign <= 0;
                        y_sign <= 0;
                        
                        if ((temp_angle > CONST_PI_2) && (temp_angle <= CONST_PI)) begin
                            // Second quadrant
                            normalized_angle <= CONST_PI - temp_angle;
                            x_sign <= 1;
                        end else if ((temp_angle > CONST_PI) && (temp_angle <= CONST_PI_3_2)) begin
                            // Third quadrant
                            normalized_angle <= temp_angle - CONST_PI;
                            x_sign <= 1;
                            y_sign <= 1;
                        end else if (temp_angle > CONST_PI_3_2) begin
                            // Fourth quadrant
                            normalized_angle <= CONST_TWO_PI - temp_angle;
                            y_sign <= 1;
                        end else if (temp_angle < -CONST_PI_2) begin
                            if (temp_angle >= -CONST_PI) begin
                                // Third quadrant (negative)
                                normalized_angle <= -CONST_PI - temp_angle;
                                x_sign <= 1;
                                y_sign <= 1;
                            end else begin
                                // Second quadrant (negative)
                                normalized_angle <= temp_angle + CONST_PI;
                                x_sign <= 1;
                            end
                        end else begin
                            // First quadrant
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