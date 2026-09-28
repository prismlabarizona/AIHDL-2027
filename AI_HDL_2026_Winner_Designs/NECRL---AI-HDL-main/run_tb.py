#!/usr/bin/env python3
import os
import subprocess
import sys

# --- Configuration ---
# Root directory for sources
SRC_DIR = "AES128"
TB_DIR = "AES128/testbenches"
OUT_DIR = "outputs"

# Ensure output directory exists
os.makedirs(OUT_DIR, exist_ok=True)

# List of testbenches and their dependencies
# Format: "Option Name": { "tb": "path/to/tb.v", "sources": ["list", "of", "source.v"] }
TESTBENCHES = {
    "1": {
        "name": "Top Level Integration (AES_peripheral_tb)",
        "tb": f"{TB_DIR}/AES_peripheral_tb.v",  # This is in root based on your ls
        "sources": [
            "peripheral.v",
            f"{SRC_DIR}/AES_memory.v",
            f"{SRC_DIR}/AES_control_unit.v",
            f"{SRC_DIR}/AES_encryption_engine.v",
            f"{SRC_DIR}/AES_key_engine.v",
            f"{SRC_DIR}/mix_columns.v",
            f"{SRC_DIR}/sbox_lookup.v"
        ]
    },
    "2": {
        "name": "Control Unit (AES_control_unit_tb)",
        "tb": f"{TB_DIR}/AES_control_unit_tb.v",
        "sources": [f"{SRC_DIR}/AES_control_unit.v"]
    },
    "3": {
        "name": "Encryption Engine (AES_encryption_engine_tb)",
        "tb": f"{TB_DIR}/AES_encryption_engine_tb.v",
        "sources": [
            f"{SRC_DIR}/AES_encryption_engine.v",
            f"{SRC_DIR}/mix_columns.v",
            f"{SRC_DIR}/sbox_lookup.v"
        ]
    },
    "4": {
        "name": "Key Engine (AES_key_engine_tb)",
        "tb": f"{TB_DIR}/AES_key_engine_tb.v",
        "sources": [
            f"{SRC_DIR}/AES_key_engine.v",
            f"{SRC_DIR}/sbox_lookup.v"
        ]
    },
    "5": {
        "name": "Memory Interface (AES_memory_tb)",
        "tb": f"{TB_DIR}/AES_memory_tb.v",
        "sources": [f"{SRC_DIR}/AES_memory.v"]
    }
}

def print_menu():
    print("\n=== Select a Testbench to Run ===")
    for key, val in TESTBENCHES.items():
        print(f"[{key}] {val['name']}")
    print("[q] Quit")

def run_test(choice):
    if choice not in TESTBENCHES:
        print("Invalid selection.")
        return

    tb_info = TESTBENCHES[choice]
    print(f"\n[INFO] Compiling {tb_info['name']}...")

    # Construct Output Filename
    output_file = os.path.join(OUT_DIR, "test_sim")
    
    # Construct Compile Command
    # iverilog -g2012 -o outputs/test_sim [TB_FILE] [SOURCE_FILES...]
    cmd = ["iverilog", "-g2012", "-o", output_file, tb_info["tb"]] + tb_info["sources"]
    
    # Run Compiler
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print("\n[ERROR] Compilation Failed:")
        print(result.stderr)
        return

    print("[INFO] Compilation Successful. Running Simulation...")
    print("-" * 40)
    
    # Run Simulation
    # vvp outputs/test_sim
    subprocess.run(["vvp", output_file])
    print("-" * 40)

if __name__ == "__main__":
    while True:
        print_menu()
        user_input = input("\nEnter choice: ").strip().lower()
        
        if user_input == 'q':
            print("Exiting.")
            sys.exit(0)
        
        run_test(user_input)