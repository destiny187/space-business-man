"""Collect the verified local motion review into the small tracked evidence set.

Run with Python providing Pillow and imageio-ffmpeg after the render/check commands.
"""
import hashlib
import json
import math
import re
import shutil
import statistics
import subprocess
import wave
from array import array
from pathlib import Path
from PIL import Image, ImageDraw
import imageio_ffmpeg

ROOT=Path(__file__).resolve().parents[1]
RAW=ROOT/'output/creature-fast-motion'
OUT=ROOT/'docs/production/media/creature-fast-motion'


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    selection=json.loads((ROOT/'tools/creature_remodel/fast_motion_review.json').read_text())
    metadata={id:json.loads((ROOT/'우주-비즈니스/data/creature_fast_motion'/f'{id}.json').read_text()) for id in selection['baseline']+selection['additional']}
    ffmpeg=imageio_ffmpeg.get_ffmpeg_exe()
    for group,ids in [('comparison',[metadata[id]['id'] for id in selection['baseline']]),('types',selection['additional'])]:
        movies=[]
        for id in ids:
            frames=list((RAW/group/id).glob('frame-*.png'));assert len(frames)==(360 if group=='comparison' else 150),id
            movie=RAW/group/(id+'.mp4')
            if not movie.exists() or max(p.stat().st_mtime for p in frames)>movie.stat().st_mtime:
                subprocess.run([ffmpeg,'-y','-loglevel','error','-framerate','30','-i',str(RAW/group/id/'frame-%03d.png'),
                                '-c:v','libx264','-preset','fast','-threads','2','-crf','21','-pix_fmt','yuv420p','-movflags','+faststart',str(movie)],check=True)
            movies.append(movie.resolve())
        listing=RAW/(group+'-concat.txt');listing.write_text(''.join("file '"+str(p)+"'\n" for p in movies))
        subprocess.run([ffmpeg,'-y','-loglevel','error','-f','concat','-safe','0','-i',str(listing),'-c','copy','-movflags','+faststart',str(OUT/(group+'.mp4'))],check=True)
        board=Image.new('RGB',(1280,300*len(ids)),(240,242,237))
        for i,id in enumerate(ids):
            for column,frame in enumerate([165,232] if group=='comparison' else [72,85]):
                im=Image.open(RAW/group/id/f'frame-{frame:03}.png');im.thumbnail((640,300));board.paste(im,(column*640,300*i))
        board.save(OUT/(group+'-board.jpg'),quality=90)
    rows=json.loads((RAW/'blender-final/evidence.json').read_text())
    rows.sort(key=lambda r:(selection['baseline']+selection['additional']).index(r['species_id']))
    board=Image.new('RGB',(1920,400*math.ceil(len(rows)/4)),(236,240,235));draw=ImageDraw.Draw(board)
    for i,row in enumerate(rows):
        im=Image.open(RAW/'blender-final'/f"{row['species_id']}-8.png");im.thumbnail((480,360))
        x=i%4*480;y=i//4*400;board.paste(im,(x,y+25));draw.text((x+6,y+5),row['species_id'],fill=(25,40,35))
    board.save(OUT/'blender-board.jpg',quality=90)
    (OUT/'blender-evidence.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
    for name in ['native-warning.png','native-attack.png','native-down.png','native-runtime.wav']:
        shutil.copyfile(Path('/tmp/native-combat-play')/name,OUT/name)
    with wave.open(str(OUT/'native-runtime.wav')) as recording:
        assert recording.getsampwidth()==2
        pcm=array('h',recording.readframes(recording.getnframes()))
        audio=dict(seconds=recording.getnframes()/recording.getframerate(),peak=max(abs(v) for v in pcm)/32768,
                   rms=math.sqrt(sum(v*v for v in pcm)/len(pcm))/32768)
    (OUT/'audio-evidence.json').write_text(json.dumps(audio,indent=2)+'\n')
    shutil.copyfile('/tmp/creature-fast-movement/evidence.json',OUT/'host-movement-evidence.json')
    shutil.copyfile(RAW/'types/evidence.json',OUT/'types-evidence.json')
    evidence=json.loads((RAW/'asset-verification.json').read_text());evidence.pop('species_results')
    evidence['authoring_sha256']=hashlib.sha256((ROOT/'tools/creature_remodel/fast_motion.py').read_bytes()).hexdigest()
    evidence['rendered_species']=17;evidence['rendered_frames']=3600;evidence['actual_campaign_additional_species']='biota_lobopod_siphons_25'
    evidence['checks']={}
    for key,path,label in [('host_movement','/tmp/creature-fast-movement.log','CREATURE_FAST_MOVEMENT'),
                           ('existing_attack_patterns','/tmp/creature-fast-domain-final.log','NATIVE_PATTERNS'),
                           ('native_incidents','/tmp/creature-fast-incidents.log','NATIVE_CHECKS'),
                           ('flight_path','/tmp/creature-fast-flight.log','CREATURE_FAST_FLIGHT'),
                           ('actual_campaign','/tmp/creature-fast-field.log','NATIVE_COMBAT_PLAY')]:
        output=Path(path).read_text();match=re.search(label+r' (\d+) FAILURES (\d+)',output)
        assert match and int(match[2])==0 and 'SCRIPT ERROR' not in output,('Missing successful check log',path)
        (OUT/(key+'-check.txt')).write_text('\n'.join(line.rstrip() for line in output.splitlines())+'\n')
        evidence['checks'][key]={'checks':int(match[1]),'failures':int(match[2]),'log':key+'-check.txt'}
    evidence['comparison']=[]
    for id in selection['baseline']:
        meta=metadata[id];frames=json.loads((RAW/'comparison'/meta['id']/'runtime.json').read_text())
        steady=frames[150:210];fast=[r for r in frames if r['clip'] in ['sprint_loop','sprint_charge_loop']]
        evidence['comparison'].append(dict(species_id=id,art_id=meta['id'],steady_requested_mps=statistics.mean(r['requested_mps'] for r in steady),
            steady_rate=statistics.mean(r['clip_rate'] for r in steady),max_fast_rate=max(r['clip_rate'] for r in fast),
            max_transition_rate=max(r['clip_rate'] for r in frames),max_planted_error=max((f['target_error_m'] for r in frames for f in r['feet'] if f['planted']),default=0)))
    (OUT/'evidence.json').write_text(json.dumps(evidence,ensure_ascii=False,indent=2)+'\n')
    print('FAST_REVIEW_PACKAGED',len(metadata),'species')


if __name__=='__main__':main()
