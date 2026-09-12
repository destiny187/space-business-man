"""Track every animal ID without replacing species or folding them into six rigs."""
from pathlib import Path
from collections import Counter
import hashlib,json,sys
sys.path.insert(0,str(Path(__file__).resolve().parent/"creature_remodel"))
from recipes import recipes as remodel_recipes
ROOT=Path(__file__).resolve().parents[1]
def main():
    destination=ROOT/'docs/production/media/creature-remodel/queue.json'
    previous=json.loads(destination.read_text()) if destination.exists() else {}
    previous_rows={r['species_id']:r for r in previous.get('forms',[])}
    forms=[];catalogs={}
    for name in ['forms','xenofauna_forms','xenoflora_forms','biota_forms']:
        path=ROOT/'우주-비즈니스/data/bestiary'/f'{name}.json'
        catalogs[name]=hashlib.sha256(path.read_bytes()).hexdigest()
        forms.extend(json.loads(path.read_text())['forms'])
    approved=json.loads((ROOT/'우주-비즈니스/data/creature_motion_studies.json').read_text())['forms']
    first={r['source_id']:r['id'] for r in approved}
    first.update({'bio_torus_loom_01':'annulus','bio_pentapalm_03':'pentafold','bio_pendulum_grazer_01':'tethermaw'})
    batches={r['source_id']:r for r in remodel_recipes()}
    built={p.stem:json.loads(p.read_text()) for p in (ROOT/'art/blender/creature_remodel/r02').glob('bio_*.json')}
    rows=[]
    for form in forms:
        if form['category']!='animal':continue
        plan=form.get('body_plan',{});rig=form.get('rig',{})
        structure=form.get('construction',form['family'])
        anatomy={'structure':structure,'medium':form.get('locomotion_medium','ground'),
                 'limbs':plan.get('limb_count'),'radial':plan.get('radial_count'),
                 'topology':plan.get('topology',plan.get('branch_mode')),'organ':form.get('organ_system',form.get('sensory_type')),
                 'existing_template':rig.get('template','legacy-unskinned')}
        rows.append({'species_id':form['id'],'family':form['family'],'anatomy':anatomy,
                     'batch':'R01' if form['id'] in first else ('R02' if form['id'] in batches else None),
                     'asset_id':first.get(form['id'],batches.get(form['id'],{}).get('id')),
                     'art_status':'approved-reference' if form['id'] in {r['source_id'] for r in approved} else 'queued',
                     'runtime_status':'pending','individual_review':'pending'})
        if form['id'] in built:
            rows[-1]['art_status']='built-awaiting-render'
            rows[-1]['build_fingerprint']=built[form['id']]['build_fingerprint']
        old=previous_rows.get(form['id'],{})
        if old.get('asset_id')==rows[-1]['asset_id'] and old.get('build_fingerprint')==rows[-1].get('build_fingerprint'):
            for key in ['art_status','runtime_status','individual_review']:
                if key in old:rows[-1][key]=old[key]
    assert len(rows)==5600 and len({r['species_id'] for r in rows})==5600
    destination.parent.mkdir(parents=True,exist_ok=True)
    destination.write_text(json.dumps({'version':1,'scope':'All 5600 animals; plants and microbial colonies retain existing assets in this animal pass',
        'species_count':8000,'animal_count':5600,'catalog_sha256':catalogs,
        'construction_counts':dict(Counter(r['anatomy']['structure'] for r in rows)),
        'rules':['No six-rig limit','No species added for color or size changes','Preserve species IDs, native origins and existing save hashes',
                 'Asset build, rendered review and campaign integration are separate states','Split rigs when joints, limbs, symmetry, organs or propulsion differ'],
        'progress':{**previous.get('progress',{}),'models_built':len(first)+len(built),'r02_planned':len(batches),'r02_built':len(built),'other_animal_ids':5600-len(first)-len(built)},'forms':rows},ensure_ascii=False,indent=2)+'\n')
    print(len(rows),'animal IDs queued;',len(first),'R01 IDs;',len(set(r['anatomy']['structure'] for r in rows)),'structure labels (not finished rigs)')
if __name__=='__main__':main()
