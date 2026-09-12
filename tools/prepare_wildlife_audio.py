"""Integrate the downloaded ElevenLabs native combat cues without altering originals."""
from pathlib import Path
import importlib.util
import json

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('firearm_audio', ROOT / 'tools/prepare_firearm_audio.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
module.SOURCES = ROOT / 'audio/source/elevenlabs/native-combat'
manifest = json.loads((ROOT / 'audio/manifests/native-combat-sources.json').read_text())
missing = [j['source'] for j in manifest['jobs'] if not (module.SOURCES / j['source']).exists()]
if missing:
    raise SystemExit('Missing originals: ' + str(missing))
manifest['jobs'] = [module.prepare(j) for j in manifest['jobs']]
manifest['review'] = 'Pending runtime and listening review'
(ROOT / 'audio/manifests/native-combat.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
for job in manifest['jobs']:
    print(job['id'],job['duration_seconds'],job['peak_dbfs'])
