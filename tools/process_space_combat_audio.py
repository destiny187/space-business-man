from pathlib import Path
import json,hashlib
import numpy as np
from scipy.io import wavfile
from scipy.signal import butter,sosfilt
root=Path.cwd();src=root/'audio/source/elevenlabs/space-combat-20260913';dst=root/'우주-비즈니스/assets/audio'
prompts={
'missile-launch':'A single spacecraft missile launching from a heavy mechanical rack, immediate tight metal release clack and deep compressed ignition thump, followed by a powerful short gritty rocket exhaust rushing away. Punchy modern science fiction combat game sound, dry close perspective, detailed and restrained, under one second with a short natural decay. No electronic chirps, whistles, cartoon boing, laser, music, voices, alarm, or long cinematic rumble.',
'missile-blast':'One guided missile striking a spacecraft hull. Immediate hard sharp impact crack, compact deep explosive punch, layered tearing metal fragments and a short gritty debris tail. Modern high quality sci-fi combat sound, powerful but controlled, dry isolated event, all energy starts immediately, decays within 1.5 seconds. No laser tones, squeaks, cartoon boing, rising whistle, music, voices or long rumbling drone.',
'hull-collision':'Two heavy armored spacecraft hulls collide once. A sudden weighty metal crunch and low resonant chassis thud, short scraping steel and rattling fragments trailing for one second. Dry close detailed game foley, forceful mechanical contact, not an explosion, no fire, no gunshots, no laser or cartoon tones, no music, no voices.'}
jobs=[]
for stem,cue,duration,peak in [('missile-launch','sfx_ship_missile_launch_v2',1.65,.58),('missile-blast','sfx_ship_missile_blast_v2',1.25,.7),('hull-collision','sfx_ship_hull_collision',1.1,.65)]:
 source=src/(stem+'-take1.wav');rate,samples=wavfile.read(source);x=samples.astype(np.float64).mean(axis=1)/32768
 x=sosfilt(butter(2,35,fs=rate,btype='highpass',output='sos'),x)[:round(duration*rate)]
 x[:round(.002*rate)]*=np.linspace(0,1,round(.002*rate));x[-round(.08*rate):]*=np.linspace(1,0,round(.08*rate));x*=peak/max(abs(x));path=dst/(cue+'.wav');wavfile.write(path,rate,(x*32767).astype(np.int16))
 jobs.append(dict(id=cue,prompt=prompts[stem],source=str(source.relative_to(root)),source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),take=1,game_file=str(path.relative_to(root)),sha256=hashlib.sha256(path.read_bytes()).hexdigest(),duration=duration,channels=1,sample_rate=rate,peak_db=round(20*np.log10(peak),2),processing='35 Hz high-pass; stereo to mono; retain immediate onset; 2 ms / 80 ms edge fades; trim tail; peak normalize'))
manifest=dict(date='2026-09-13',provider='ElevenLabs web Sound Effects',settings=dict(duration_seconds=2,loop=False,prompt_influence=.3,model='not exposed in UI'),generation_notes='Launch prompt was accidentally submitted twice (4 candidates each); blast and collision each generated once (4 candidates). Selected launch is take 1 of the later batch. No further regeneration used to recover stalled downloads.',jobs=jobs,verification='File signal, duration and game playback verified separately; subjective listening not claimed.')
(root/'audio/manifests/space-combat-20260913.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
p=root/'우주-비즈니스/data/space_combat.json';d=json.loads(p.read_text());d['audio'].update(missile_launch='sfx_ship_missile_launch_v2',missile_blast='sfx_ship_missile_blast_v2',collision='sfx_ship_hull_collision');p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
p=root/'우주-비즈니스/scripts/world/space_skill_view.gd';p.write_text(p.read_text().replace('sfx_ship_missile_launch','sfx_vessel_boost'))
print([(j['id'],j['duration'],j['peak_db']) for j in jobs])
