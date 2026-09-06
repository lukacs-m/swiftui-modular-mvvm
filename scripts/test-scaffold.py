#!/usr/bin/env python3
"""Exercise the public bootstrap commands without touching the user's project."""
import os
from pathlib import Path
from scaffold_test_support import copy_scaffold, run

with copy_scaffold() as root:
    # Xcode 26.4 generates actor-unsafe accessors for MainActor package catalogs.
    symbols = root.parent / "string-symbols"
    symbols.mkdir()
    catalog = root / "Packages/Presentation/Sources/Presentation/Resources/Localizable.xcstrings"
    run(root, "xcrun", "xcstringstool", "generate-symbols", str(catalog),
        "--output-directory", str(symbols), "--language", "swift")
    generated = list(symbols.glob("*.swift"))
    assert generated and all(not source.read_text().strip() for source in generated), \
        "Keep unused string-symbol generation disabled for Xcode 26.4 compatibility."
    original = (root / "project.yml").read_bytes()
    app_name = original.decode().splitlines()[0].split(":", 1)[1].strip()
    for name in ["class", "App", "Data", "Bad_Name", "9App", "Bad-Name"]:
        run(root, "make", "rename", f"NAME={name}", expected_success=False)
        assert (root / "project.yml").read_bytes() == original
        assert (root / f"App/{app_name}/{app_name}.swift").exists()
    # Force an external resolver failure while using the real Makefile entry point.
    shim = root.parent / "bin"
    shim.mkdir()
    resolver = shim / "xcodebuild"
    resolver.write_text("#!/bin/sh\nexit 42\n")
    resolver.chmod(0o755)
    environment = dict(os.environ, PATH=str(shim) + os.pathsep + os.environ["PATH"])
    result = run(root, "make", "setup", "RESOLVE=1", expected_success=False, env=environment)
    assert "Setup complete" not in result.stdout

    pins = (root / "Package.resolved").read_bytes()
    run(root, "make", "new-project", "NAME=AuditApp")
    entry = (root / "App/AuditApp/AuditApp.swift").read_bytes()
    run(root, "make", "new-project")
    assert (root / "App/AuditApp/AuditApp.swift").read_bytes() == entry
    assert (root / "Packages/Domain/Sources/Domain/DomainError.swift").exists()
    assert (root / "Packages/Presentation/Sources/Presentation/ViewState.swift").exists()
    run(root, "make", "rename", "NAME=RenamedApp")
    run(root, "make", "clean")
    assert (root / "Package.resolved").read_bytes() == pins
    run(root, "make", "generate")
    app_pins = root / "RenamedApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
    assert app_pins.read_bytes() == pins
    run(root, "make", "check-locks", "check-architecture", "test", "build")

with copy_scaffold() as root:
    run(root, "git", "init", "--quiet")
    run(root, "git", "add", ".")
    run(root, "git", "-c", "user.name=Scaffold Test", "-c", "user.email=scaffold@example.invalid",
        "-c", "commit.gpgsign=false", "commit", "--quiet", "-m", "Smoke test baseline")
    article = root / "Packages/Model/Sources/Model/Article.swift"
    if article.exists():
        article.write_text(article.read_text() + "\n// Uncommitted customization.\n")
        before = article.read_bytes()
        run(root, "make", "new-project", expected_success=False)
        assert article.read_bytes() == before
    forbidden = root / "Packages/Domain/Sources/Domain/Forbidden.swift"
    forbidden.write_text("import SwiftUI\n")
    run(root, "make", "check-architecture", expected_success=False)
print("Bootstrap, pin preservation, and architecture smoke checks passed.")
