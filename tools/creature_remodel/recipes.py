"""Species anatomy recipes: identity comes from the original catalogue, never from color variants."""
from pathlib import Path
import json,hashlib
ROOT=Path(__file__).resolve().parents[2]
FAMILIES={'torus_loom':'annular','pentapalm':'radial','pendulum_grazer':'cantilever','quill_amphora':'pressure','hinge_book':'bivalve','mirror_fork':'forked'}
APPROVED={'bio_torus_loom_01','bio_pentapalm_03','bio_pendulum_grazer_01','bio_quill_amphora_01'}
PALETTES={'basalt':['586f70','b6bda1','33494c','bd925d'],'arid':['987353','d8c393','3e5555','a68051'],'thermal':['7c6659','c8b397','3e5352','bf7a47'],'crystal':['627789','b6c7b5','374c62','c49361'],'cave':['695e77','bab0b1','34494e','ab9567']}

def recipes():
    forms=json.loads((ROOT/'우주-비즈니스/data/bestiary/xenofauna_forms.json').read_text())['forms']
    result=[]
    for row in forms:
        if row['family'] not in FAMILIES or row['id'] in APPROVED:continue
        plan=row['body_plan'];mode=int(plan['branch_mode']);kind=FAMILIES[row['family']]
        morphology={**plan,'mode':mode,'sensory_type':row['sensory_type'],'eye_count':row['eye_count'],
                    'neck_length':[1.60,1.2,2.1,.85,2.6,1.8,1.4,2.2,1.0,2.45][mode],
                    'organ_branch':[1,2,1,3,1,2,3,2,4,3][mode],
                    'shell_lobes':[3,4,5,6,7,5,4,6,8,7][mode]}
        spec={'id':row['id'],'source_id':row['id'],'name':row['name'],'kind':kind,'family':row['family'],
              'habitat':row['environment_label'],'palette':PALETTES.get(row['environment'],PALETTES['basalt']),
              'morphology':morphology,'attack':'spit' if kind in ['annular','pressure'] else ('slam' if kind=='radial' else 'bite')}
        spec['recipe_sha256']=hashlib.sha256(json.dumps(spec,sort_keys=True).encode()).hexdigest()
        result.append(spec)
    assert len(result)==56
    return result
