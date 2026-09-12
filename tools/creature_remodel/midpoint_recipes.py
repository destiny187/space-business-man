"""The remaining named ground anatomies; preserve every catalogue identity."""
from pathlib import Path
import json
from recipes import PALETTES
ROOT=Path(__file__).resolve().parents[2]
KINDS={'cervid','proboscid','canid','felid','chelonian','crocodilian','giraffoid','camelid','rhinocerid','bovid','anuran','monotreme','pangolin','armadillo','gekkonid','skink','macropod','lagomorph','mustelid','serpent','arachnid','scorpion','crab','hermit','mantid','beetle'}
APPROVED={'biota_spindle_armor_25','biota_lobopod_armor_26','biota_chain_armor_26','biota_ribbon_armor_26'}
def recipes():
    result=[]
    combat=json.loads((ROOT/'우주-비즈니스/data/wildlife_combat.json').read_text())
    for f in json.loads((ROOT/'우주-비즈니스/data/bestiary/biota_forms.json').read_text())['forms']:
        if f.get('construction') not in KINDS or f['id'] in APPROVED:continue
        r={k:f[k] for k in ['id','name','family','construction','organ_system','environment','locomotion_medium','anatomy_note']}
        r.update(source_id=f['id'],kind=f['construction'],source_renderer='BLENDER_EEVEE',habitat=f['habitat_note'],palette=PALETTES.get(f['environment'],PALETTES['basalt']),attack='bite',morphology={**f['body_plan'],'mode':f['body_plan']['topology'],'eye_count':f['eye_count']})
        pattern=combat['anatomical_attacks'].get(f['construction'],f.get('attack','none'))
        r.update(production_batch='r04',host_pattern=pattern,host_motion=combat.get('anatomical_behaviors',{}).get(f['construction'],{}).get('behavior',combat['patterns'].get(pattern,{}).get('behavior','')))
        result.append(r)
    return result
