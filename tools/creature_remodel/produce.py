"""Resumable production entry point. Disjoint workers write only per-species assets.

blender -b -t 4 --python tools/creature_remodel/produce.py -- <family or species ID>
An explicit --all processes every implemented recipe. Manifest publication is separate.
"""
from pathlib import Path
import sys,json,hashlib,os,traceback
ROOT=Path(__file__).resolve().parents[2];sys.path[:0]=[str(Path(__file__).parent),str(ROOT/'tools')]
import build_batch as pipeline
from production_recipes import recipes
from production_motion import animate
from source_stage import render as render_source
from biota_anatomy import body,GROUND_KINDS
SRC=ROOT/'art/blender/creature_remodel/r03';OUT=ROOT/'우주-비즈니스/assets/models/creature_remodel/r03';MEDIA=ROOT/'docs/production/media/creature-remodel/r03'

def fingerprint(spec):
    h=hashlib.sha256(json.dumps(spec,sort_keys=True).encode())
    for file in ['produce.py','production_recipes.py','production_motion.py','biota_anatomy.py','build_batch.py','source_stage.py']:
        h.update((Path(__file__).parent/file).read_bytes())
    for file in ['build_creature_studies.py','build_creature_remodel_r01.py','refine_creature_motion.py','ink_blender.py']:
        h.update((ROOT/'tools'/file).read_bytes())
    h.update((ROOT/'우주-비즈니스/data/ink_materials.json').read_bytes())
    return h.hexdigest()

def main():
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    if not args:raise SystemExit('Select an exact species, family, construction, or --all.')
    for path in [SRC,OUT,MEDIA/'blender']:path.mkdir(parents=True,exist_ok=True)
    pipeline.SRC=SRC;pipeline.OUT=OUT;pipeline.MEDIA=MEDIA;pipeline.VERSION='r03-2';pipeline.BUILDERS={kind:body for kind in GROUND_KINDS};pipeline.animate=animate;pipeline.source_render=render_source;pipeline.fingerprint=fingerprint
    selected=[r for r in recipes() if '--all' in args or any(r[k] in args for k in ['id','family','construction'])]
    assert selected,'No matching anatomical recipe'
    for spec in selected:
        # Prevent a second production process from touching this species while Blender is writing.
        lock=SRC/(spec['id']+'.lock')
        try:fd=os.open(lock,os.O_CREAT|os.O_EXCL|os.O_WRONLY)
        except FileExistsError:raise RuntimeError('Species is locked; inspect recorded PID before recovering: '+str(lock))
        with os.fdopen(fd,'w') as stream:stream.write(str(os.getpid()))
        try:pipeline.build(spec)
        finally:lock.unlink()
    print('PRODUCTION_COMPLETE',len(selected),flush=True)
if __name__=='__main__':main()
