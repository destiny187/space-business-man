"""Run GPU presentation reviews sequentially to bound memory usage."""
from pathlib import Path
import subprocess
ROOT=Path(__file__).resolve().parents[2]
commands=[('gallery-tests',['./tools/godot.sh','--script','res://tests/check_bestiary_gallery.gd']),('field',['./tools/godot.sh','--script','res://tests/capture_bestiary_field.gd']),('attacks-final',['./tools/show_bestiary.sh','--','--attack-captures']),('film-frames',['./tools/show_bestiary.sh','--','--film-captures'])]
for label,command in commands:
 print('REVIEW_START',label,flush=True)
 p=Path('/tmp')/('bestiary-'+label+'.log')
 with p.open('w') as log: result=subprocess.run(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
 assert result.returncode==0 and 'ERROR:' not in p.read_text(),p.read_text()[-3000:]
 print('REVIEW_DONE',label,flush=True)
