"""Publish only complete per-species checkpoints. Does not enable campaign replacement."""
from pathlib import Path
import json,hashlib,os,sys
ROOT=Path(__file__).resolve().parents[2]
def main(batch):
    assert batch.isidentifier()
    rows=[]
    expected={}
    if batch=='r03':
        from production_recipes import recipes
        for spec in recipes():
            h=hashlib.sha256(json.dumps(spec,sort_keys=True).encode())
            for file in ['produce.py','production_recipes.py','production_motion.py','biota_anatomy.py','build_batch.py','source_stage.py']:
                h.update((Path(__file__).parent/file).read_bytes())
            for file in ['build_creature_studies.py','build_creature_remodel_r01.py','refine_creature_motion.py','ink_blender.py']:
                h.update((ROOT/'tools'/file).read_bytes())
            h.update((ROOT/'우주-비즈니스/data/ink_materials.json').read_bytes());expected[spec['id']]=h.hexdigest()
    elif batch=='r04':
        from produce_midpoints import recipes,fingerprint
        expected={s['id']:fingerprint(s) for s in recipes()}
    elif batch=='r05':
        from produce_air import recipes,fingerprint
        expected={s['id']:fingerprint(s) for s in recipes()}
    elif batch=='r06':
        from produce_legacy import recipes,fingerprint
        expected={s['id']:fingerprint(s) for s in recipes()}
    for p in sorted((ROOT/'art/blender/creature_remodel'/batch).glob('*.json')):
        if p.with_suffix('.lock').exists():continue
        row=json.loads(p.read_text())
        if expected and row['build_fingerprint']!=expected.get(row['id']):
            print('STALE_CHECKPOINT',row['id']);continue
        if any(not (ROOT/l['path']).exists() or hashlib.sha256((ROOT/l['path']).read_bytes()).hexdigest()!=l['sha256'] for l in row['lods'].values()):raise ValueError('Incomplete asset '+row['id'])
        # Describe the two authored peaks, without rebuilding meshes or changing host timing.
        if batch in ['r04','r06'] and row.get('host_motion')=='double_sweep':
            row['motion_profile'].update(release=[1.03,1.55],active_end=1.77)
        rows.append(row)
        # Small per-species runtime records; build audit and skeleton graphs remain offline.
        runtime={k:row[k] for k in ['id','source_id','name','kind','palette','attack','bone_count','locomotion_chains','clips','muzzle','lods','motion_profile','sockets']}
        for key in ['host_motion','host_pattern','air_motion']:
            if key in row:runtime[key]=row[key]
        destination=ROOT/'우주-비즈니스/data/creature_remodel'/batch/(row['id']+'.json');destination.parent.mkdir(parents=True,exist_ok=True)
        temp_entry=destination.with_suffix('.json.tmp');temp_entry.write_text(json.dumps(runtime,ensure_ascii=False,separators=(',',':'))+'\n');os.replace(temp_entry,destination)
    target=ROOT/f'우주-비즈니스/data/creature_remodel_{batch}.json';temp=target.with_suffix('.json.tmp')
    temp.write_text(json.dumps({'version':1,'scope':'Complete Blender checkpoints; runtime enablement requires matching actual render evidence','forms':rows},ensure_ascii=False,indent=2)+'\n');os.replace(temp,target)
    print(batch,len(rows),'complete models published for review')
if __name__=='__main__':main(sys.argv[1])
