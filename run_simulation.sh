#!/bin/bash

# CORDIC Simulation Script
# This script compiles and runs the CORDIC testbench

echo "=== CORDIC Verilog Simulation ==="
echo "Compiling design files..."

# Create a work directory
mkdir -p work

# Compile Verilog files using iverilog (Icarus Verilog)
if command -v iverilog &> /dev/null; then
    echo "Using Icarus Verilog (iverilog)..."
    iverilog -o work/cordic_sim -g2012 CORDIC.v CORDIC_tb.v
    
    if [ $? -eq 0 ]; then
        echo "Compilation successful!"
        echo "Running simulation..."
        cd work
        ./cordic_sim
        cd ..
        
        if [ -f work/cordic_tb.vcd ]; then
            echo "Waveform file generated: work/cordic_tb.vcd"
            echo "You can view it with: gtkwave work/cordic_tb.vcd"
        fi
    else
        echo "Compilation failed!"
        exit 1
    fi

# Alternative: try with ModelSim/QuestaSim
elif command -v vsim &> /dev/null; then
    echo "Using ModelSim/QuestaSim..."
    
    # Create library and compile
    vlib work
    vlog -sv CORDIC.v CORDIC_tb.v
    
    if [ $? -eq 0 ]; then
        echo "Compilation successful!"
        echo "Running simulation..."
        vsim -c -do "run -all; quit" CORDIC_tb
    else
        echo "Compilation failed!"
        exit 1
    fi

# Alternative: try with Verilator
elif command -v verilator &> /dev/null; then
    echo "Using Verilator..."
    
    # Verilator compilation (more complex setup needed)
    echo "Verilator setup would require additional C++ wrapper"
    echo "Please use iverilog or ModelSim for this testbench"
    exit 1

else
    echo "No supported Verilog simulator found!"
    echo "Please install one of the following:"
    echo "  - Icarus Verilog (iverilog) - Open source"
    echo "  - ModelSim/QuestaSim - Commercial"
    echo "  - Vivado Simulator (xsim) - Free with Vivado"
    exit 1
fi

echo "Simulation complete!"

# If MATLAB is available, run the MATLAB model
if command -v matlab &> /dev/null; then
    echo ""
    echo "Running MATLAB golden model..."
    matlab -batch "matlab_model; exit;"
elif command -v octave &> /dev/null; then
    echo ""
    echo "Running Octave golden model..."
    octave --eval "matlab_model; exit;"
else
    echo ""
    echo "MATLAB/Octave not found. Please run matlab_model.m manually for golden reference."
fi

echo ""
echo "=== Simulation Summary ==="
echo "Files generated:"
echo "  - CORDIC.v (main module)"
echo "  - CORDIC_tb.v (testbench)"
echo "  - matlab_model.m (golden reference)"
echo "  - cordic_constraints.xdc (FPGA constraints)"
echo "  - CORDIC_Documentation.md (detailed documentation)"
echo ""
echo "For FPGA implementation:"
echo "  1. Create new Vivado project"
echo "  2. Add CORDIC.v as design source"
echo "  3. Add cordic_constraints.xdc as constraints"
echo "  4. Set target device to Zynq-7020 (or your target)"
echo "  5. Run synthesis and implementation"