"""Import explicitly generated space effects, retaining ElevenLabs originals."""
import json
from pathlib import Path
from import_web_audio import import_job, ROOT
path=ROOT/'audio/manifests/space-experience.json'
manifest=json.loads(path.read_text())
for job in manifest['jobs']:
    if job['status']=='generated_integrated': continue
    try:
        import_job(job,{})
        job['generated_at']='2026-09-07'
        job['qa']='PCM signal and duration checked; Godot playback verification pending'
    except RuntimeError as exc:
        print(exc)
manifest['status']='integrated' if all(j['status']=='generated_integrated' for j in manifest['jobs']) else 'partial'
path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')

# Align arrival loudness gradually without clipping or changing source recordings.
import array, hashlib, math, wave
for index, job in enumerate(manifest['jobs'][:5]):
    if job['status']!='generated_integrated' or job.get('loudness_balanced'):continue
    target=-23.0+index
    output=ROOT/job['game_file']
    with wave.open(str(output)) as wav:
        params=wav.getparams();samples=array.array('h',wav.readframes(wav.getnframes()))
    peak=max(abs(x) for x in samples)
    rms=math.sqrt(sum(x*x for x in samples)/len(samples))
    gain=min(26000/max(1,peak),32768*10**(target/20)/max(1,rms))
    samples=array.array('h',(round(x*gain) for x in samples))
    with wave.open(str(output),'wb') as wav:
        wav.setparams(params);wav.writeframes(samples.tobytes())
    job.update(loudness_balanced=True,target_rms_db=target,sha256=hashlib.sha256(output.read_bytes()).hexdigest())
    job['edits']+='; progressive arrival RMS targets -23 to -19 dBFS, peak capped at 26000'
path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
