#!/usr/bin/env python3
"""Compare generated resolution roots without depending on their root-specific hashes."""
import json
from pathlib import Path

paths = [Path("Package.resolved"), Path("Packages/AppModules/Package.resolved")]
pins = []
for path in paths:
    if not path.is_file():
        raise SystemExit(f"Missing {path}; run make resolve resolve-app and review the generated pins.")
    pins.append({pin["identity"]: pin["state"] for pin in json.loads(path.read_text())["pins"]})
if any(value != pins[0] for value in pins[1:]):
    raise SystemExit("Dependency pins differ between the app and AppModules roots.")
print("Dependency pins agree across app and AppModules.")
