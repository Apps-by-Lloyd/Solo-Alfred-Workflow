#!/bin/bash

python3 - "$solo_command" << 'PYEOF'
import subprocess, sys

solo_command = sys.argv[1]

if not solo_command:
    print("Error: solo_command is empty", file=sys.stderr)
    sys.exit(1)

applescript = f'''
-- Dismiss Alfred first (key code 53 = Escape), then activate Solo.
-- This prevents keystrokes landing in Alfred when Solo was already frontmost.
tell application "System Events"
    key code 53
end tell

delay 0.2

tell application "Solo"
    activate
end tell

delay 0.2

tell application "System Events"
    tell process "Solo"
        keystroke "k" using command down
        delay 0.4
        keystroke "{solo_command}"
        delay 0.3
        key code 36
    end tell
end tell
'''

result = subprocess.run(["osascript", "-e", applescript], capture_output=True, text=True)
if result.returncode != 0:
    print(f"AppleScript error: {result.stderr}", file=sys.stderr)
PYEOF
