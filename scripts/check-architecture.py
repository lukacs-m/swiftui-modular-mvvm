#!/usr/bin/env python3
"""Check the scaffold's declared package graph and source import boundaries."""
import json
from pathlib import Path
import re
import subprocess

allowed = {
    "Common": set(), "Model": {"Common"}, "Domain": {"Common", "Model"},
    "Data": {"Common", "Model", "Domain"}, "DI": {"Common", "Model", "Domain", "Data"},
    "Presentation": {"Common", "Model", "Domain", "DI"},
}
errors = []
for layer, dependencies in allowed.items():
    package = Path("Packages") / layer
    result = subprocess.run(["swift", "package", "--package-path", str(package), "dump-package"],
                            check=True, capture_output=True, text=True)
    manifest = json.loads(result.stdout)
    for dependency in manifest["dependencies"]:
        for local in dependency.get("fileSystem", []):
            name = Path(local["path"]).name
            if name not in dependencies:
                errors.append(f"{layer}: forbidden dependency {name}")
        for remote in dependency.get("sourceControl", []):
            identity = remote["identity"]
            if identity == "factory" and layer not in {"DI", "Presentation"}:
                errors.append(f"{layer}: Factory belongs in DI (or Presentation tests)")
            if identity == "sqlite-data" and layer != "Data":
                errors.append(f"{layer}: SQLiteData belongs in Data")
    if "defaultIsolation(MainActor.self)" in (package / "Package.swift").read_text() and layer != "Presentation":
        errors.append(f"{layer}: only Presentation may default to MainActor")
    for path in (package / "Sources").rglob("*.swift"):
        source = path.read_text()
        for module in re.findall(r"^\s*(?:@_exported\s+)?(?:(?:public|internal|private|package)\s+)?import\s+(\w+)", source, re.M):
            if module in allowed and module not in dependencies:
                errors.append(f"{path}: forbidden import {module}")
            if module in {"FactoryKit", "FactoryTesting"} and (layer != "DI" or module == "FactoryTesting"):
                errors.append(f"{path}: import DI for registration APIs; Testing belongs in test targets")
            if module == "SwiftData" or (module == "SQLiteData" and layer != "Data"):
                errors.append(f"{path}: persistence must use SQLiteData in Data")
            if module in {"SwiftUI", "UIKit", "AppKit"} and layer in {"Model", "Domain", "Data", "DI"}:
                errors.append(f"{path}: UI belongs in Presentation")
if errors:
    raise SystemExit("\n".join(errors))
print("Package dependencies and source imports respect the six-layer boundaries.")
