"""Compatibility entry point. Catalogue portraits use the production Godot ink renderer.
Run: python3 tools/render_catalog.py (or tools/render_ink_catalog.sh).
Blender is used for .blend/GLB authoring; preview lighting is defined in Godot.
"""
from pathlib import Path
import subprocess

if __name__ == "__main__":
    root = Path(__file__).resolve().parents[1]
    subprocess.run([str(root / "tools/render_ink_catalog.sh")], check=True)
