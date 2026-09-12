"""Produce flight/atmosphere anatomies without changing their original placement."""
from pathlib import Path
import sys,json,hashlib,os
ROOT=Path(__file__).resolve().parents[2];sys.path[:0]=[str(Path(__file__).parent),str(ROOT/'tools'),str(ROOT/'tools/bestiary')]
from air_recipes import recipes
def fingerprint(spec):
    h=hashlib.sha256(json.dumps(spec,sort_keys=True).encode())
    for file in ['produce_air.py','air_recipes.py','air_anatomy.py','air_motion.py','production_core.py','anatomy_stage.py','biota_anatomy.py','build_batch.py']:
        h.update((Path(__file__).parent/file).read_bytes())
    for file in ['build_creature_studies.py','build_creature_remodel_r01.py','refine_creature_motion.py','ink_blender.py']:
        h.update((ROOT/'tools'/file).read_bytes())
    h.update((ROOT/'우주-비즈니스/data/ink_materials.json').read_bytes());return h.hexdigest()
def main():
    from production_core import build
    from air_anatomy import body
    from air_motion import animate
    from anatomy_stage import render
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [];rows=recipes()
    if '--representatives' in args:
        groups={}
        for r in rows:
            key=(r['locomotion_medium'],r['anatomical_type'],r.get('flight',{}).get('wing_style',''))
            groups.setdefault(key,r)
        rows=list(groups.values())
    elif '--all' not in args:rows=[r for r in rows if r['id'] in args or r['construction'] in args or r['locomotion_medium'] in args]
    assert rows
    source=ROOT/'art/blender/creature_remodel/r05';source.mkdir(parents=True,exist_ok=True)
    for spec in rows:
        lock=source/(spec['id']+'.lock');fd=os.open(lock,os.O_CREAT|os.O_EXCL|os.O_WRONLY)
        with os.fdopen(fd,'w') as stream:stream.write(str(os.getpid()))
        try:build(spec,'r05',fingerprint,body,animate,render)
        finally:lock.unlink()
    print('PRODUCTION_COMPLETE',len(rows),flush=True)
if __name__=='__main__':main()
