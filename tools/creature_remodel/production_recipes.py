"""Read all catalogue IDs; explicitly supported anatomies only, without placeholder fallbacks."""
from pathlib import Path
import json,hashlib
from recipes import PALETTES
ROOT=Path(__file__).resolve().parents[2]
SUPPORTED={'spindle','lobopod','radial','tower','saddle','mantle','spiral','flat','chain','bilateral','crown','amphora','ribbon','branch'}
def recipes():
    forms=json.loads((ROOT/'우주-비즈니스/data/bestiary/biota_forms.json').read_text())['forms']
    result=[]
    for f in forms:
        if f['category']!='animal' or f.get('construction') not in SUPPORTED or f.get('locomotion_medium')!='ground':continue
        spec={k:f[k] for k in ['id','name','family','construction','organ_system','environment','locomotion_medium']}
        spec.update(source_renderer='BLENDER_EEVEE',source_id=f['id'],kind=f['construction'],habitat=f['habitat_note'],attack='spit' if f['organ_system']=='siphons' else 'bite',palette=PALETTES.get(f['environment'],PALETTES['basalt']),morphology={**f['body_plan'],'mode':f['body_plan']['topology'],'eye_count':f['eye_count']},anatomy_note=f['anatomy_note'])
        spec['recipe_sha256']=hashlib.sha256(json.dumps(spec,sort_keys=True).encode()).hexdigest();result.append(spec)
    return result
if __name__=='__main__':
    from collections import Counter
    rows=recipes();print(len(rows),Counter(r['construction'] for r in rows))
