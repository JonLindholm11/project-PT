#!/usr/bin/env python3
"""
Test script to simulate Lua output for testing the tracker
"""

import time
import sys
import random

# Sample test events
TEST_EVENTS = [
    "NEW: Species 25 caught! (PID: 0x12345678, Location: party)",
    "NEW: Species 4 caught! (PID: 0x23456789, Location: party)",
    "LEVEL UP: Species 25 leveled up 5 -> 6 (PID: 0x12345678)",
    "LEVEL UP: Species 25 leveled up 6 -> 7 (PID: 0x12345678)",
    "EVOLUTION: Species 25 evolved to 26 (PID: 0x12345678)",
    "MOVED: Species 4 moved from party to box (PID: 0x23456789)",
    "NEW: Species 16 caught! (PID: 0x34567890, Location: party)",
    "LEVEL UP: Species 26 leveled up 7 -> 8 (PID: 0x12345678)",
    "DEATH: Species 16 fainted! (PID: 0x34567890)",
    "REMOVED: Species 16 no longer in save (PID: 0x34567890)",
]

def simulate_continuous():
    """Simulate continuous Lua output"""
    print("=== SIMULATING LUA OUTPUT ===")
    print("Press Ctrl+C to stop\n")
    
    try:
        # Output some events with delays
        for event in TEST_EVENTS:
            print(event)
            sys.stdout.flush()
            time.sleep(random.uniform(1, 3))
        
        print("\n=== All test events sent ===")
        print("Waiting... (press Ctrl+C to stop)")
        
        # Keep running
        while True:
            time.sleep(10)
            
    except KeyboardInterrupt:
        print("\n=== Simulation stopped ===")

def generate_test_log(filename="test_output.log"):
    """Generate a test log file"""
    print(f"Generating test log file: {filename}")
    
    with open(filename, 'w') as f:
        f.write("Nuzlocke Tracker initialized!\n")
        f.write("Monitoring party and PC boxes (DMA-safe)...\n\n")
        
        for event in TEST_EVENTS:
            f.write("=== CHANGES DETECTED ===\n")
            f.write(event + "\n")
            f.write("========================\n\n")
    
    print(f"✓ Test log created: {filename}")
    print(f"\nTest with: python nuzlocke_tracker.py --log-file {filename} --process-existing")

def main():
    import argparse
    
    parser = argparse.ArgumentParser(description='Generate test data for Nuzlocke Tracker')
    parser.add_argument(
        '--mode',
        choices=['continuous', 'file'],
        default='continuous',
        help='Mode: continuous (pipe to tracker) or file (generate test log)'
    )
    parser.add_argument(
        '--output',
        default='test_output.log',
        help='Output filename for file mode'
    )
    
    args = parser.parse_args()
    
    if args.mode == 'continuous':
        simulate_continuous()
    else:
        generate_test_log(args.output)

if __name__ == '__main__':
    main()
