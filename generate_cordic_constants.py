#!/usr/bin/env python3

"""
CORDIC Constants Generator
Generates parameterizable Verilog constants for any ANGLE_WIDTH
This solves the hardcoding issue by generating proper constants at design time
"""

import math
import sys

def generate_cordic_constants(angle_width, iterations, width):
    """Generate CORDIC constants for specified parameters"""
    
    # Calculate fractional bits (reserve 3 bits for integer part)
    frac_bits = max(angle_width - 3, 5)  # Minimum 5 fractional bits
    angle_scale = 2**frac_bits
    coord_scale = 2**(width - 2)
    
    print(f"// Generated CORDIC constants for ANGLE_WIDTH={angle_width}")
    print(f"// Fractional bits: {frac_bits}, Angle scale: {angle_scale}")
    print("")
    
    # Calculate angle constants
    pi_scaled = int(math.pi * angle_scale)
    pi_2_scaled = int(math.pi/2 * angle_scale)
    pi_3_2_scaled = int(3*math.pi/2 * angle_scale)
    two_pi_scaled = int(2*math.pi * angle_scale)
    
    # Calculate CORDIC gain
    cordic_gain_real = 1.0
    for i in range(iterations):
        cordic_gain_real *= math.sqrt(1 + 2**(-2*i))
    cordic_gain_compensated = 1.0 / cordic_gain_real
    cordic_gain_scaled = int(cordic_gain_compensated * coord_scale)
    
    print("// Angle constants")
    print(f"localparam signed [ANGLE_WIDTH-1:0] PI = {angle_width}'h{pi_scaled:0{(angle_width+3)//4}X};")
    print(f"localparam signed [ANGLE_WIDTH-1:0] PI_2 = {angle_width}'h{pi_2_scaled:0{(angle_width+3)//4}X};")
    print(f"localparam signed [ANGLE_WIDTH-1:0] PI_3_2 = {angle_width}'h{pi_3_2_scaled:0{(angle_width+3)//4}X};")
    print(f"localparam signed [ANGLE_WIDTH-1:0] TWO_PI = {angle_width}'h{two_pi_scaled:0{(angle_width+3)//4}X};")
    print("")
    
    print("// CORDIC gain compensation")
    print(f"localparam signed [WIDTH-1:0] CORDIC_GAIN = {width}'h{cordic_gain_scaled:0{(width+3)//4}X};")
    print("")
    
    # Calculate maximum reduction levels
    max_reduction_power = min(angle_width - 4, 10)  # Practical limit
    max_reducible_angle_pi = 2**(max_reduction_power + 1)  # In units of π
    max_reducible_angle_deg = max_reducible_angle_pi * 180
    
    print(f"// Maximum efficiently reducible angle: ±{max_reducible_angle_deg:.0f}° (±{max_reducible_angle_pi}π)")
    print(f"localparam MAX_REDUCTION_POWER = {max_reduction_power};")
    print("")
    
    # Generate arctangent lookup table
    print("// Arctangent lookup table")
    print(f"localparam [ANGLE_WIDTH-1:0] ATAN_TABLE [0:ITERATIONS-1] = {{")
    
    for i in range(iterations):
        atan_val = math.atan(2**(-i))
        atan_scaled = int(atan_val * angle_scale)
        
        if i == iterations - 1:
            print(f"    {angle_width}'h{atan_scaled:0{(angle_width+3)//4}X}   // atan(2^-{i})")
        else:
            print(f"    {angle_width}'h{atan_scaled:0{(angle_width+3)//4}X},  // atan(2^-{i})")
    
    print("};")
    print("")
    
    # Generate reduction logic template
    print("// Parameterizable angle reduction logic")
    print("// Insert this in your NORMALIZE state:")
    print("")
    
    for power in range(max_reduction_power, -1, -1):
        if power > 0:
            reduction_amount = f"(TWO_PI << {power})"
            angle_equiv = 2**(power + 1) * 180  # Equivalent in degrees
            print(f"if (temp_angle >= {reduction_amount}) begin  // >= {angle_equiv:.0f}°")
            print(f"    temp_angle <= temp_angle - {reduction_amount};")
            print(f"end else if (temp_angle <= -{reduction_amount}) begin")
            print(f"    temp_angle <= temp_angle + {reduction_amount};")
            print("end else ", end="")
        else:
            print("if (temp_angle >= TWO_PI) begin  // >= 360°")
            print("    temp_angle <= temp_angle - TWO_PI;")
            print("end else if (temp_angle <= -TWO_PI) begin")
            print("    temp_angle <= temp_angle + TWO_PI;")
            print("end else begin")
            print("    // Proceed to quadrant correction")
            print("    // ... (quadrant correction logic)")
            print("end")
    
    print("")
    
    # Generate statistics
    print(f"// Performance characteristics:")
    print(f"// - Angle range: ±{max_reducible_angle_deg:.0f}° efficiently")
    print(f"// - Reduction levels: {max_reduction_power + 1}")
    print(f"// - Max normalization cycles: {max_reduction_power + 3}")
    print(f"// - Fractional precision: {frac_bits} bits")
    print(f"// - Angle resolution: {2**(-frac_bits):.2e} radians")

def generate_test_module(angle_width):
    """Generate a test module for specific ANGLE_WIDTH"""
    
    module_name = f"CORDIC_{angle_width}bit"
    
    print(f"""
// Auto-generated CORDIC module for {angle_width}-bit angles
module {module_name} #(
    parameter WIDTH = 16,
    parameter ITERATIONS = 15
)(
    input wire clock,
    input wire reset, 
    input wire start,
    input wire signed [WIDTH-1:0] x_start,
    input wire signed [WIDTH-1:0] y_start,
    input wire signed [{angle_width-1}:0] angle,
    output reg signed [WIDTH-1:0] cosine,
    output reg signed [WIDTH-1:0] sine,
    output reg done
);

// Include the generated constants above
// ... (insert generated constants here)

// Standard CORDIC implementation with the generated constants
// ... (rest of implementation)

endmodule
""")

def main():
    """Main function to generate constants for different bit widths"""
    
    if len(sys.argv) != 4:
        print("Usage: python3 generate_cordic_constants.py <angle_width> <iterations> <width>")
        print("Example: python3 generate_cordic_constants.py 32 15 16")
        print("")
        print("Generating examples for common configurations:")
        print("")
        
        # Generate for common configurations
        configs = [
            (16, 12, 16),  # Compact version
            (24, 15, 16),  # Medium precision
            (32, 15, 16),  # Standard version
            (40, 18, 20),  # High precision
            (48, 20, 24),  # Very high precision
        ]
        
        for angle_w, iter_w, width_w in configs:
            print(f"=== Configuration: {angle_w}-bit angles, {iter_w} iterations, {width_w}-bit data ===")
            generate_cordic_constants(angle_w, iter_w, width_w)
            print("")
            print("="*80)
            print("")
    else:
        angle_width = int(sys.argv[1])
        iterations = int(sys.argv[2])
        width = int(sys.argv[3])
        
        generate_cordic_constants(angle_width, iterations, width)

if __name__ == "__main__":
    main()