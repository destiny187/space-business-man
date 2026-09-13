"""Crossfaded energy sustain from the preserved ElevenLabs plasma take."""
from pathlib import Path
import array, hashlib, json, math, wave
root=Path(__file__).resolve().parents[1]
src=root/'audio/source/elevenlabs/ground-combat/plasma_v1.wav'
with wave.open(str(src),'rb') as w:
 rate=w.getframerate();channels=w.getnchannels();assert w.getsampwidth()==2;raw=array.array('h',w.readframes(w.getnframes()))
mono=[sum(raw[i:i+channels])/channels for i in range(0,len(raw),channels)]
a=mono[int(rate*.20):int(rate*.60)];n=int(rate*.045)
# Crossfade the end to the beginning; loop carries no repeated shot attack.
loop=a[n:-n]+[a[-n+i]*(1-i/n)+a[i]*i/n for i in range(n)]
# Low-pass harsh upper frequencies. Warm up at the seam before retaining a loop.
alpha=1-math.exp(-2*math.pi*2400/rate);state=0.0;filtered=[]
for sample in loop*2:
 state+=alpha*(sample-state);filtered.append(state)
loop=filtered[-len(loop):];mean=sum(loop)/len(loop);loop=[v-mean for v in loop]
peak=max(abs(v) for v in loop);gain=32768*10**(-12/20)/max(1,peak);data=array.array('h',(round(v*gain) for v in loop))
target=root/'우주-비즈니스/assets/audio/sfx_gun_laser_loop.wav'
with wave.open(str(target),'wb') as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(rate);w.writeframes(data.tobytes())
record={'provider':'ElevenLabs','source':str(src.relative_to(root)),'original_manifest':'audio/manifests/ground-combat-sources.json','processing':'0.20–0.60 s energy tail, 45 ms cyclic crossfade, 2.4 kHz low pass, DC removal, -12 dBFS peak','source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'file':str(target.relative_to(root)),'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'duration':len(data)/rate,'new_generation':False,'listening_review':'미확인; 실제 게임 재생과 수치 측정은 제작 기록 참조'}
(root/'audio/manifests/firearm-laser-loop.json').write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n')
