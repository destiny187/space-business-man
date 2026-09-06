"""Verify the shipped ZIP in a fresh directory, outside the Godot source tree."""
from pathlib import Path
from datetime import datetime, timezone
import hashlib
import json
import plistlib
import re
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
RESULTS = ROOT / "test-results"
archive = ROOT / "builds/macos/Locus-Space-Business.zip"
destination = Path(tempfile.mkdtemp(prefix="locus-release-"))
subprocess.run(["/usr/bin/ditto","-xk",str(archive),str(destination)],check=True)
app = destination / "Locus.app"
info = plistlib.loads((app/"Contents/Info.plist").read_bytes())
expected = re.search(r'application/short_version="([^"]+)"',
                     (ROOT/"우주-비즈니스/export_presets.cfg").read_text()).group(1)
if info["CFBundleShortVersionString"] != expected:
    raise SystemExit("The ZIP version does not match the export preset")
subprocess.run(["/usr/bin/codesign","--verify","--deep","--strict",str(app)],check=True)
capture = RESULTS/"screenshots/release.png"
capture.parent.mkdir(parents=True,exist_ok=True)
if capture.exists(): capture.unlink()
started = time.monotonic()
command = [str(app/"Contents/MacOS/Locus"),"--","--smoke","--capture="+str(capture)]
result = subprocess.run(command,cwd=destination,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,
                        text=True,timeout=180)
elapsed = time.monotonic()-started
(RESULTS/"release-run.log").write_text(result.stdout)
errors = [line for line in result.stdout.splitlines() if "ERROR:" in line]
report = {
    "version":info["CFBundleShortVersionString"],
    "archive_sha256":hashlib.sha256(archive.read_bytes()).hexdigest(),
    "archive_bytes":archive.stat().st_size,"extracted_path":str(app),
    "signature_verified":True,"independent_run_exit":result.returncode,
    "error_lines":len(errors),"smoke_elapsed_seconds":round(elapsed,2),
    "capture":str(capture.relative_to(ROOT)),"verified_at":datetime.now(timezone.utc).isoformat(),
}
(RESULTS/"release.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n")
print(json.dumps(report,ensure_ascii=False,indent=2),flush=True)
if result.returncode != 0 or errors or "SMOKE_CAPTURE" not in result.stdout or not capture.exists():
    raise SystemExit("Exported app verification failed; inspect test-results/release-run.log")
