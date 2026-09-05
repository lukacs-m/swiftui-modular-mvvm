#!/usr/bin/env python3
"""Expand the shipped Xcode file templates and compile their generated Swift."""
from pathlib import Path
from scaffold_test_support import copy_scaffold, run

with copy_scaffold() as root:
    for template, name, layer in [("MVVM", "ExampleScene", "Presentation"),
                                  ("UseCase Async", "ExampleAsync", "Domain"),
                                  ("UseCase Sync", "ExampleSync", "Domain")]:
        for source in (root / "Templates" / f"{template}.xctemplate").glob("*.swift"):
            text = source.read_text()
            for key, value in {"___FILEHEADER___": "Template compilation check",
                               "___VARIABLE_sceneName:identifier___": name,
                               "___VARIABLE_productName:identifier___": name,
                               "___VARIABLE_protocolName___": name + "UseCase"}.items():
                text = text.replace(key, value)
            assert "___" not in text, f"Unexpanded placeholder in {source}"
            filename = source.name.replace("___FILEBASENAME___", name)
            (root / "Packages" / layer / "Sources" / layer / filename).write_text(text)
    run(root, "make", "test")
print("All three Xcode templates compile with the scaffold settings.")
