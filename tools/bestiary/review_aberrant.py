"""Run the new collection's UI and attack captures sequentially on the GPU."""
from pathlib import Path
import subprocess,os,json
ROOT=Path(__file__).resolve().parents[2]
dest=ROOT/'docs/production/media/bestiary/aberrant'
env=dict(os.environ,BESTIARY_FILM_FRAMES='/tmp/aberrant-film-frames')
commands=[
 ['tools/godot.sh','--script','res://tests/check_bestiary_gallery.gd'],
 ['tools/show_bestiary.sh','--','--aberrant','--attack-captures'],
 ['tools/show_bestiary.sh','--','--aberrant','--film-captures'],
]
results=[]
for i,cmd in enumerate(commands):
 print('ABERRANT_REVIEW_START',i,flush=True)
 result=subprocess.run(cmd,cwd=ROOT,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
 (dest/f'review-{i}.log').write_text(result.stdout)
 assert result.returncode==0 and 'ERROR:' not in result.stdout,result.stdout[-4000:]
 results.append({'command':cmd,'exit_code':result.returncode})
 print('ABERRANT_REVIEW_DONE',i,flush=True)
(dest/'review-verification.json').write_text(json.dumps({'status':'pass','runs':results},indent=2)+'\n')
