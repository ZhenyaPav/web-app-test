#!/usr/bin/env python3
"""Change exactly one app image; refuse malformed input or ambiguous manifests."""
import re
import sys
from pathlib import Path

if len(sys.argv) != 2 or not re.fullmatch(r"sha256:[0-9a-f]{64}", sys.argv[1]):
    sys.exit("Usage: scripts/set-image.py sha256:<64 lowercase hex characters>")
path = Path("deploy/deployment.yaml")
content = path.read_text()
updated, count = re.subn(
    r"(?m)^( +image: )ghcr\.io/zhenyapav/web-app-test(?::[\w.-]+|@sha256:[0-9a-f]{64})[ \t]*$",
    rf"\g<1>ghcr.io/zhenyapav/web-app-test@{sys.argv[1]}",
    content,
)
if count != 1:
    sys.exit(f"Expected one app image, found {count}; file left unchanged")
path.write_text(updated)
