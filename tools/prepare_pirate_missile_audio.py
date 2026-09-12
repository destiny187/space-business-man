"""Short ship missile cues edited from the recorded ElevenLabs originals."""
from pathlib import Path
import numpy as np, wave, json, hashlib
root=Path(__file__).resolve().parents[1];jobs=[]
for cue,source,start,duration in [('sfx_ship_missile_launch','sfx_vessel_boost',.1,.48),('sfx_ship_missile_blast','sfx_gun_plasma',0,.6)]:
 path=root/'우주-비즈니스/assets/audio'/f'{source}.wav'
 with wave.open(str(path)) as f:
  rate=f.getframerate();x=np.frombuffer(f.readframes(f.getnframes()),dtype='<i2').reshape(-1,f.getnchannels()).mean(axis=1)/32768
 x=x[int(start*rate):int((start+duration)*rate)].copy();n=len(x)
 attack=min(int(.003*rate),n//2);tail=min(int(.05*rate),n//2)
 x[:attack]*=np.linspace(0,1,attack);x[-tail:]*=np.linspace(1,0,tail);x*=.56/max(.001,np.max(np.abs(x)))
 output=root/'우주-비즈니스/assets/audio'/f'{cue}.wav'
 with wave.open(str(output),'wb') as f:f.setnchannels(1);f.setsampwidth(2);f.setframerate(rate);f.writeframes((x*32767).astype('<i2').tobytes())
 jobs.append({'id':cue,'source':str(path.relative_to(root)),'source_manifest':'audio/manifests/space-experience.json' if source=='sfx_vessel_boost' else 'audio/manifests/ground-combat.json','source_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'start':start,'duration':n/rate,'processing':'ElevenLabs existing source, mono trim, 3ms/50ms edge fades, peak .56; no new synthesis','game_file':str(output.relative_to(root)),'sha256':hashlib.sha256(output.read_bytes()).hexdigest()})
(root/'audio/manifests/pirate-missiles-reuse.json').write_text(json.dumps({'date':'2026-09-12','provider':'ElevenLabs original recordings reused','jobs':jobs},ensure_ascii=False,indent=2)+'\n')
