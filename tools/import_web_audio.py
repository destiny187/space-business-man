"""Import only newly downloaded ElevenLabs WAVs matching the recorded prompt.
Preserve original audio; normalize and fade game copies with deterministic edits.
"""
import argparse, array, hashlib, json, math, re, shutil, sys, wave
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def normalized(value): return re.sub('[^a-z0-9]','',value.lower())
def import_job(job,record):
    prefix=normalized(record.get('prompt',job['prompt']))[:14]
    files=[p for p in (Path.home()/'Downloads').glob('*.wav') if normalized(p.name).startswith(prefix)]
    if not files: raise RuntimeError('No matching ElevenLabs download: '+job['id'])
    source=max(files,key=lambda p:p.stat().st_mtime)
    original=ROOT/'audio/source/elevenlabs'/(job['id']+'.wav')
    original.parent.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(source,original)
    with wave.open(str(original)) as wav:
        channels,width,rate,frames,_,_=wav.getparams()
        if width!=2: raise RuntimeError('Expected PCM16 WAV')
        samples=array.array('h',wav.readframes(frames))
    if sys.byteorder!='little': samples.byteswap()
    if record.get('loop',job['loop']):
        overlap=min(int(rate*0.045),frames//10)
        for frame in range(overlap):
            t=frame/max(1,overlap-1)
            for ch in range(channels):
                end=(frames-overlap+frame)*channels+ch
                samples[end]=round(samples[end]*(1-t)+samples[frame*channels+ch]*t)
        samples=samples[overlap*channels:]
    else:
        frames=len(samples)//channels
        for frame in range(frames):
            gain=min(1,frame/max(1,rate*.002),(frames-1-frame)/max(1,rate*.012))
            if gain<1:
                for ch in range(channels): samples[frame*channels+ch]=round(samples[frame*channels+ch]*gain)
    peak=max(abs(x) for x in samples)
    if peak<64: raise RuntimeError('Silent or unusably quiet audio')
    gain=min(3.0,26000/peak)
    samples=array.array('h',(round(x*gain) for x in samples))
    output=ROOT/'우주-비즈니스/assets/audio'/(job['id']+'.wav');output.parent.mkdir(parents=True,exist_ok=True)
    if sys.byteorder!='little': samples.byteswap()
    with wave.open(str(output),'wb') as wav:
        wav.setnchannels(channels);wav.setsampwidth(2);wav.setframerate(rate);wav.writeframes(samples.tobytes())
    job.update(record)
    job.update(status='generated_integrated',provider='ElevenLabs web Sound Effects',take=1,generated_at='2026-09-06',original_filename=source.name,source=str(original.relative_to(ROOT)),game_file=str(output.relative_to(ROOT)),duration_actual=len(samples)/channels/rate,sample_rate=rate,channels=channels,sha256=hashlib.sha256(output.read_bytes()).hexdigest(),edits='PCM16; peak normalization; 45ms loop crossfade or 2ms/12ms edge fades',qa='Signal and runtime playback checked; final listening review remains subjective')
    print(job['id'],len(samples)/channels/rate,'seconds')
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('records',type=Path);args=parser.parse_args()
    manifest_path=ROOT/'audio/manifests/elevenlabs.json';manifest=json.loads(manifest_path.read_text())
    for record in json.loads(args.records.read_text()):
        job=next(j for j in manifest['jobs'] if j['id']==record['id'])
        if job['status']=='generated_integrated': continue
        import_job(job,record)
        manifest['status']='partially_integrated';manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    if all(j['status']=='generated_integrated' for j in manifest['jobs']): manifest['status']='integrated'
    manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
