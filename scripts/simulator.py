#!/usr/bin/env python3
"""Select an installed iPhone runtime without depending on a device model name."""
import json
from pathlib import Path
import re
import subprocess

result = subprocess.run(["xcrun", "simctl", "list", "devices", "available", "--json"], capture_output=True, text=True)
if result.returncode == 0:
    minimum = int(re.search(r'iOS: "(\d+)', Path("project.yml").read_text())[1])
    devices = [device for runtime, group in json.loads(result.stdout)["devices"].items()
               if "iOS" in runtime and int(runtime.split("iOS-")[1].split("-")[0]) >= minimum
               for device in group if device["name"].startswith("iPhone")]
    devices.sort(key=lambda device: device["state"] != "Booted")
    if devices:
        print("platform=iOS Simulator,id=" + devices[0]["udid"])
