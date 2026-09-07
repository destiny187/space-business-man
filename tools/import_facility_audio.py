"""Master the three authorized ElevenLabs facility loops. Original WAVs remain intact."""
from pathlib import Path
import json,hashlib,shutil,wave
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
JOBS=[
('water','Seamless_steady_loop_#1-1788789565558.wav','0MzAyiNFYtRzUJMphEuJ','Seamless steady loop of a compact science fiction water reclamation machine. Soft liquid circulation through sealed pipes, gentle pump pulses and subtle filter hiss. Dry close perspective, restrained industrial character, suitable beneath gameplay. Constant level, no start or stop, no speech, no music, no alarms, no splashes or sharp clicks.'),
('thermal','Seamless_steady_loop_#1-1788789660744.wav','Jk3zvb6NUeBVbtOhC0jS','Seamless steady loop of a compact science fiction thermal regulator. A warm low compressor hum with smooth rotating coolant fans and quiet refrigeration airflow. Rounded controlled midrange, mechanical but comfortable for long gameplay. Constant operation, no start or stop, no music, no voice, no alarms, no clicks or harsh high frequencies.'),
('biolab','Seamless_constant_lo_#1-1788789802776.wav','OOicyD9vRTxUlwK99GCf','Seamless constant loop of a small science fiction botanical bioreactor cultivating microbes. Gentle enclosed liquid bubbling and slow miniature agitator motor, delicate organic fizz under a soft clean mechanical hum. Close dry sound, quiet and reassuring, modest stable energy for a building in a game. No speech, no music, no alarms, no heartbeats, no start or stop.')]
manifest=ROOT/'audio/manifests/elevenlabs.json';data=json.loads(manifest.read_text())
for kind,filename,history,prompt in JOBS:
    audio_id='sfx_'+kind+'_loop';src=ROOT/'audio/source/elevenlabs'/f'{audio_id}.wav'
    if not src.exists():shutil.copyfile(Path.home()/'Downloads'/filename,src)
    with wave.open(str(src),'rb') as f:
        rate=f.getframerate();channels=f.getnchannels();assert f.getsampwidth()==2
        samples=np.frombuffer(f.readframes(f.getnframes()),dtype='<i2').reshape(-1,channels).astype(float)/32768
    samples=samples.mean(axis=1);samples-=samples.mean()
    # Remove inaudible rumble and soften upper machine hiss; loop crossfade preserves continuity.
    spectrum=np.fft.rfft(samples);freq=np.fft.rfftfreq(len(samples),1/rate)
    spectrum*=np.minimum(1,(freq/70)**2)*np.minimum(1,(8000/np.maximum(freq,1))**2)
    samples=np.fft.irfft(spectrum,n=len(samples))
    n=int(.08*rate);w=np.linspace(0,1,n)
    samples=np.concatenate([samples[n:-n],samples[-n:]*(1-w)+samples[:n]*w])
    rms=float(np.sqrt(np.mean(samples*samples)));peak=float(np.abs(samples).max())
    samples*=min(10**(-23/20)/max(rms,1e-8),10**(-9/20)/max(peak,1e-8))
    target=ROOT/'우주-비즈니스/assets/audio'/f'{audio_id}.wav'
    with wave.open(str(target),'wb') as f:f.setnchannels(1);f.setsampwidth(2);f.setframerate(rate);f.writeframes((samples*32767).astype('<i2').tobytes())
    info={'id':audio_id,'provider':'ElevenLabs web Sound Effects','status':'generated_integrated','prompt':prompt,'duration':6,'duration_actual':len(samples)/rate,'loop':True,'take':1,'generated_at':'2026-09-07','history':'https://elevenlabs.io/app/sound-effects/history?id='+history,'prompt_influence':.3,'character_cost':80,'original_filename':filename,'source':str(src.relative_to(ROOT)),'game_file':str(target.relative_to(ROOT)),'sample_rate':rate,'channels':1,'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'edits':'Mono PCM16; DC removal; gentle 70Hz/8kHz filtering; 80ms loop crossfade; RMS -23dBFS with -9dBFS peak ceiling','qa':'Runtime playback and signal checked; subjective listening unavailable. See docs/production/46-ground-play-repairs.md','signal':{'rms_dbfs':round(20*np.log10(np.sqrt(np.mean(samples*samples))),2),'peak_dbfs':round(20*np.log10(np.abs(samples).max()),2),'seam_step':round(float(abs(samples[-1]-samples[0])),6)}}
    data['jobs']=[x for x in data['jobs'] if x['id']!=audio_id]+[info]
    print(audio_id,info['signal'])
manifest.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
