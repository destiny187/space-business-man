"""Preserve selected ElevenLabs WAVs and prepare conservative game mixes."""
from pathlib import Path
import wave,array,math,json,hashlib,shutil
from datetime import datetime,timezone
ROOT=Path(__file__).resolve().parents[1]
JOBS=[('amb_surface_river_v1','A_small_clear_river__#1','',True,'A small clear river flowing steadily downhill over rounded stones, textured gentle bubbling and flowing water, close natural recording, seamless four-second loop. No animals, birds, voices, music, machinery, rain or dramatic waterfall.')]
jobs=[]
for id,prefix,history,loop,prompt in JOBS:
 matches=list((Path.home()/'Downloads').glob(prefix+'*.wav'))
 if not matches:matches=list((Path.home()/'Downloads').glob(prefix.split('_#')[0]+'*#1*.wav'))
 assert matches,prefix
 download=max(matches,key=lambda p:p.stat().st_mtime);raw=ROOT/'audio/source/elevenlabs'/f'{id}.wav';shutil.copy2(download,raw)
 with wave.open(str(raw),'rb') as w:
  rate=w.getframerate();channels=w.getnchannels();assert w.getsampwidth()==2;data=array.array('h',w.readframes(w.getnframes()))
 if loop:
  width=round(rate*.08)*channels;out=array.array('h',data[width:])
  for i in range(width):
   t=(i//channels)/(width//channels-1);out[len(out)-width+i]=round(data[len(data)-width+i]*(1-t)+data[i]*t)
 else:
  out=data;fade=round(rate*.008)*channels
  for i in range(fade):out[i]=round(out[i]*i/fade);out[-i-1]=round(out[-i-1]*i/fade)
 rms=math.sqrt(sum(v*v for v in out)/len(out))/32768;peak=max(abs(v) for v in out)/32768;gain=min(10**(-21/20)/rms,10**(-4/20)/peak)
 out=array.array('h',(round(v*gain) for v in out));target=ROOT/'우주-비즈니스/assets/audio'/f'{id}.wav'
 with wave.open(str(target),'wb') as w:w.setnchannels(channels);w.setsampwidth(2);w.setframerate(rate);w.writeframes(out.tobytes())
 jobs.append({'id':id,'provider':'ElevenLabs Sound Effects web','prompt':prompt,'source_url':'https://elevenlabs.io/app/sound-effects/history'+('?id='+history if history else ''),'selected_variant':1,'duration_setting_seconds':4,'loop_setting':loop,'prompt_influence':.3,'displayed_credits':52,'download_name':download.name,'source':str(raw.relative_to(ROOT)),'game_file':str(target.relative_to(ROOT)),'source_sha256':hashlib.sha256(raw.read_bytes()).hexdigest(),'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'duration_seconds':len(out)/channels/rate,'format':f'PCM16 {channels}ch {rate}Hz','peak_dbfs':20*math.log10(max(abs(v) for v in out)/32768),'processing':'80ms loop crossfade' if loop else '8ms edge fades','normalization':'RMS -21dBFS target, -4dBFS peak ceiling','status':'generated_integrated_pending_game_review','imported_at':datetime.now(timezone.utc).isoformat()})
 print(id,'IMPORTED')
(ROOT/'audio/manifests/surface-hydrology.json').write_text(json.dumps({'date':'2026-09-09','jobs':jobs},ensure_ascii=False,indent=2)+'\n')
