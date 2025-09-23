#!/usr/bin/env python3
"""Test if the UI updates when a file is loaded"""

import subprocess
import time
import os

print("Testing UI update when file is loaded...")

# Check if app is running
result = subprocess.run(["pgrep", "-f", "ParqViewApp"], capture_output=True, text=True)
if result.returncode == 0:
    print("✅ ParqView app is running")
    
    # Try to open a file using AppleScript
    script = '''
    tell application "System Events"
        tell process "ParqViewApp"
            set frontmost to true
            keystroke "o" using command down
        end tell
    end tell
    '''
    
    print("Sending Cmd+O to open file dialog...")
    subprocess.run(["osascript", "-e", script])
    
    # Give it time to open
    time.sleep(2)
    
    # Check the log
    log_path = os.path.expanduser("~/parqview_debug.log")
    if os.path.exists(log_path):
        with open(log_path, 'r') as f:
            lines = f.readlines()
            recent_lines = lines[-20:] if len(lines) > 20 else lines
            
            print("\nRecent log entries:")
            for line in recent_lines:
                print(line.strip())
    
else:
    print("❌ ParqView app is not running")
    print("Please run: .build/debug/ParqViewApp")