"""Compatibility entry point for the current INK mesa authoring pipeline."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_ink_followups import build

if __name__ == '__main__':
    requested = sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    requested = requested or ['mesa_0', 'mesa_1', 'mesa_2']
    if set(requested) - {'mesa_0', 'mesa_1', 'mesa_2'}:
        raise SystemExit('Expected mesa_0, mesa_1 or mesa_2')
    for asset in requested:
        build(asset)
