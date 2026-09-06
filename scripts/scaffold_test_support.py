"""Disposable working copies shared by the template and bootstrap smoke tests."""
from contextlib import contextmanager
from pathlib import Path
import shutil
import subprocess
import tempfile

@contextmanager
def copy_scaffold():
    with tempfile.TemporaryDirectory(prefix="scaffold-check-") as directory:
        root = Path(directory) / "project"
        shutil.copytree(Path.cwd(), root, ignore=shutil.ignore_patterns(
            ".git", ".build", ".swiftpm", "*.xcodeproj", "DerivedData", "build",
            "Info.plist", ".DS_Store", "__pycache__"
        ))
        yield root

def run(root, *command, expected_success=True, env=None):
    result = subprocess.run(command, cwd=root, env=env, capture_output=True, text=True, timeout=600)
    if (result.returncode == 0) != expected_success:
        raise AssertionError(f"{' '.join(command)} returned {result.returncode}\n{result.stdout}\n{result.stderr}")
    print(f"Verified {' '.join(command)} ({'success' if expected_success else 'rejected'})", flush=True)
    return result
