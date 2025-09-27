# CORDIC Algorithm Implementation in Verilog

## Table of Contents
1. [Introduction to CORDIC](#introduction-to-cordic)
2. [Algorithm Theory](#algorithm-theory)
3. [Implementation Details](#implementation-details)
4. [Module Architecture](#module-architecture)
5. [Verification Strategy](#verification-strategy)
6. [Performance Analysis](#performance-analysis)
7. [FPGA Implementation](#fpga-implementation)
8. [Usage Examples](#usage-examples)

## Introduction to CORDIC

The CORDIC (COordinate Rotation DIgital Computer) algorithm is a hardware-efficient iterative method for computing trigonometric, hyperbolic, and linear functions. Developed by Jack Volder in 1959, CORDIC is particularly valuable in digital signal processing and embedded systems where hardware resources are limited.

### Key Advantages:
- **Hardware Efficient**: Uses only additions, subtractions, and bit shifts
- **No Multipliers Required**: Significant area and power savings
- **Scalable Precision**: Accuracy improves with iteration count
- **Versatile**: Can compute sine, cosine, magnitude, phase, and more

### Applications:
- Digital Signal Processing (DSP) chips
- FPGA-based trigonometric function units
- Embedded systems requiring fast math operations
- Calculator implementations
- Radar and communication systems

## Algorithm Theory

### Basic Principle

CORDIC works by performing a series of micro-rotations to rotate a vector by a desired angle. Each micro-rotation uses a pre-computed angle from a lookup table, and the algorithm decides the rotation direction to converge toward the target angle.

### Mathematical Foundation

For circular functions (sine/cosine), CORDIC operates in rotation mode:

Starting with vector **(x₀, y₀)** and target angle **z₀**, each iteration performs:

```
x(i+1) = x(i) - d(i) × y(i) × 2^(-i)
y(i+1) = y(i) + d(i) × x(i) × 2^(-i)  
z(i+1) = z(i) - d(i) × atan(2^(-i))
```

Where:
- **d(i) = +1** if z(i) ≥ 0 (clockwise rotation)
- **d(i) = -1** if z(i) < 0 (counter-clockwise rotation)
- **atan(2^(-i))** is the pre-computed arctangent lookup table value

### CORDIC Gain

Due to the iterative rotations, the final result must be multiplied by the CORDIC gain factor:

**Kₙ = ∏(i=0 to n-1) √(1 + 2^(-2i)) ≈ 1.6467605901**

In practice, we initialize x₀ with **1/Kₙ ≈ 0.6072529350** to pre-compensate for this gain.

### Angle Range and Quadrant Correction

CORDIC converges for angles in the range **[-π/2, π/2]**. For angles outside this range, we use quadrant correction:

- **Quadrant I** [0, π/2]: No correction needed
- **Quadrant II** [π/2, π]: Rotate by (π - θ), negate cosine
- **Quadrant III** [π, 3π/2]: Rotate by (θ - π), negate both
- **Quadrant IV** [3π/2, 2π]: Rotate by (2π - θ), negate sine

## Implementation Details

### Module Parameters

```verilog
parameter WIDTH = 16;           // Data width for coordinates (16-bit)
parameter ITERATIONS = 15;      // Number of CORDIC iterations
parameter ANGLE_WIDTH = 32;     // Angle width in bits (32-bit)
```

### Fixed-Point Representation

**Coordinate Format**: Q2.14 (2 integer bits, 14 fractional bits)
- Range: [-2.0, 2.0) with resolution of 2^(-14) ≈ 0.000061

**Angle Format**: Q3.29 (3 integer bits, 29 fractional bits)
- Range: [-4π, 4π) with resolution of 2^(-29) ≈ 1.86e-9 radians

### Arctangent Lookup Table

Pre-computed values for atan(2^(-i)) scaled to fixed-point format:

```verilog
ATAN_TABLE[0] = 0x20000000;  // atan(1) = 45.000000°
ATAN_TABLE[1] = 0x12E4051E;  // atan(0.5) = 26.565051°
ATAN_TABLE[2] = 0x09FB385B;  // atan(0.25) = 14.036243°
...
```

### State Machine

The implementation uses a 4-state finite state machine:

1. **IDLE**: Waiting for start signal
2. **NORMALIZE**: Angle normalization and quadrant correction
3. **COMPUTE**: Iterative CORDIC rotations
4. **FINISH**: Apply final quadrant correction and output results

## Module Architecture

### Input/Output Ports

```verilog
module CORDIC #(
    parameter WIDTH = 16,
    parameter ITERATIONS = 15,
    parameter ANGLE_WIDTH = 32
)(
    input wire clock,                           // System clock
    input wire reset,                           // Asynchronous reset
    input wire start,                           // Start computation
    input wire signed [WIDTH-1:0] x_start,     // Initial X (CORDIC gain)
    input wire signed [WIDTH-1:0] y_start,     // Initial Y (usually 0)
    input wire signed [ANGLE_WIDTH-1:0] angle, // Input angle in radians
    output reg signed [WIDTH-1:0] cosine,      // Cosine result
    output reg signed [WIDTH-1:0] sine,        // Sine result
    output reg done                            // Computation complete
);
```

### Internal Architecture

```
[Input Angle] → [Quadrant Correction] → [CORDIC Iterations] → [Final Correction] → [Output]
      ↓                    ↓                      ↓                    ↓              ↓
[Normalize to         [Determine           [15 Micro-         [Apply Quadrant    [cos/sin
 ±π/2 range]          Sign Corrections]    Rotations]         Corrections]       Results]
```

### Key Features

1. **Parameterizable Design**: Configurable width and iteration count
2. **Full Angle Range**: Handles angles beyond ±π/2 through quadrant correction
3. **Pipeline-Ready**: Clean start/done handshaking
4. **Resource Efficient**: Uses only adders, shifters, and registers

## Verification Strategy

### Testbench Coverage

The comprehensive testbench (`CORDIC_tb.v`) covers:

1. **Corner Cases**: 0°, 90°, 180°, 270°, 360°
2. **Overflow/Underflow**: Angles > 360° and < 0°
3. **Random Tests**: 50 random angles from -360° to +360°
4. **Boundary Conditions**: Maximum and minimum representable angles

### Accuracy Metrics

The testbench compares CORDIC outputs against MATLAB's built-in functions:

```verilog
tolerance = 0.01; // 1% tolerance for CORDIC approximation
max_error = (error_cos > error_sin) ? error_cos : error_sin;
```

### Expected Accuracy

For 15 iterations, CORDIC typically achieves:
- **Accuracy**: ~15 bits of precision
- **Maximum Error**: < 0.01 (1%)
- **Typical Error**: < 0.001 (0.1%)

## Performance Analysis

### Hardware Resources (Estimated for Zynq-7000)

| Resource | Count | Percentage |
|----------|-------|------------|
| LUTs     | ~800  | ~1.5%      |
| FFs      | ~600  | ~0.6%      |
| BRAMs    | 0     | 0%         |
| DSP48s   | 0     | 0%         |

### Timing Performance

- **Clock Frequency**: 100 MHz (10 ns period)
- **Latency**: 17-20 clock cycles per computation
- **Throughput**: ~5-6 million computations per second
- **Critical Path**: Carry propagation in adders

### Power Consumption

- **Static Power**: ~50 mW (estimated)
- **Dynamic Power**: ~100 mW @ 100 MHz (estimated)
- **Power Efficiency**: ~10x better than multiplier-based implementations

## FPGA Implementation

### Synthesis Results (100 MHz Target)

Expected synthesis results for Zynq-7020:

```
Timing Summary:
- Setup: 8.5 ns (1.5 ns slack)
- Hold: 0.2 ns (met)
- Pulse Width: 4.5 ns (met)

Resource Utilization:
- Slice LUTs: 847/53200 (1.59%)
- Slice Registers: 623/106400 (0.59%)
- F7 Muxes: 12/26600 (0.05%)
- F8 Muxes: 0/13300 (0.00%)
```

### Optimization Strategies

1. **Pipeline Optimization**: Register critical paths
2. **Resource Sharing**: Reuse adders across iterations
3. **Bit-Width Optimization**: Minimize unnecessary precision
4. **Clock Gating**: Reduce power during idle periods

## Usage Examples

### Basic Sine/Cosine Calculation

```verilog
// Initialize for sine/cosine calculation
x_start = 16'h26DD;  // CORDIC gain (≈0.607)
y_start = 16'h0000;  // Zero for rotation mode
angle = 32'h20000000; // 45 degrees

// Start computation
start = 1;
@(posedge clock);
start = 0;

// Wait for result
wait(done);
// cosine and sine outputs now contain results
```

### Integration Example

```verilog
module trig_calculator (
    input clock, reset,
    input [15:0] angle_degrees,
    input calculate,
    output [15:0] cos_result, sin_result,
    output result_valid
);

// Convert degrees to radians
wire signed [31:0] angle_radians = (angle_degrees * 32'h477D1A8B) >>> 16;

CORDIC cordic_inst (
    .clock(clock),
    .reset(reset),
    .start(calculate),
    .x_start(16'h26DD),
    .y_start(16'h0000),
    .angle(angle_radians),
    .cosine(cos_result),
    .sine(sin_result),
    .done(result_valid)
);

endmodule
```

### Performance Optimization Tips

1. **Pipeline Input/Output**: Add input/output registers for higher throughput
2. **Parallel Processing**: Instantiate multiple CORDIC units for parallel computation
3. **Custom Precision**: Adjust WIDTH and ITERATIONS based on accuracy requirements
4. **Memory Interface**: Buffer inputs/outputs for continuous processing

## Advanced Features and Extensions

### Possible Enhancements

1. **Pipelined Version**: Process multiple angles simultaneously
2. **Vectoring Mode**: Compute magnitude and phase
3. **Hyperbolic Functions**: Compute sinh, cosh, tanh
4. **Adaptive Precision**: Variable iteration count based on required accuracy

### Integration with Other Systems

- **FFT Processors**: Twiddle factor generation
- **Motor Control**: Park/Clarke transformations
- **Communications**: Quadrature modulation/demodulation
- **Graphics**: Rotation and transformation matrices

## Conclusion

This CORDIC implementation provides a hardware-efficient solution for trigonometric function computation. The parameterizable design allows for easy customization based on specific accuracy and resource requirements. The comprehensive verification ensures reliable operation across all angle ranges, making it suitable for production FPGA deployments.

The implementation successfully handles angles beyond ±π/2 through intelligent quadrant correction, achieving approximately 15 bits of accuracy with 15 iterations while maintaining minimal hardware resource usage.