"""Package the actual host and seeded flight frames; never synthesize a contact event."""
from pathlib import Path
import json,subprocess,hashlib
from PIL import Image,ImageDraw,ImageFont
import imageio_ffmpeg
ROOT=Path(__file__).resolve().parents[2]
def encode(frames,destination,fps):
    staging=ROOT/'output/creature-remodel'/('encode-'+destination.stem);staging.mkdir(parents=True,exist_ok=True)
    for i,path in enumerate(frames):
        target=staging/f'{i:05d}.png'
        if target.is_symlink():target.unlink()
        assert not target.exists();target.symlink_to(path.resolve())
    subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(),'-y','-v','error','-framerate',str(fps),'-i',str(staging/'%05d.png'),'-frames:v',str(len(frames)),'-c:v','libx264','-crf','19','-pix_fmt','yuv420p','-movflags','+faststart',str(destination)],check=True)
    return hashlib.sha256(destination.read_bytes()).hexdigest()
def main():
    for batch in ['combat','flight']:
        output=ROOT/'output/creature-remodel'/batch;media=ROOT/'docs/production/media/creature-remodel'/batch;media.mkdir(parents=True,exist_ok=True)
        evidence=json.loads((output/'evidence.json').read_text());assert evidence['renderer']=='forward_plus'
        if batch=='combat':
            assert evidence['failures']==0 and len(evidence['records'])==6
            frames=[output/name for r in evidence['records'] if r['outcome']=='hit' for name in r['frames']]
            for r in evidence['records']:assert r['rendered_contacts']==(1 if r['outcome']=='hit' else 0)
            fps=30;images=[output/f'{id}_{state}.png' for id in ['sailhorn','shearprowler'] for state in ['hit_028','hit_049','down']]
        else:
            assert evidence['root_error']==0 and len(evidence['clips'])==4 and evidence['max_ground_foot_error']<.025
            frames=[output/f'veilglider_{i:04d}.png' for i in range(0,1441,2)];fps=15;images=[output/f'veilglider_{i:04d}.png' for i in [60,375,435,540,1320,1410]]
        assert all(p.exists() for p in frames+images)
        evidence.update(video_frames=len(frames),video_fps=fps,video_sha256=encode(frames,media/(batch+'-motion.mp4'),fps),audio='Silent review. Runtime reuses existing cues; no new audio generation.')
        canvas=Image.new('RGB',(1650,800),'#cbd5d0')
        for i,path in enumerate(images):canvas.paste(Image.open(path).convert('RGB').resize((550,400),Image.Resampling.LANCZOS),((i%3)*550,(i//3)*400))
        canvas.save(media/(batch+'-board.jpg'),quality=94)
        (media/'evidence.json').write_text(json.dumps(evidence,ensure_ascii=False,indent=2)+'\n')
        manifest=ROOT/f'우주-비즈니스/data/creature_remodel_{batch}.json';data=json.loads(manifest.read_text())
        for row in data['forms']:
            row['status']='host-motion-and-render-reviewed' if batch=='combat' else 'seeded-flight-render-reviewed'
            (ROOT/'art/blender/creature_remodel'/batch/(row['id']+'.json')).write_text(json.dumps(row,ensure_ascii=False,indent=2)+'\n')
        manifest.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n');print('PACKAGED',batch,len(frames),'frames',fps,'fps')
if __name__=='__main__':main()
