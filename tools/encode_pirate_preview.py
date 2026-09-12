"""Encode the real Godot Movie Maker capture; no synthesized/interpolated frames.
Requires imageio-ffmpeg in the chosen Python environment. Raw AVI remains in output/.
"""
from pathlib import Path
import json,subprocess,argparse
import imageio_ffmpeg
ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--capture',choices=['pirate-quality','pirate-explosion'],default='pirate-quality');args=parser.parse_args()
raw=ROOT/'output'/args.capture/'flight-raw.avi'
meta=json.loads((raw.parent/'movie.json').read_text())
out=ROOT/'docs/production/media'/args.capture/'flight-combat.mp4'
out.parent.mkdir(parents=True,exist_ok=True)
ffmpeg=imageio_ffmpeg.get_ffmpeg_exe()
start=meta['start_frame']/meta['fps'];duration=(meta['end_frame']-meta['start_frame'])/meta['fps']
subprocess.run([ffmpeg,'-hide_banner','-loglevel','error','-y','-ss',str(start),'-i',str(raw),'-t',str(duration),'-c:v','libx264','-crf','19','-pix_fmt','yuv420p','-movflags','+faststart','-c:a','aac','-b:a','160k',str(out)],check=True)
for i,second in enumerate([2.8,3.8,5.2,6.4,8.8,10.3,11.4,12.1]):
 subprocess.run([ffmpeg,'-hide_banner','-loglevel','error','-y','-ss',str(second),'-i',str(out),'-frames:v','1',str(raw.parent/f'movie-review-{i}.png')],check=True)
(out.parent/'movie-provenance.json').write_text(json.dumps({**meta,'start_seconds':start,'duration_seconds':duration,'game_scene':'res://scenes/app/crew_expedition.tscn','capture_script':'res://tests/render_pirate_explosion.gd' if args.capture=='pirate-explosion' else 'res://tests/render_pirate_motion.gd','render':'Godot 4.7.2 Forward+ / Metal; Movie Maker fixed 60 FPS','note':'Scripted pilot inputs through the actual host; offline rendering, not a real-time FPS benchmark; original mixed audio retained'},ensure_ascii=False,indent=2)+'\n')
print(out,round(duration,3),'seconds',out.stat().st_size,'bytes')
