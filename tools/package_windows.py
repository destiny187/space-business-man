"""Package a Windows export with relative launchers, notices, and file hashes."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import re
import shutil
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
stage = Path(sys.argv[1]).resolve()
preset = (ROOT / "우주-비즈니스/export_presets.cfg").read_text().split("[preset.1.options]", 1)[1]
version = re.search(r'application/product_version="([^"]+)"', preset).group(1).rsplit(".", 1)[0]
name = f"Locus-{version}-Windows-x64"
output = ROOT / "builds/windows"
for filename in ("Locus.exe", "Locus.console.exe", "Locus.pck"):
    if not (stage / filename).is_file() or (stage / filename).stat().st_size == 0:
        raise SystemExit(f"Missing export: {filename}")
for filename in ("windows-import.log", "windows-export.log"):
    log = (ROOT / "test-results" / filename).read_text()
    if "ERROR:" in log:
        raise SystemExit(f"Godot reported errors; inspect test-results/{filename}")

def windows_text(path, content, encoding="ascii"):
    path.write_bytes(content.replace("\r\n", "\n").replace("\n", "\r\n").encode(encoding))

windows_text(stage / "README.txt", (ROOT / "docs/release/windows-README.txt").read_text().replace("{version}", version), "utf-8-sig")
windows_text(stage / "Start-Vulkan.cmd", '''@echo off
cd /d "%~dp0"
start "" "%~dp0Locus.exe" --rendering-driver vulkan --rendering-method forward_plus
''')
windows_text(stage / "Start-Diagnostics.cmd", r'''@echo off
cd /d "%~dp0"
echo Starting Locus with diagnostic logging. Close the game to finish.
"%~dp0Locus.console.exe" --verbose --log-file "%TEMP%\Locus-Windows-test.log"
echo.
echo Log file: %TEMP%\Locus-Windows-test.log
echo No file is sent automatically. Share this log if you need help.
pause
''')
licenses = stage / "licenses"
licenses.mkdir(exist_ok=True)
for source in (ROOT / "우주-비즈니스/assets/legal").glob("*.txt"):
    shutil.copy2(source, licenses / source.name)
shutil.copy2(ROOT / "우주-비즈니스/assets/fonts/OFL.txt", licenses / "NotoSansKR-OFL.txt")
files = {str(p.relative_to(stage)).replace("\\", "/"): {
    "bytes": p.stat().st_size, "sha256": hashlib.sha256(p.read_bytes()).hexdigest()
} for p in sorted(stage.rglob("*")) if p.is_file() and p.name != "build-info.json"}
info = {"product": "우주 비즈니스맨", "version": version, "engine": "Godot 4.7.2",
        "target": "Windows x86_64", "renderer": "Forward+ / Direct3D 12 (Vulkan launcher included)",
        "built_at": datetime.now(timezone.utc).isoformat(), "native_windows_tested": False, "files": files}
(stage / "build-info.json").write_text(json.dumps(info, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
archive = output / (name + ".zip")
temporary = archive.with_suffix(".zip.tmp")
with zipfile.ZipFile(temporary, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as package:
    for path in sorted(stage.rglob("*")):
        if path.is_file():
            package.write(path, str(Path(name) / path.relative_to(stage)))
temporary.replace(archive)
(output / "SHA256SUMS.txt").write_text(hashlib.sha256(archive.read_bytes()).hexdigest() + "  " + archive.name + "\n")
print(f"Packaged: {archive} ({archive.stat().st_size:,} bytes)", flush=True)
