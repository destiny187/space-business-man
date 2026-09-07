"""Edit the selected ElevenLabs foley take into short movement events."""
from pathlib import Path
import array, hashlib, json, math, shutil, wave
ROOT=Path(__file__).resolve().parents[1]
source=ROOT/'audio/source/elevenlabs/suit_foley_v1.wav'
source.parent.mkdir(parents=True,exist_ok=True)
if not source.exists():shutil.copyfile(Path.home()/'Downloads/Dry_close-up_science_#1-1788759297049.wav',source)
with wave.open(str(source)) as w:
 rate=w.getframerate();channels=w.getnchannels();raw=array.array('h',w.readframes(w.getnframes()))
mono=[round(sum(raw[i:i+channels])/channels) for i in range(0,len(raw),channels)]
jobs=[]
for name,start,end in [('sfx_suit_jump',.05,.47),('sfx_suit_land',5.0,5.58),('sfx_suit_step',2.0,2.28)]:
 samples=mono[round(start*rate):round(end*rate)];rms=math.sqrt(sum(v*v for v in samples)/len(samples));gain=min(24000/max(1,max(abs(v) for v in samples)),32768*10**(-20/20)/max(1,rms))
 fade=int(rate*.01);samples=array.array('h',(round(v*gain*min(1,i/fade,(len(samples)-1-i)/fade)) for i,v in enumerate(samples)))
 output=ROOT/'우주-비즈니스/assets/audio'/f'{name}.wav'
 with wave.open(str(output),'wb') as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(rate);w.writeframes(samples.tobytes())
 jobs.append({'id':name,'source':str(source.relative_to(ROOT)),'source_range_seconds':[start,end],'game_file':str(output.relative_to(ROOT)),'sha256':hashlib.sha256(output.read_bytes()).hexdigest(),'duration':len(samples)/rate,'peak':max(abs(v) for v in samples),'qa':'Godot playback pending'})
manifest={'date':'2026-09-07','service':'ElevenLabs web Sound Effects','selection':'generation variant 1 of 4','duration_seconds':6,'prompt_influence':.30,'loop':False,'prompt':'Dry close-up science fiction spacesuit foley: one short boot push-off with fabric rustle at the start, silence, one heavy two-boot landing with knee servo compression in the middle, silence, then two separate walking boot steps on rough stone. Six seconds total, distinct isolated events for game editing. Restrained mechanical detail, no voices, no music, no background ambience, no reverb.','source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'edits':'Selected isolated transients from generated foley; mono 48kHz PCM16, 10ms fades, RMS -20dBFS with peak limit 24000. Generation timing did not follow the requested sequence exactly.','jobs':jobs}
(ROOT/'audio/manifests/crew-locomotion.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(jobs,indent=2))
