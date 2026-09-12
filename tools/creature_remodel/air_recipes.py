"""Separate pressure-supported atmospheric fauna and surface birds."""
from pathlib import Path
import json
from recipes import PALETTES
ROOT=Path(__file__).resolve().parents[2]
def recipes():
    rows=[]
    refinements=json.loads((Path(__file__).parent/'air_refinements.json').read_text())
    for f in json.loads((ROOT/'우주-비즈니스/data/bestiary/biota_forms.json').read_text())['forms']:
        if f.get('category')!='animal' or f.get('locomotion_medium') not in ['surface_air','atmosphere'] or f['id']=='biota_bilateral_armor_11':continue
        r={k:f[k] for k in ['id','name','family','construction','organ_system','environment','locomotion_medium','anatomy_note']}
        r.update(source_id=f['id'],kind=f['construction'],source_renderer='BLENDER_EEVEE',habitat=f['habitat_note'],palette=PALETTES.get(f['environment'],PALETTES['basalt']),attack='dart',morphology={**f['body_plan'],'mode':f['body_plan']['topology'],'eye_count':f['eye_count']},flight=f.get('flight',{}),anatomical_type=f.get('anatomical_type','avian' if f['locomotion_medium']=='surface_air' else f['construction']),production_batch='r05',air_motion=f['locomotion_medium']=='surface_air',host_pattern='none')
        if f['id'] in refinements:r['art_refinements']=refinements[f['id']]
        rows.append(r)
    return rows
