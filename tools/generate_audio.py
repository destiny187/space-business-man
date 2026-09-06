"""Generate authorized game SFX with ElevenLabs, keeping provenance and raw audio.

Dry run: python3 tools/generate_audio.py
Generate: ELEVENLABS_API_KEY (environment) + --generate [--only AUDIO_ID]
API reference: https://elevenlabs.io/docs/api-reference/text-to-sound-effects/convert
No credentials are written to files or displayed. Existing files are preserved.
"""
from pathlib import Path
from datetime import datetime, timezone
import argparse
import hashlib
import json
import os
import shutil
import urllib.request
import urllib.error

ROOT=Path(__file__).resolve().parents[1]
MANIFEST=ROOT/"audio/manifests/elevenlabs.json"

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--generate",action="store_true")
    parser.add_argument("--only",action="append",default=[])
    args=parser.parse_args()
    data=json.loads(MANIFEST.read_text())
    jobs=[job for job in data["jobs"] if not args.only or job["id"] in args.only]
    if args.only and set(args.only)-{job["id"] for job in jobs}:
        parser.error("Unknown audio ID")
    if not args.generate:
        for job in jobs: print(job["id"],job["duration"],"seconds",job["status"])
        print("Dry run; no requests sent. Set ELEVENLABS_API_KEY in the local environment and use --generate.")
        return
    pending=[]
    for job in jobs:
        existing=[ROOT/"우주-비즈니스/assets/audio"/(job["id"]+ext) for ext in [".mp3",".wav"]]
        if any(path.exists() for path in existing): print("Preserved existing audio:",job["id"])
        else: pending.append(job)
    if not pending: return
    key=os.environ.get("ELEVENLABS_API_KEY")
    if not key:
        raise SystemExit("ELEVENLABS_API_KEY is not configured. No audio has been generated.")
    for job in pending:
        target=ROOT/"우주-비즈니스/assets/audio"/(job["id"]+".mp3")
        source=ROOT/"audio/source/elevenlabs"/(job["id"]+".mp3")
        if target.exists():
            print("Preserved existing audio:",job["id"])
            continue
        payload={"text":job["prompt"],"duration_seconds":job["duration"],"loop":job["loop"],"model_id":"eleven_text_to_sound_v2","prompt_influence":0.4}
        request=urllib.request.Request("https://api.elevenlabs.io/v1/sound-generation",data=json.dumps(payload).encode(),headers={"xi-api-key":key,"Content-Type":"application/json","Accept":"audio/mpeg"},method="POST")
        try:
            with urllib.request.urlopen(request,timeout=60) as response:
                content=response.read()
                cost=response.headers.get("character-cost")
        except urllib.error.HTTPError as error:
            raise SystemExit(f"ElevenLabs returned HTTP {error.code} for {job['id']}; stopped without retrying a billable request.")
        if len(content)<512:
            raise SystemExit(f"Unexpectedly short response for {job['id']}; no audio installed.")
        source.parent.mkdir(parents=True,exist_ok=True)
        target.parent.mkdir(parents=True,exist_ok=True)
        source.write_bytes(content)
        shutil.copyfile(source,target)
        job.update({"status":"generated_pending_listening_qa","generated_at":datetime.now(timezone.utc).isoformat(),"model":"eleven_text_to_sound_v2","sha256":hashlib.sha256(content).hexdigest(),"character_cost":cost,"source":str(source.relative_to(ROOT)),"game_file":str(target.relative_to(ROOT))})
        MANIFEST.write_text(json.dumps(data,ensure_ascii=False,indent=2)+"\n")
        print("Generated:",job["id"])

if __name__=="__main__": main()
