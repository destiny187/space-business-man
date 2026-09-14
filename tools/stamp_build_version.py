"""Embed the source identity in exports; never modify commits during a push."""
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def git(*args):
    return subprocess.check_output(["git", "--no-optional-locks", "-C", str(ROOT), *args], text=True).strip()


def main():
    version = git("log", "-1", "--format=%cs+%h", "--abbrev=9").replace("-", ".")
    dirty = bool(git("status", "--porcelain", "--untracked-files=normal"))
    if dirty:
        version += " (개발 중)"
    data = {"version": version, "commit": git("rev-parse", "HEAD"), "dirty": dirty}
    target = ROOT / "우주-비즈니스/data/build_version.json"
    target.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("Build version: " + version)


if __name__ == "__main__":
    main()
