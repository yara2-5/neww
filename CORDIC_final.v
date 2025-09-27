// CORDIC Final Implementation - Truly Parameterizable for Any ANGLE_WIDTH
// Uses include file approach for constants generation

`include "cordic_constants.vh"

module CORDIC_final #(
    parameter WIDTH = 16,           // Data width for coordinates
    parameter ITERATIONS = 15,      // Number of CORDIC iterations  
    parameter ANGLE_WIDTH = 32      // Angle width in bits (any value)
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

// Use macros from include file that adapt to ANGLE_WIDTH
localparam signed [ANGLE_WIDTH-1:0] PI = `PI_VALUE(ANGLE_WIDTH);
localparam signed [ANGLE_WIDTH-1:0] PI_2 = `PI_2_VALUE(ANGLE_WIDTH);
localparam signed [ANGLE_WIDTH-1:0] PI_3_2 = `PI_3_2_VALUE(ANGLE_WIDTH);
localparam signed [ANGLE_WIDTH-1:0] TWO_PI = `TWO_PI_VALUE(ANGLE_WIDTH);

// Generate ATAN table based on parameters
wire signed [ANGLE_WIDTH-1:0] ATAN_TABLE [0:ITERATIONS-1];
`GENERATE_ATAN_TABLE(ANGLE_WIDTH, ITERATIONS)

// Rest of implementation...
endmodule