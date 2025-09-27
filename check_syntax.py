#!/usr/bin/env python3

"""
Basic Verilog Syntax Checker for CORDIC files
This script performs basic syntax validation on the Verilog files
"""

import re
import sys

def check_verilog_syntax(filename):
    """Basic syntax checking for Verilog files"""
    
    print(f"Checking syntax for {filename}...")
    
    try:
        with open(filename, 'r') as f:
            content = f.read()
    except FileNotFoundError:
        print(f"ERROR: File {filename} not found!")
        return False
    
    errors = []
    warnings = []
    line_num = 0
    
    # Split into lines for line-by-line checking
    lines = content.split('\n')
    
    # Basic syntax checks
    paren_count = 0
    bracket_count = 0
    brace_count = 0
    in_comment_block = False
    
    for line_num, line in enumerate(lines, 1):
        line = line.strip()
        
        # Skip empty lines
        if not line:
            continue
            
        # Handle comment blocks
        if '/*' in line and '*/' in line:
            # Single line comment block
            continue
        elif '/*' in line:
            in_comment_block = True
            continue
        elif '*/' in line:
            in_comment_block = False
            continue
        elif in_comment_block:
            continue
            
        # Skip single line comments
        if line.startswith('//'):
            continue
            
        # Remove inline comments for checking
        if '//' in line:
            line = line[:line.index('//')]
            
        # Count parentheses, brackets, braces
        paren_count += line.count('(') - line.count(')')
        bracket_count += line.count('[') - line.count(']')
        brace_count += line.count('{') - line.count('}')
        
        # Check for common syntax issues
        if line.endswith(',') and ('end' in line or 'endmodule' in line):
            errors.append(f"Line {line_num}: Unexpected comma before 'end' statement")
            
        if 'begin' in line and not line.endswith('begin'):
            warnings.append(f"Line {line_num}: 'begin' not at end of line")
            
        # Check for missing semicolons (basic check)
        if (any(keyword in line for keyword in ['reg', 'wire', 'input', 'output', 'parameter', 'localparam']) 
            and not line.endswith(';') and not line.endswith(',') and not line.endswith(')')):
            warnings.append(f"Line {line_num}: Possible missing semicolon")
    
    # Check balanced parentheses/brackets/braces
    if paren_count != 0:
        errors.append(f"Unbalanced parentheses (count: {paren_count})")
    if bracket_count != 0:
        errors.append(f"Unbalanced brackets (count: {bracket_count})")
    if brace_count != 0:
        errors.append(f"Unbalanced braces (count: {brace_count})")
    
    # Check for required Verilog constructs
    if 'module' not in content:
        errors.append("No module declaration found")
    if 'endmodule' not in content:
        errors.append("No endmodule found")
        
    # Report results
    if errors:
        print(f"  ERRORS found ({len(errors)}):")
        for error in errors:
            print(f"    - {error}")
    
    if warnings:
        print(f"  WARNINGS found ({len(warnings)}):")
        for warning in warnings:
            print(f"    - {warning}")
    
    if not errors and not warnings:
        print(f"  ✓ No syntax issues found in {filename}")
        
    return len(errors) == 0

def check_module_interfaces():
    """Check if module interfaces are compatible"""
    
    print("\nChecking module interface compatibility...")
    
    # Basic check to ensure testbench can instantiate the CORDIC module
    try:
        with open('CORDIC.v', 'r') as f:
            cordic_content = f.read()
        with open('CORDIC_tb.v', 'r') as f:
            tb_content = f.read()
    except FileNotFoundError as e:
        print(f"ERROR: Cannot read files for interface check: {e}")
        return False
    
    # Extract module port list from CORDIC.v
    module_match = re.search(r'module\s+CORDIC[^(]*\((.*?)\);', cordic_content, re.DOTALL)
    if not module_match:
        print("ERROR: Cannot parse CORDIC module ports")
        return False
    
    ports = module_match.group(1)
    
    # Extract port names
    port_names = []
    for line in ports.split('\n'):
        line = line.strip()
        if 'input' in line or 'output' in line:
            # Extract port name (simplified)
            words = line.split()
            if len(words) >= 2:
                port_name = words[-1].replace(',', '').replace(';', '')
                # Handle array notation
                if '[' in port_name:
                    port_name = port_name.split('[')[0]
                port_names.append(port_name)
    
    print(f"  Found {len(port_names)} ports in CORDIC module")
    
    # Check if testbench references these ports
    missing_connections = []
    for port in port_names:
        if port not in tb_content:
            missing_connections.append(port)
    
    if missing_connections:
        print(f"  WARNING: Ports not found in testbench: {missing_connections}")
    else:
        print("  ✓ All module ports referenced in testbench")
    
    return len(missing_connections) == 0

def main():
    """Main function to check all files"""
    
    print("=== CORDIC Verilog Syntax Checker ===\n")
    
    files_to_check = ['CORDIC.v', 'CORDIC_tb.v']
    all_good = True
    
    # Check individual files
    for filename in files_to_check:
        if not check_verilog_syntax(filename):
            all_good = False
        print()
    
    # Check interface compatibility
    if not check_module_interfaces():
        all_good = False
    
    # Final summary
    print("\n=== Summary ===")
    if all_good:
        print("✓ All syntax checks passed!")
        print("  The Verilog files appear to be syntactically correct.")
        print("  You can proceed with simulation using a Verilog simulator.")
    else:
        print("✗ Some issues were found!")
        print("  Please review and fix the reported issues.")
    
    return 0 if all_good else 1

if __name__ == "__main__":
    sys.exit(main())