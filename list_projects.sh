#!/bin/bash

# Ensure Solo is running
if ! pgrep -x "Solo" > /dev/null 2>&1; then
    open -a "Solo"
    for i in $(seq 1 10); do
        sleep 1
        curl -s --max-time 1 "http://localhost:$HTTP_API_PORT/projects" > /dev/null 2>&1 && break
    done
fi

RESPONSE=$(curl -s --max-time 5 "http://localhost:$HTTP_API_PORT/projects" 2>/dev/null)

if [ -z "$RESPONSE" ] || [ "$RESPONSE" = "null" ]; then
    echo '{"items":[{"title":"Solo is not responding","subtitle":"Make sure Solo is running","valid":false}]}'
    exit 0
fi

python3 - "$RESPONSE" << 'PYEOF'
import json, sys

projects = json.loads(sys.argv[1])
items = []

for project in projects:
    name = project["name"]
    process_count = len(project.get("processes", []))
    running = sum(1 for p in project.get("processes", []) if p.get("status") == "running")
    subtitle = f"{process_count} process{'es' if process_count != 1 else ''}"
    if running > 0:
        subtitle += f" · {running} running"

    items.append({
        "title": name,
        "subtitle": subtitle + "  ·  ⌘ start auto  ·  ⌃ stop all  ·  ⇧ go to project",
        "arg": "",
        "valid": True,
        "uid": str(project["id"]),
        # Plain enter: drill down into processes
        "variables": {
            "project_id": str(project["id"]),
            "project_name": name,
        },
        "mods": {
            # ⌘: Start all auto-start processes — bypasses process list
            "cmd": {
                "valid": True,
                "subtitle": f"⌘ Start auto-start processes in {name}",
                "variables": {
                    "project_name": name,
                    "solo_command": f"{name} Start auto-start processes",
                }
            },
            # ⌃: Stop all processes — bypasses process list
            "ctrl": {
                "valid": True,
                "subtitle": f"⌃ Stop all processes in {name}",
                "variables": {
                    "project_name": name,
                    "solo_command": f"{name} Stop all processes",
                }
            },
            # ⇧: Go to project — bypasses process list
            "shift": {
                "valid": True,
                "subtitle": f"⇧ Go to project {name}",
                "variables": {
                    "project_name": name,
                    "solo_command": f"{name} Go to project",
                }
            },
        }
    })

print(json.dumps({"items": items}))
PYEOF
