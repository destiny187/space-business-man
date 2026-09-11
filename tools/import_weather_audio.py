"""Import three authorized ElevenLabs weather cues; preserve original WAVs."""
from pathlib import Path
import array,hashlib,json,math,shutil,wave
from datetime import datetime,timezone
ROOT=Path(__file__).resolve().parents[1]
JOBS=[('amb_weather_rain', 'Steady_gentle_rain_f', True, 'Steady gentle rain falling on bare rocky ground and a few metal panels, detailed soft droplets and a smooth airy rain bed, calm alien outdoor exploration ambience. No voices, birds, music, thunder or sudden impacts. Consistent loudness, seamless loop.'), ('sfx_weather_thunder', 'A_single_natural_th', False, 'A single natural thunderclap in an open rocky valley: immediate crisp electric crack, followed by a low rolling rumble that gradually fades to silence. Restrained game sound effect with clear onset, no music, voices, rain bed or cinematic bass drop.'), ('amb_weather_acid', 'Soft_rain_droplets_l', True, 'Soft rain droplets lightly sizzling on a protective metal canopy, delicate bubbling and intermittent gentle acidic hissing. Quiet alien environmental contact loop, even restrained loudness, no voices, music, alarms, thunder or explosions. Seamless loop.')]

records=[]
for id,prefix,loop,prompt in JOBS:
 matches=list(Path.home().joinpath('Downloads').glob(prefix+'*#1*.wav'))
 assert matches,prefix
 download=max(matches,key=lambda p:p.stat().st_mtime)
 source=ROOT/'audio/source/elevenlabs'/f'{id}.wav';shutil.copy2(download,source)
 with wave.open(str(source),'rb') as w:
  rate=w.getframerate();channels=w.getnchannels();assert w.getsampwidth()==2
  raw=array.array('h',w.readframes(w.getnframes()))
 data=array.array('h',(round(sum(raw[i:i+channels])/channels) for i in range(0,len(raw),channels)))
 if loop:
  width=round(rate*.08);out=array.array('h',data[width:])
  for i in range(width):out[len(out)-width+i]=round(data[len(data)-width+i]*(1-i/(width-1))+data[i]*i/(width-1))
 else:
  audible=[i for i,v in enumerate(data) if abs(v)>104]
  assert audible
  out=data[max(0,audible[0]-round(rate*.035)):min(len(data),audible[-1]+round(rate*.12))]
  fade=round(rate*.008)
  for i in range(fade):out[i]=round(out[i]*i/fade);out[-i-1]=round(out[-i-1]*i/fade)
 if id=="sfx_incident_beacon":
  out=out[:round(rate*.65)]
  for i in range(round(rate*.015)):out[-i-1]=round(out[-i-1]*i/(rate*.015))
 rms=math.sqrt(sum(v*v for v in out)/len(out))/32768;peak=max(abs(v) for v in out)/32768
 gain=min(10**(-21/20)/max(rms,1e-9),10**(-4/20)/max(peak,1e-9));out=array.array('h',(round(v*gain) for v in out))
 target=ROOT/'우주-비즈니스/assets/audio'/f'{id}.wav'
 with wave.open(str(target),'wb') as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(rate);w.writeframes(out.tobytes())
 records.append({'id':id,'provider':'ElevenLabs Sound Effects web','prompt':prompt,'source_url':'https://elevenlabs.io/app/sound-effects/history','selected_variant':1,'duration_setting_seconds':8,'loop_setting':loop,'prompt_influence':.3,'displayed_generation_credits':108,'source':str(source.relative_to(ROOT)),'game_file':str(target.relative_to(ROOT)),'download_name':download.name,'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'duration_seconds':len(out)/rate,'format':f'PCM16 mono {rate}Hz','peak_dbfs':20*math.log10(max(abs(v) for v in out)/32768),'processing':'Stereo average to mono; '+('80ms loop crossfade' if loop else 'trim edge silence, 8ms fades')+'; -21dBFS RMS target / -4dBFS peak ceiling','status':'generated_integrated_pending_game_review','generated_at':datetime.now(timezone.utc).isoformat()})
 print(id,round(len(out)/rate,2),'s')
(ROOT/'audio/manifests/planet-weather.json').write_text(json.dumps({'date':'2026-09-11','jobs':records},ensure_ascii=False,indent=2)+'\n')
