"""Serialize finite Godot art captures to avoid simultaneous Metal cache pressure."""
from pathlib import Path
from contextlib import contextmanager
import fcntl, subprocess, sys

@contextmanager
def renderer_slot():
    folder = Path(__file__).resolve().parents[2] / 'output/creature-remodel/production'
    folder.mkdir(parents=True, exist_ok=True)
    with (folder / 'renderer.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            yield
        finally:
            fcntl.flock(lock, fcntl.LOCK_UN)

if __name__ == '__main__':
    assert len(sys.argv) > 1
    with renderer_slot():
        raise SystemExit(subprocess.run(sys.argv[1:]).returncode)
