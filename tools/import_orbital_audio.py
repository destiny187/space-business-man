"""Import selected ElevenLabs generations, retaining originals and loop edits."""
from pathlib import Path
from datetime import datetime, timezone
import array, math, wave, json, hashlib, shutil
ROOT=Path(__file__).resolve().parents[1]
MANIFEST=ROOT/'audio/manifests/space-polish.json'
JOBS=[
 ('sfx_vessel_reactor_v2','Steady_deep_reactor__#1-1788913550898.wav','Steady deep reactor and hull resonance inside a large exploration spacecraft. Warm restrained low mechanical rumble, subtle electrical harmonics, soft industrial vibration, even continuous texture for seamless game engine layering. Eight seconds. No wind, no music, no melody, no voices, no alarms, no impacts, no fade in or out.','https://elevenlabs.io/app/sound-effects/history?id=DsLjmVeOHtpK82WnidJP'),
 ('sfx_finch_turbine_v2','Steady_agile_electri_#1','Steady agile electric ion turbine of a small exploration shuttle. Smooth precise midrange motor whine, fine mechanical harmonics, light compact machine, a hint of pulsing power, continuous even eight-second loop for game propulsion layering. No bass booms, no wind, no music, no voices, no alarms, no start or stop.','https://elevenlabs.io/app/sound-effects/history?id=7H5BbicZ7NE81zKQAfrw'),
 ('sfx_vessel_exhaust_v2','Continuous_high-outp_#1','Continuous high-output spacecraft plasma exhaust, controlled powerful broad rushing propulsion texture with a smooth electric edge and restrained low end. Stable eight-second loop, designed as the bright layer over a separate engine bass. Clean science fiction machinery. No music, voices, alarms, explosions, start or stop, no fade.','https://elevenlabs.io/app/sound-effects/history?id=CJhNmSwzU4NwoNi35wyR')]
data=json.loads(MANIFEST.read_text()) if MANIFEST.exists() else {'version':1,'date':'2026-09-09','provider':'ElevenLabs','jobs':[]}
for id,prefix,prompt,url in JOBS:
 if any(j['id']==id for j in data['jobs']):continue
 matches=list((Path.home()/'Downloads').glob(prefix+'*'))
 if not matches:print('PENDING',id,prefix);continue
 source_download=max(matches,key=lambda p:p.stat().st_mtime)
 raw=ROOT/'audio/source/elevenlabs'/f'{id}.wav';raw.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source_download,raw)
 with wave.open(str(raw),'rb') as w:
  rate=w.getframerate();channels=w.getnchannels();assert w.getsampwidth()==2;pcm=array.array('h',w.readframes(w.getnframes()))
 width=round(rate*.12)*channels
 # End-to-start crossfade removes the duplicated head; zero crossing remains continuous.
 result=array.array('h',pcm[width:])
 for i in range(width):
  t=(i//channels)/(width//channels-1)
  result[len(result)-width+i]=round(pcm[len(pcm)-width+i]*(1-t)+pcm[i]*t)
 rms=math.sqrt(sum(v*v for v in result)/len(result))/32768
 peak=max(abs(v) for v in result)/32768
 gain=min(10**(-21/20)/max(rms,1e-9),10**(-3/20)/max(peak,1e-9))
 result=array.array('h',(round(v*gain) for v in result))
 target=ROOT/'우주-비즈니스/assets/audio'/f'{id}.wav'
 with wave.open(str(target),'wb') as w:w.setnchannels(channels);w.setsampwidth(2);w.setframerate(rate);w.writeframes(result.tobytes())
 data['jobs'].append({'id':id,'status':'generated_integrated_pending_game_playback','provider':'ElevenLabs Sound Effects web','prompt':prompt,'project_url':url,'duration_setting_seconds':8,'loop_setting':True,'selected_variant':1,'displayed_credits':108,'download_name':source_download.name,'source':str(raw.relative_to(ROOT)),'game_file':str(target.relative_to(ROOT)),'source_sha256':hashlib.sha256(raw.read_bytes()).hexdigest(),'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'measured_duration_seconds':len(result)/channels/rate,'format':f'PCM16 {channels}ch {rate}Hz','processing':'120ms linear loop crossfade; RMS -21dBFS target with -3dBFS peak ceiling','imported_at':datetime.now(timezone.utc).isoformat()})
 print('IMPORTED',id,len(result)/channels/rate)
MANIFEST.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
