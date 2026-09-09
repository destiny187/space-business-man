"""Import four authorized ElevenLabs web generations; keep raw WAV and mono game mix."""
from pathlib import Path
import array,hashlib,json,math,shutil,wave
from datetime import datetime,timezone
ROOT=Path(__file__).resolve().parents[1]
JOBS=[
('sfx_lotus_carrier','A_compact_unmanned_c_',True,'A compact unmanned cargo VTOL spacecraft hovering steadily overhead. Four ducted electric lift turbines with a warm low mechanical hum, controlled airy thrust and subtle servo texture. Stable continuous sound suitable for a seamless loop in a stylized science fiction game. No speech, music, beeps, explosions or background ambience.'),
('sfx_lotus_touchdown','A_heavy_industrial_s_',False,'A heavy industrial supply crate touches down on firm rocky soil with one cushioned low thump, a short rattle of cargo restraints and a pneumatic pressure release. One clear landing impact at the beginning with a short decay into silence. Close dry science fiction game foley. No explosion, voices, music or engine.'),
('ui_lotus_dispatch','A_futuristic_field_',False,'A futuristic field radio sends a supply request: a soft tactile switch click, two short clear electronic handshake pulses and a warm rising confirmation chirp. One restrained positive communication cue near the start, fading quickly into silence. Dry isolated game interface sound. No speech, music, alarm, static hiss or background ambience.'),
('sfx_lotus_open','An_industrial_suppl',False,'An industrial supply crate opens: two metal safety latches click free, a short pneumatic seal hiss, and a sturdy hinged lid lifts with a soft mechanical servo. One brief close dry sequence at the start, ending in silence. Satisfying utilitarian science fiction game foley. No voice, music, engine, alarms or ambient noise.')]
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
 rms=math.sqrt(sum(v*v for v in out)/len(out))/32768;peak=max(abs(v) for v in out)/32768
 gain=min(10**(-21/20)/max(rms,1e-9),10**(-4/20)/max(peak,1e-9));out=array.array('h',(round(v*gain) for v in out))
 target=ROOT/'우주-비즈니스/assets/audio'/f'{id}.wav'
 with wave.open(str(target),'wb') as w:w.setnchannels(1);w.setsampwidth(2);w.setframerate(rate);w.writeframes(out.tobytes())
 records.append({'id':id,'provider':'ElevenLabs Sound Effects web','prompt':prompt,'source_url':'https://elevenlabs.io/app/sound-effects/history','selected_variant':1,'duration_setting_seconds':4,'loop_setting':loop,'prompt_influence':.3,'displayed_generation_credits':52,'source':str(source.relative_to(ROOT)),'game_file':str(target.relative_to(ROOT)),'download_name':download.name,'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'duration_seconds':len(out)/rate,'format':f'PCM16 mono {rate}Hz','peak_dbfs':20*math.log10(max(abs(v) for v in out)/32768),'processing':'Stereo average to mono; '+('80ms loop crossfade' if loop else 'trim edge silence, 8ms fades')+'; -21dBFS RMS target / -4dBFS peak ceiling','status':'generated_integrated_pending_game_review','generated_at':datetime.now(timezone.utc).isoformat()})
 print(id,round(len(out)/rate,2),'s')
(ROOT/'audio/manifests/lotus-support.json').write_text(json.dumps({'date':'2026-09-09','jobs':records},ensure_ascii=False,indent=2)+'\n')
