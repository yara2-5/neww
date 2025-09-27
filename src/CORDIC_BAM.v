// CORDIC_BAM.v - CORDIC rotation mode using Binary Angular Measure (BAM) angles
//
// - Angle input is unsigned BAM format: 0 .. 2^ANGLE_WIDTH-1 maps to [0, 2π)
// - Modulo 2π wrapping is automatic by truncation; no divides or iterative wrapping
// - Quadrant reduction is performed via simple subtracts using BAM constants
// - Micro-rotation table atan(2^-i) is stored in BAM units
//
// Usage for sine/cosine:
// - Provide x_start = 1/K (fixed-point) and y_start = 0. K is the CORDIC gain
// - Drive angle_bam in BAM units; results are cosine/sine scaled by 1.0 (when x_start = 1/K)

`timescale 1ns/1ps

module CORDIC_BAM #(
	parameter integer DATA_WIDTH   = 16,
	parameter integer FRAC_BITS    = DATA_WIDTH-2, // data fixed-point fractional bits
	parameter integer ITERATIONS   = (DATA_WIDTH < 32) ? DATA_WIDTH : 32,
	parameter integer ANGLE_WIDTH  = 16            // BAM bits (e.g., 16 => 2π = 65536)
) (
	input  wire                             clock,
	input  wire signed [DATA_WIDTH-1:0]     x_start,
	input  wire signed [DATA_WIDTH-1:0]     y_start,
	input  wire        [ANGLE_WIDTH-1:0]    angle_bam,  // unsigned BAM
	output wire signed [DATA_WIDTH-1:0]     cosine,
	output wire signed [DATA_WIDTH-1:0]     sine
);

	// ------------------------------
	// BAM constants
	// ------------------------------
	localparam [ANGLE_WIDTH-1:0] TWO_PI_BAM = {ANGLE_WIDTH{1'b0}}; // wrap length (implicit)
	localparam [ANGLE_WIDTH-1:0] PI_BAM     = {1'b1, {ANGLE_WIDTH-1{1'b0}}};      // 2^(N-1)
	localparam [ANGLE_WIDTH-1:0] PI_BY2_BAM = ({1'b1, {ANGLE_WIDTH-1{1'b0}}}) >> 1; // 2^(N-2)

	// ------------------------------
	// Quadrant decoding
	// q = angle_bam[ANGLE_WIDTH-1:ANGLE_WIDTH-2]
	// 00: [0, π/2)
	// 01: [π/2, π)
	// 10: [π, 3π/2)
	// 11: [3π/2, 2π)
	// ------------------------------
	wire [1:0] quadrant = angle_bam[ANGLE_WIDTH-1 -: 2];

	// Map to core range [-π/2, π/2] in signed BAM
	// Also determine whether to flip both outputs (quadrants 01 and 10)
	reg  signed [ANGLE_WIDTH:0] z0_signed; // one extra bit to hold negative values safely
	reg  need_flip_sign;
	always @* begin
		case (quadrant)
			2'b00: begin
				z0_signed      = $signed({1'b0, angle_bam});
				need_flip_sign = 1'b0;
			end
			2'b01: begin
				// angle_core = angle - π (in (-π/2, 0)) and flip both outputs
				z0_signed      = $signed({1'b0, angle_bam}) - $signed({1'b0, PI_BAM});
				need_flip_sign = 1'b1;
			end
			2'b10: begin
				// angle_core = angle - π (in (0, π/2)) and flip both outputs
				z0_signed      = $signed({1'b0, angle_bam}) - $signed({1'b0, PI_BAM});
				need_flip_sign = 1'b1;
			end
			default: begin // 2'b11
				// angle_core = angle - 2π (in (-π/2, 0))
				z0_signed      = $signed({1'b0, angle_bam}) - $signed({1'b0, {1'b1,{ANGLE_WIDTH{1'b0}}}}); // subtract 2^ANGLE_WIDTH
				need_flip_sign = 1'b0;
			end
		endcase
	end

	// ------------------------------
	// atan(2^-i) in BAM units: round( atan(2^-i) * 2^ANGLE_WIDTH / (2π) )
	// For portability, we generate at elaboration using $atan.
	// Replace with a constant table if your tool doesn't allow real math at elaboration.
	// ------------------------------
	reg signed [ANGLE_WIDTH:0] atan_bam [0:ITERATIONS-1];
	integer ii;
	initial begin
		for (ii = 0; ii < ITERATIONS; ii = ii + 1) begin
			real ang = $atan($pow(2.0, -ii));
			real scale = (1.0 * (1<<ANGLE_WIDTH)) / (6.283185307179586);
			integer val = $rtoi(ang * scale + 0.5);
			atan_bam[ii] = val;
		end
	end

	// ------------------------------
	// Pipelined CORDIC core (rotation mode)
	// ------------------------------
	reg signed [DATA_WIDTH-1:0] x_reg [0:ITERATIONS];
	reg signed [DATA_WIDTH-1:0] y_reg [0:ITERATIONS];
	reg signed [ANGLE_WIDTH:0]  z_reg [0:ITERATIONS];

	integer k;
	always @(posedge clock) begin
		// Stage 0
		x_reg[0] <= x_start;
		y_reg[0] <= y_start;
		z_reg[0] <= z0_signed;

		for (k = 0; k < ITERATIONS; k = k + 1) begin
			if (!z_reg[k][ANGLE_WIDTH]) begin
				// z >= 0
				x_reg[k+1] <= x_reg[k] - (y_reg[k] >>> k);
				y_reg[k+1] <= y_reg[k] + (x_reg[k] >>> k);
				z_reg[k+1] <= z_reg[k] - atan_bam[k];
			end else begin
				// z < 0
				x_reg[k+1] <= x_reg[k] + (y_reg[k] >>> k);
				y_reg[k+1] <= y_reg[k] - (x_reg[k] >>> k);
				z_reg[k+1] <= z_reg[k] + atan_bam[k];
			end
		end
	end

	// Apply final sign correction for quadrants 01 and 10
	wire signed [DATA_WIDTH-1:0] x_out = need_flip_sign ? -x_reg[ITERATIONS] : x_reg[ITERATIONS];
	wire signed [DATA_WIDTH-1:0] y_out = need_flip_sign ? -y_reg[ITERATIONS] : y_reg[ITERATIONS];

	assign cosine = x_out;
	assign sine   = y_out;

endmodule

