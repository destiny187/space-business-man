"""Explicit species/type selection; independent of the frozen R03 production workers."""
from pathlib import Path
import sys,json,hashlib,os
ROOT=Path(__file__).resolve().parents[2];sys.path[:0]=[str(Path(__file__).parent),str(ROOT/'tools'),str(ROOT/'tools/bestiary')]
from midpoint_recipes import recipes

def revised_contact(spec):
    return spec.get('host_pattern') in ['claw','scythe'] and spec['construction'] in ['felid','scorpion','mantid']

def fingerprint(spec):
    h=hashlib.sha256(json.dumps(spec,sort_keys=True).encode())
    for file in ['produce_midpoints.py','midpoint_recipes.py','midpoint_anatomy.py','midpoint_motion.py','production_core.py','anatomy_stage.py','biota_anatomy.py','build_batch.py']:
        # Only the twenty claw/sweep species enter the revised animation branch.
        # Other species retain the exact original source provenance and assets.
        path=Path(__file__).parent/file
        if not revised_contact(spec) and file in ['produce_midpoints.py','midpoint_motion.py']:
            path=path.parent/'compat'/(path.stem+'_v1.py')
        h.update(path.read_bytes())
    for file in ['build_creature_studies.py','build_creature_remodel_r01.py','refine_creature_motion.py','bestiary/biota_midpoint_art.py','ink_blender.py']:
        h.update((ROOT/'tools'/file).read_bytes())
    h.update((ROOT/'우주-비즈니스/data/ink_materials.json').read_bytes());return h.hexdigest()

def main():
    from production_core import build
    from midpoint_anatomy import body
    from midpoint_motion import animate
    from anatomy_stage import render
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    rows=recipes()
    if '--representatives' in args:rows=[next(r for r in rows if r['construction']==kind) for kind in dict.fromkeys(r['construction'] for r in rows)]
    elif '--all' not in args:rows=[r for r in rows if r['id'] in args or r['construction'] in args]
    assert rows
    source=ROOT/'art/blender/creature_remodel/r04';source.mkdir(parents=True,exist_ok=True)
    for spec in rows:
        lock=source/(spec['id']+'.lock');fd=os.open(lock,os.O_CREAT|os.O_EXCL|os.O_WRONLY)
        with os.fdopen(fd,'w') as stream:stream.write(str(os.getpid()))
        try:build(spec,'r04',fingerprint,body,animate,render)
        finally:lock.unlink()
    print('PRODUCTION_COMPLETE',len(rows),flush=True)
if __name__=='__main__':main()
