"""Track every animal ID without replacing species or folding them into six rigs."""
from pathlib import Path
from collections import Counter
import hashlib,json,sys
sys.path.insert(0,str(Path(__file__).resolve().parent/"creature_remodel"))
from recipes import recipes as remodel_recipes
from production_recipes import recipes as production_recipes
from midpoint_recipes import recipes as midpoint_recipes
from air_recipes import recipes as air_recipes
from legacy_recipes import recipes as legacy_recipes
from publish_manifest import expected_fingerprints,checkpoint_current
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
    batches={r['source_id']:{**r,'batch':'R02'} for r in remodel_recipes()}
    batches.update({r['source_id']:{**r,'batch':'R03'} for r in production_recipes()})
    for batch,recipe in [('R04',midpoint_recipes),('R05',air_recipes),('R06',legacy_recipes)]:
        batches.update({r['source_id']:{**r,'batch':batch} for r in recipe()})
    built={};captured=set();audited=set()
    for batch in ['r02','r03','r04','r05','r06']:
        expected=expected_fingerprints(batch)
        for p in (ROOT/'art/blender/creature_remodel'/batch).glob('*.json'):
            if p.with_suffix('.lock').exists():continue
            entry=json.loads(p.read_text())
            if expected and not checkpoint_current(entry,expected):continue
            if batch=='r06':
                from strike_metadata import patch
                patch(entry)
                from body_support_metadata import patch as patch_body
                patch_body(entry)
            built[entry['source_id']]=entry
            evidence=ROOT/'output/creature-remodel'/batch/(entry['id']+'_evidence.json')
            if evidence.exists():
                data=json.loads(evidence.read_text());record=data.get('species',data)
                if record.get('id')==entry['id'] and data.get('renderer')=='forward_plus' and record.get('asset_sha256')=={k:v['sha256'] for k,v in entry['lods'].items()} and (batch=='r05' or record.get('authored_pose_capture_version',0)>=2) and record.get('contact_metadata_version',0)==entry.get('contact_metadata_version',0) and record.get('body_support_version',0)==entry.get('body_support_version',0):captured.add(entry['source_id'])
        evidence=ROOT/'docs/production/media/creature-remodel'/batch/'evidence.json'
        if evidence.exists():
            data=json.loads(evidence.read_text())
            for record in data.get('species',[]):
                entry=next((r for r in built.values() if r['id']==record['id']),None)
                if entry and record.get('asset_sha256')=={k:v['sha256'] for k,v in entry['lods'].items()} and (batch=='r05' or record.get('authored_pose_capture_version',0)>=2) and record.get('contact_metadata_version',0)==entry.get('contact_metadata_version',0) and record.get('body_support_version',0)==entry.get('body_support_version',0):audited.add(entry['source_id'])
    runtime=json.loads((ROOT/'우주-비즈니스/data/creature_remodel_runtime.json').read_text())
    enabled=set(runtime['enabled_ground_species'])|set(runtime.get('enabled_air_species',[]))
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
                     'batch':'R01' if form['id'] in first else batches.get(form['id'],{}).get('batch'),
                     'asset_id':first.get(form['id'],batches.get(form['id'],{}).get('id')),
                     'art_status':'approved-reference' if form['id'] in {r['source_id'] for r in approved} else 'queued',
                     'runtime_status':'pending','individual_review':'pending'})
        if form['id'] in built:
            rows[-1]['art_status']='built-awaiting-render'
            rows[-1]['build_fingerprint']=built[form['id']]['build_fingerprint']
        if form['id'] in captured:rows[-1]['individual_review']='renderer-captured'
        if form['id'] in audited:rows[-1]['art_status']='asset-and-render-audited'
        if form['id'] in enabled:rows[-1]['runtime_status']='enabled-presentation'
    assert len(rows)==5600 and len({r['species_id'] for r in rows})==5600
    destination.parent.mkdir(parents=True,exist_ok=True)
    destination.write_text(json.dumps({'version':1,'scope':'All 5600 animals; plants and microbial colonies retain existing assets in this animal pass',
        'species_count':8000,'animal_count':5600,'catalog_sha256':catalogs,
        'construction_counts':dict(Counter(r['anatomy']['structure'] for r in rows)),
        'rules':['No six-rig limit','No species added for color or size changes','Preserve species IDs, native origins and existing save hashes',
                 'Asset build, rendered review and campaign integration are separate states','Split rigs when joints, limbs, symmetry, organs or propulsion differ'],
        'progress':{'models_built':len(first)+len(built),'renderer_captured':len(captured),'asset_and_render_audited':len(audited),'campaign_replacements':len(enabled),'remaining_replacements':5600-len(enabled),
                    'batches':{batch:{'planned':sum(r['batch']==batch for r in batches.values()),'built':sum(batches[id]['batch']==batch for id in built),'enabled':sum(batches[id]['batch']==batch for id in enabled if id in batches)} for batch in ['R02','R03','R04','R05','R06']}},'forms':rows},ensure_ascii=False,indent=2)+'\n')
    print(len(rows),'animal IDs queued;',len(first),'R01 IDs;',len(set(r['anatomy']['structure'] for r in rows)),'structure labels (not finished rigs)')
if __name__=='__main__':main()
