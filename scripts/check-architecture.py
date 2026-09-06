#!/usr/bin/env python3
"""Check the scaffold's target graph, isolation, and source import boundaries."""
import json
from pathlib import Path
import re
import subprocess

package = Path("Packages/AppModules")
allowed = {
    "Common": set(), "Model": {"Common"}, "Domain": {"Common", "Model"},
    "Data": {"Common", "Model", "Domain"}, "DI": {"Common", "Model", "Domain", "Data"},
    "Presentation": {"Common", "Model", "Domain", "DI"},
}
allowed_tests = {
    "DomainTests": {"Domain", "Model"},
    "DataTests": {"Data", "Domain", "Model"},
    "PresentationTests": {"Presentation", "Domain", "Model", "DI"},
}
features = {"ExistentialAny", "InternalImportsByDefault", "MemberImportVisibility",
            "InferIsolatedConformances", "NonisolatedNonsendingByDefault"}
result = subprocess.run(["swift", "package", "--package-path", str(package), "dump-package"],
                        capture_output=True, text=True)
if result.returncode:
    raise SystemExit(result.stderr)
manifest = json.loads(result.stdout)
targets = {target["name"]: target for target in manifest["targets"]}
expected = allowed | allowed_tests
errors = []
for name in sorted(expected.keys() - targets.keys()):
    errors.append(f"Missing target {name}")
for name in sorted(targets.keys() - expected.keys()):
    errors.append(f"Unexpected target {name}; declare its architecture rules")

for name, target in targets.items():
    if name not in expected:
        continue
    is_test = name in allowed_tests
    if target["type"] != ("test" if is_test else "regular"):
        errors.append(f"{name}: incorrect target type")
    source_path = Path("Tests" if is_test else "Sources") / name
    if Path(target.get("path") or source_path) != source_path:
        errors.append(f"{name}: sources must live in {source_path}")
    if not (package / source_path).is_dir():
        errors.append(f"{name}: missing source directory {source_path}")

    for dependency in target["dependencies"]:
        kind, values = next(iter(dependency.items()))
        module = values[0]
        identity = (values[1] or "").lower() if kind == "product" else ""
        if module in targets and module not in expected[name]:
            errors.append(f"{name}: forbidden dependency {module}")
        if identity == "factory" or module in {"Factory", "FactoryKit", "FactoryTesting"}:
            if (name, module) not in {("DI", "FactoryKit"), ("PresentationTests", "FactoryTesting")}:
                errors.append(f"{name}: FactoryKit belongs in DI; FactoryTesting belongs in PresentationTests")
        if (identity == "sqlite-data" or module == "SQLiteData") and name != "Data":
            errors.append(f"{name}: SQLiteData belongs in Data")

    swift_settings = [setting for setting in target["settings"] if setting["tool"] == "swift"]
    isolation = [setting for setting in swift_settings if "defaultIsolation" in setting["kind"]]
    expects_main_actor = name in {"Presentation", "PresentationTests"}
    if expects_main_actor:
        if len(isolation) != 1 or isolation[0]["kind"]["defaultIsolation"]["_0"] != "MainActor" or isolation[0].get("condition"):
            errors.append(f"{name}: must default to MainActor on every platform")
    elif isolation:
        errors.append(f"{name}: only Presentation and PresentationTests may set default isolation")
    enabled = {setting["kind"]["enableUpcomingFeature"]["_0"] for setting in swift_settings
               if "enableUpcomingFeature" in setting["kind"] and not setting.get("condition")}
    if missing := features - enabled:
        errors.append(f"{name}: missing Swift features {', '.join(sorted(missing))}")

    for path in (package / source_path).rglob("*.swift"):
        source = path.read_text()
        imports = re.findall(
            r"^\s*(?:(?:@_exported|@testable|@preconcurrency)\s+)*"
            r"(?:(?:public|internal|private|fileprivate|package)\s+)?import\s+"
            r"(?:(?:typealias|struct|class|enum|protocol|let|var|func)\s+)?(\w+)", source, re.M)
        for module in imports:
            if module in targets and module not in expected[name]:
                errors.append(f"{path}: forbidden import {module}")
            if module in {"Factory", "FactoryKit", "FactoryTesting"}:
                if (name, module) not in {("DI", "FactoryKit"), ("PresentationTests", "FactoryTesting")}:
                    errors.append(f"{path}: import DI for registration APIs; FactoryTesting belongs in PresentationTests")
            if module == "SwiftData" or (module == "SQLiteData" and name != "Data"):
                errors.append(f"{path}: persistence must use SQLiteData in Data")
            if module in {"SwiftUI", "UIKit", "AppKit"} and name not in {"Common", "Presentation", "PresentationTests"}:
                errors.append(f"{path}: UI belongs in Presentation")
if errors:
    raise SystemExit("\n".join(errors))
print("Target dependencies, isolation, and imports respect the six-layer boundaries.")
