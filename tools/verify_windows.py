"""Verify Windows ZIP/PE/PCK integrity; optionally render its PCK with a host Godot."""
from pathlib import Path
from datetime import datetime, timezone
import argparse
import fnmatch
import hashlib
import json
import platform
import re
import struct
import subprocess
import tempfile
import time
import zipfile

ROOT = Path(__file__).resolve().parents[1]

def file_sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()

RESULTS = ROOT / "test-results"
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--godot", type=Path, help="Optional host Godot 4.7.2 executable for an independent PCK render")
args = parser.parse_args()
preset_text = (ROOT / "우주-비즈니스/export_presets.cfg").read_text()
preset = preset_text.split("[preset.1.options]", 1)[1]
export_settings = preset_text.split("[preset.1]", 1)[1].split("[preset.1.options]", 1)[0]
excluded = re.search(r'exclude_filter="([^"]*)"', export_settings).group(1).split(",")
version = re.search(r'application/product_version="([^"]+)"', preset).group(1).rsplit(".", 1)[0]
name = f"Locus-{version}-Windows-x64"
archive = ROOT / "builds/windows" / (name + ".zip")
destination = Path(tempfile.mkdtemp(prefix="locus-windows-release-"))
with zipfile.ZipFile(archive) as package:
    assert all(p.startswith(name + "/") and ".." not in Path(p).parts for p in package.namelist())
    # Extraction reads every member to EOF and verifies its CRC, without a
    # second full decompression pass for large resource packs.
    package.extractall(destination)
release = destination / name
info = json.loads((release / "build-info.json").read_text())
assert info["version"] == version and info["target"] == "Windows x86_64"
for filename, expected in info["files"].items():
    path = release / filename
    assert path.stat().st_size == expected["bytes"], filename
    assert file_sha256(path) == expected["sha256"], filename
for filename, subsystem in (("Locus.exe", 2), ("Locus.console.exe", 3)):
    data = (release / filename).read_bytes()
    assert data[:2] == b"MZ", filename
    pe = struct.unpack_from("<I", data, 0x3C)[0]
    assert data[pe:pe+4] == b"PE\0\0", filename
    assert struct.unpack_from("<H", data, pe+4)[0] == 0x8664, "Wrong CPU architecture"
    assert struct.unpack_from("<H", data, pe+24)[0] == 0x20B, "Expected PE32+"
    assert struct.unpack_from("<H", data, pe+24+68)[0] == subsystem, "Wrong Windows subsystem"
    assert "우주 비즈니스맨".encode("utf-16-le") in data, "Product branding missing"
    assert (version + ".0").encode("utf-16-le") in data, "Product version missing"

# Godot's unencrypted PCK v3/v4 directory layout (core/io/file_access_pack.cpp).
packed_path = release / "Locus.pck"
packed_size = packed_path.stat().st_size
stream = packed_path.open("rb")
resources = packed_path.open("rb")
def unpack(fmt):
    return struct.unpack(fmt, stream.read(struct.calcsize(fmt)))
magic, pack_version, major, minor, patch, flags, base, directory = unpack("<4sIIIIIQQ")
assert magic == b"GDPC" and pack_version in (3, 4) and (major, minor, patch) == (4, 7, 2)
assert flags & ~2 == 0, "Expected a normal unencrypted resource pack"
stream.seek(directory)
count, = unpack("<I")
paths = set()
for _ in range(count):
    length, = unpack("<I")
    path = stream.read(length).rstrip(b"\0").decode("utf-8").removeprefix("res://")
    offset, size, md5, file_flags = unpack("<QQ16sI")
    assert file_flags == 0 and base + offset + size <= packed_size, path
    resources.seek(base + offset)
    digest = hashlib.md5()
    remaining = size
    while remaining:
        block = resources.read(min(remaining, 1024 * 1024))
        assert block, path
        digest.update(block)
        remaining -= len(block)
    assert digest.digest() == md5, path
    assert path not in paths, path
    paths.add(path)
stream.close()
resources.close()
assert not any(p.startswith("tests/") for p in paths), "Tests should be excluded"
for filename in ("project.binary", "data/catalog.json", "data/graphics.json",
                 "assets/fonts/OFL.txt", "assets/legal/Godot-LICENSE.txt"):
    assert filename in paths, filename
project = ROOT / "우주-비즈니스"
expected_models = {str(source.relative_to(project)) + ".import"
                   for source in (project / "assets/models").rglob("*.glb")}
expected_audio = {str(source.relative_to(project)) + ".import"
                  for source in (project / "assets/audio").rglob("*")
                  if source.suffix in (".wav", ".mp3")}
expected_data = {str(source.relative_to(project))
                 for source in (project / "data").rglob("*.json")
                 if not any(fnmatch.fnmatchcase(source.relative_to(project).as_posix(), pattern)
                            for pattern in excluded)}
for expected in expected_models | expected_audio | expected_data:
    assert expected in paths, "Missing current source resource: " + expected
models = len([p for p in paths if p.startswith("assets/models/") and p.endswith(".glb.import")])
audio = len([p for p in paths if p.startswith("assets/audio/") and p.endswith((".wav.import", ".mp3.import"))])
assert models == len(expected_models) and audio == len(expected_audio), (models, audio)
report = {"version": version, "archive_sha256": file_sha256(archive),
          "archive_bytes": archive.stat().st_size, "zip_crc_verified": True,
          "file_hashes_verified": len(info["files"]), "pe_x86_64_verified": True,
          "pck_resource_hashes_verified": count, "models": models, "audio": audio,
          "native_windows_tested": False, "extracted_path": str(release)}
if args.godot:
    capture = RESULTS / "screenshots/windows-pack-on-host.png"
    capture.parent.mkdir(parents=True, exist_ok=True)
    capture.unlink(missing_ok=True)
    started = time.monotonic()
    result = subprocess.run([str(args.godot.resolve()), "--path", str(release),
        "--main-pack", str(release / "Locus.pck"), "--", "--smoke", "--capture=" + str(capture)],
        cwd=release, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=180)
    (RESULTS / "windows-pack-on-host.log").write_text(result.stdout)
    errors = [line for line in result.stdout.splitlines() if "ERROR:" in line]
    report["host_resource_run"] = {"os": platform.system(), "exit_code": result.returncode,
        "error_lines": len(errors), "elapsed_seconds": round(time.monotonic()-started, 2),
        "capture": str(capture.relative_to(ROOT))}
    assert result.returncode == 0 and not errors and capture.exists() and "SMOKE_CAPTURE" in result.stdout, result.stdout
report["verified_at"] = datetime.now(timezone.utc).isoformat()
RESULTS.mkdir(exist_ok=True)
(RESULTS / "windows-release.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
print(json.dumps(report, ensure_ascii=False, indent=2), flush=True)
