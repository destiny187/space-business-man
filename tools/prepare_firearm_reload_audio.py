"""Retimed mechanical cues from the preserved ElevenLabs reload take; no new synthesis."""
from pathlib import Path
import array, hashlib, json, math, wave
root=Path(__file__).resolve().parents[1]
src=root/'audio/source/elevenlabs/ground-combat/reload_v1.wav'
with wave.open(str(src),'rb') as w:
 rate=w.getframerate();channels=w.getnchannels();assert w.getsampwidth()==2
 raw=array.array('h',w.readframes(w.getnframes()))
mono=[sum(raw[i:i+channels])/channels for i in range(0,len(raw),channels)]
records=[]
for name,start,stop in [('sfx_gun_mag_out',.03,.37),('sfx_gun_mag_in',.68,1.05),('sfx_gun_charge',1.28,1.68)]:
 samples=mono[int(start*rate):int(stop*rate)]
 for i in range(len(samples)):samples[i]*=min(1,i/(rate*.003),(len(samples)-1-i)/(rate*.025))
 peak=max(abs(v) for v in samples);gain=32768*10**(-8/20)/max(1,peak)
 data=array.array('h',(round(v*gain) for v in samples));target=root/'우주-비즈니스/assets/audio'/f'{name}.wav'
 with wave.open(str(target),'wb') as w:
  w.setnchannels(1);w.setsampwidth(2);w.setframerate(rate);w.writeframes(data.tobytes())
 records.append(dict(id=name,source=str(src.relative_to(root)),source_sha256=hashlib.sha256(src.read_bytes()).hexdigest(),trim=[start,stop],game_file=str(target.relative_to(root)),sha256=hashlib.sha256(target.read_bytes()).hexdigest(),duration=len(data)/rate,peak_dbfs=20*math.log10(max(abs(v) for v in data)/32768)))
(root/'audio/manifests/firearm-reload-stages.json').write_text(json.dumps({'provider':'ElevenLabs','original_manifest':'audio/manifests/ground-combat-sources.json','processing':'Mono, stage slices, 3ms/25ms fades, -8dBFS peak','status':'pending_runtime_review','cues':records},ensure_ascii=False,indent=2)+'\n')
