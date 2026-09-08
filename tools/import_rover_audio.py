"""Master six ElevenLabs web SFX; preserve downloaded originals and honest QA state."""
from pathlib import Path
import json, wave, hashlib, shutil
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
JOBS=[
('drive','Seamless_steady_elec_#1-1788825586014.wav',True,'Seamless steady electric traction motor of a compact four-wheel expedition rover driving at moderate speed. Rounded low mechanical whirr, subtle tire rolling texture and gentle drivetrain harmonics. Friendly practical science fiction utility vehicle, close dry recording. Constant motion, no acceleration or braking, no start or stop, no voice, no music, no alarm, no wind. Comfortable restrained six second game loop.'),
('start','A_compact_electric_e_#1-1788825786111.wav',False,'A compact electric expedition rover powering on: one tactile relay click, a smooth short motor spin-up and a soft confident readiness tone. Practical industrial science fiction game vehicle, close and dry, clean ending. No voice, no music, no long background hum.'),
('door','A_compact_pressurize_#1-1788825853181.wav',False,'A compact pressurized exploration rover door opening and closing once: a soft seal release, a short damped electric hinge servo, then a satisfying cushioned latch click. Small practical science fiction machine. One clean dry three second sequence, no voices, no music, no alarm, no loud slam.'),
('brake','A_small_electric_ex*',False,'A small electric exploration rover braking to a clean stop on firm gravel, brief rubber grit scuff and a restrained regenerative motor deceleration whirr ending in a gentle parking brake click. Close dry two second game effect, no crash, no squealing tires, no voices, no music.'),
('winch','Seamless_steady_comp*',True,'Seamless steady compact electric vehicle loading winch and ratcheting cargo tie-down mechanism. Slow controlled geared motor with soft rhythmic pulley movement, restrained industrial science fiction equipment. Close dry six second texture, no beginning or ending, no voice, no music, no alarms, no sharp impacts.'),
('fault','A_compact_exploratio*',False,'A compact exploration rover electrical fault warning: two low gentle electronic pulses followed by a short muted mechanical relay clunk. Clear but not startling, friendly industrial science fiction equipment, one second, close dry sound. No voice, no music, no siren, no explosion.')]
records=[]
for key,pattern,loop,prompt in JOBS:
 audio_id='sfx_rover_'+key
 source=ROOT/'audio/source/elevenlabs'/f'{audio_id}.wav'
 if not source.exists():
  matches=sorted((Path.home()/'Downloads').glob(pattern),key=lambda p:p.stat().st_mtime)
  assert matches,pattern
  shutil.copyfile(matches[-1],source);filename=matches[-1].name
 else:filename=pattern
 with wave.open(str(source)) as f:
  rate=f.getframerate();channels=f.getnchannels();assert f.getsampwidth()==2
  samples=np.frombuffer(f.readframes(f.getnframes()),dtype='<i2').reshape(-1,channels).astype(float).mean(axis=1)/32768
 samples-=samples.mean();freq=np.fft.rfftfreq(len(samples),1/rate)
 samples=np.fft.irfft(np.fft.rfft(samples)*np.minimum(1,(freq/65)**2)*np.minimum(1,(8500/np.maximum(freq,1))**2),n=len(samples))
 if loop:
  n=int(.08*rate);t=np.linspace(0,1,n);samples=np.concatenate([samples[n:-n],samples[-n:]*(1-t)+samples[:n]*t])
 else:
  n=int(.012*rate);samples[:n]*=np.linspace(0,1,n);samples[-n:]*=np.linspace(1,0,n)
 samples*=min(10**((-23 if loop else -20)/20)/max(np.sqrt(np.mean(samples*samples)),1e-9),10**(-6/20)/max(abs(samples).max(),1e-9))
 out=ROOT/'우주-비즈니스/assets/audio'/f'{audio_id}.wav'
 with wave.open(str(out),'wb') as f:f.setnchannels(1);f.setsampwidth(2);f.setframerate(rate);f.writeframes((samples*32767).astype('<i2').tobytes())
 records.append({'id':audio_id,'provider':'ElevenLabs web Sound Effects','generated_at':'2026-09-08','prompt':prompt,'prompt_influence':.3,'loop':loop,'take':1,'original_filename':filename,'source':str(source.relative_to(ROOT)),'game_file':str(out.relative_to(ROOT)),'sha256':hashlib.sha256(out.read_bytes()).hexdigest(),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'sample_rate':rate,'channels':1,'duration_actual':len(samples)/rate,'status':'generated_mastered','edits':'Mono PCM16; DC removal; 65Hz/8.5kHz gentle filtering; loop 80ms crossfade or one-shot 12ms edge fades; RMS normalization; -6dBFS ceiling','qa':'Signal checked. Subjective listening unavailable; runtime check recorded in C14/C15 production document.','rms_dbfs':float(20*np.log10(np.sqrt(np.mean(samples*samples)))),'peak_dbfs':float(20*np.log10(abs(samples).max()))})
 print(audio_id,len(samples)/rate,records[-1]['peak_dbfs'])
(ROOT/'audio/manifests/rover-sounds.json').write_text(json.dumps({'version':1,'jobs':records},ensure_ascii=False,indent=2)+'\n')
