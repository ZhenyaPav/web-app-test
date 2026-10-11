#!/usr/bin/env python3
"""Small offline check: invalid or ambiguous input must never change the manifest."""
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

root = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory() as directory:
    work = Path(directory)
    (work / "deploy").mkdir()
    manifest = work / "deploy/deployment.yaml"
    shutil.copy(root / "deploy/deployment.yaml", manifest)
    original = manifest.read_text()
    command = [sys.executable, str(root / "scripts/set-image.py")]
    bad = subprocess.run(command + ["sha256:bad"], cwd=work, capture_output=True)
    assert bad.returncode != 0 and manifest.read_text() == original
    digest = "sha256:" + "a" * 64
    subprocess.run(command + [digest], cwd=work, check=True)
    expected_image = "ghcr.io/zhenyapav/web-app-test@" + digest
    assert expected_image in manifest.read_text() and ":bootstrap" not in manifest.read_text()
    subprocess.run(command + [digest], cwd=work, check=True)
    ambiguous = manifest.read_text() + "\n  image: " + expected_image + "\n"
    manifest.write_text(ambiguous)
    bad = subprocess.run(command + [digest], cwd=work, capture_output=True)
    assert bad.returncode != 0 and manifest.read_text() == ambiguous
print("Image promotion input, idempotence, and ambiguity checks passed")
