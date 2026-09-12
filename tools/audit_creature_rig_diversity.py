"""Document rig diversity without assigning existing species to six preview rigs."""
from pathlib import Path
from collections import Counter
import json
ROOT=Path(__file__).resolve().parents[1]
forms=[]
for name in ['forms','xenofauna_forms','xenoflora_forms','biota_forms']:
    forms.extend(f for f in json.loads((ROOT/'우주-비즈니스/data/bestiary'/f'{name}.json').read_text())['forms'] if f['category']=='animal')
layouts=Counter(f.get('rig',{}).get('layout','legacy_without_skin_template') for f in forms)
structures=Counter(f.get('construction','legacy:'+f['family']) for f in forms)
templates=set(f['rig']['template'] for f in forms if f.get('rig',{}).get('template'))
data={'scope':'Catalog metadata inventory, not newly completed rigs or a retargeting map',
      'animal_forms':len(forms),'layout_counts':dict(layouts),'construction_counts':dict(structures),
      'distinct_recorded_template_names':len(templates),'review_representatives':6,
      'six_rig_limit':False,'automatic_assignment_to_representatives':False,
      'dedicated_rig_split_requirements':['limb number and joint axes','body segmentation and symmetry','weight-bearing surfaces and center of mass','wing/membrane/finger topology','mouth/pressure organ/weapon attachments','turning, locomotion medium and feeding behavior'],
      'reuse_boundary':'Share contact results and timing contracts. Reuse a skeleton only after verifying compatible anatomy, joint hierarchy, skin deformation and contact points.'}
p=ROOT/'docs/production/media/creature-motion/rig-diversity.json';p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
print(len(forms),'animals;',len(structures),'construction labels;',len(layouts)-1,'skin layout labels;',len(templates),'template names (metadata, not quality approval)')
