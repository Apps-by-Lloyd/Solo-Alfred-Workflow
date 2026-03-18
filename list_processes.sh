#!/bin/bash

if [ -n "$solo_command" ]; then
    python3 - "$solo_command" << 'PYEOF'
import subprocess, sys

solo_command = sys.argv[1]

applescript = f'''
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
subprocess.run(["osascript", "-e", applescript])
PYEOF
    echo '{"items":[]}'
    exit 0
fi

RESPONSE=$(curl -s --max-time 5 "http://localhost:$HTTP_API_PORT/projects" 2>/dev/null)

if [ -z "$RESPONSE" ] || [ "$RESPONSE" = "null" ]; then
    echo '{"items":[{"title":"Solo is not responding","valid":false}]}'
    exit 0
fi

python3 - "$project_id" "$RESPONSE" << 'PYEOF'
import json, sys

project_id = sys.argv[1]

if not project_id:
    print(json.dumps({"items": [{"title": "No project_id received", "valid": False}]}))
    sys.exit(0)

projects = json.loads(sys.argv[2])
project = next((p for p in projects if str(p["id"]) == project_id), None)

if not project:
    print(json.dumps({"items": [{"title": f"Project not found (id={project_id})", "valid": False}]}))
    sys.exit(0)

project_name = project["name"]
processes = project.get("processes", [])

if not processes:
    print(json.dumps({"items": [{"title": "No processes configured", "valid": False}]}))
    sys.exit(0)

items = []
for proc in processes:
    name = proc["name"]
    command = proc.get("command", "")
    status = proc.get("status", "unknown")
    is_running = status == "running"
    status_icon = "▶ Running" if is_running else "⏹ Stopped"

    cmd_label = "Restart" if is_running else "Start"
    cmd_command = f"{project_name} {name} {'Restart' if is_running else 'Start'} process"

    items.append({
        "title": name,
        "subtitle": f"{status_icon} · {command}  ·  ⌘ {cmd_label.lower()}  ·  ⌃ stop",
        "arg": "",
        "valid": True,
        "uid": str(proc["id"]),
        "match": f"{name} {command}",
        "variables": {
            "project_id": project_id,
            "project_name": project_name,
            "process_name": name,
            "solo_command": f"{project_name} {name} go to process",
        },
        "mods": {
            "cmd": {
                "valid": True,
                "subtitle": f"⌘ {cmd_label} process: {name}",
                "variables": {
                    "project_name": project_name,
                    "process_name": name,
                    "solo_command": cmd_command,
                }
            },
            "ctrl": {
                "valid": is_running,
                "subtitle": f"⌃ Stop process: {name}" if is_running else f"⌃ Already stopped: {name}",
                "variables": {
                    "project_name": project_name,
                    "process_name": name,
                    "solo_command": f"{project_name} {name} Stop process",
                }
            },
        }
    })

print(json.dumps({"items": items, "skipknowledge": True}))
PYEOF
