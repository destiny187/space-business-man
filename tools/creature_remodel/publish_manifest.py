"""Publish only complete per-species checkpoints. Does not enable campaign replacement."""
from pathlib import Path
import json,hashlib,os,sys,fcntl
ROOT=Path(__file__).resolve().parents[2]
def expected_fingerprints(batch):
    expected={}
    if batch=='r03':
        from production_recipes import recipes
        files=[Path(__file__).parent/file for file in ['produce.py','production_recipes.py','production_motion.py','biota_anatomy.py','build_batch.py','source_stage.py']]
        files += [ROOT/'tools'/file for file in ['build_creature_studies.py','build_creature_remodel_r01.py','refine_creature_motion.py','ink_blender.py']]
        files.append(ROOT/'우주-비즈니스/data/ink_materials.json')
        common=b''.join(file.read_bytes() for file in files)
        for spec in recipes():
            h=hashlib.sha256(json.dumps(spec,sort_keys=True).encode())
            h.update(common);expected[spec['id']]=h.hexdigest()
    elif batch=='r04':
        from produce_midpoints import recipes,fingerprint
        expected={s['id']:fingerprint(s) for s in recipes()}
    elif batch=='r05':
        from produce_air import recipes,fingerprint
        expected={s['id']:fingerprint(s) for s in recipes()}
    elif batch=='r06':
        from produce_legacy import recipes,fingerprint
        expected={s['id']:fingerprint(s) for s in recipes()}
    return expected

def checkpoint_current(row,expected):
    from produce_captured import fingerprint as captured_fingerprint
    base=expected.get(row['id'])
    if row['build_fingerprint']==base:return True
    if base is None or row.get('animation_capture')!={'version':1,'base_fingerprint':base}:return False
    if row['build_fingerprint']==captured_fingerprint(base):return True
    from produce_reused import fingerprint as reused_fingerprint,legacy_fingerprint
    reuse=row.get('lod_animation_reuse',{})
    return any(reuse=={'version':v,'source':'near'} and row['build_fingerprint']==legacy_fingerprint(base,v) for v in [1,2]) or (reuse=={'version':3,'source':'near'} and row['build_fingerprint']==reused_fingerprint(base))

def publish(batch):
    assert batch.isidentifier()
    rows=[];expected=expected_fingerprints(batch)
    cache_path=ROOT/'output/creature-remodel/production'/('verified-assets-'+batch+'.json')
    cache=json.loads(cache_path.read_text()) if cache_path.exists() else {}
    cache_changed=False
    for p in sorted((ROOT/'art/blender/creature_remodel'/batch).glob('*.json')):
        if p.with_suffix('.lock').exists():continue
        row=json.loads(p.read_text())
        if expected and not checkpoint_current(row,expected):
            print('STALE_CHECKPOINT',row['id']);continue
        for asset in row['lods'].values():
            path=ROOT/asset['path'];stat=path.stat()
            signature=[stat.st_size,stat.st_mtime_ns,asset['sha256']]
            if cache.get(asset['path'])!=signature:
                if hashlib.sha256(path.read_bytes()).hexdigest()!=asset['sha256']:raise ValueError('Incomplete asset '+row['id'])
                cache[asset['path']]=signature;cache_changed=True
        # Describe the two authored peaks, without rebuilding meshes or changing host timing.
        if batch in ['r04','r06'] and row.get('host_motion')=='double_sweep':
            row['motion_profile'].update(release=[1.03,1.55],active_end=1.77)
        if batch=='r06':
            from strike_metadata import patch
            patch(row)
            from body_support_metadata import patch as patch_body
            patch_body(row)
            from coiled_support_metadata import patch as patch_coiled
            patch_coiled(row)
        if batch=='r03':
            from low_body_support_metadata import patch as patch_low_body
            patch_low_body(row)
        rows.append(row)
        # Small per-species runtime records; build audit and skeleton graphs remain offline.
        runtime={k:row[k] for k in ['id','source_id','name','kind','palette','attack','bone_count','locomotion_chains','clips','muzzle','lods','motion_profile','sockets']}
        for key in ['host_motion','host_pattern','air_motion','contact_metadata_version','body_support_version']:
            if key in row:runtime[key]=row[key]
        destination=ROOT/'우주-비즈니스/data/creature_remodel'/batch/(row['id']+'.json');destination.parent.mkdir(parents=True,exist_ok=True)
        content=json.dumps(runtime,ensure_ascii=False,separators=(',',':'))+'\n'
        if not destination.exists() or destination.read_text()!=content:
            temp_entry=destination.with_suffix('.json.tmp');temp_entry.write_text(content);os.replace(temp_entry,destination)
    target=ROOT/f'우주-비즈니스/data/creature_remodel_{batch}.json';temp=target.with_suffix('.json.tmp')
    temp.write_text(json.dumps({'version':1,'scope':'Complete Blender checkpoints; runtime enablement requires matching actual render evidence','forms':rows},ensure_ascii=False,indent=2)+'\n');os.replace(temp,target)
    if cache_changed:
        cache_path.parent.mkdir(parents=True,exist_ok=True);temporary=cache_path.with_suffix('.tmp');temporary.write_text(json.dumps(cache));os.replace(temporary,cache_path)
    print(batch,len(rows),'complete models published for review')

def main(batch):
    assert batch.isidentifier()
    folder=ROOT/'output/creature-remodel/production';folder.mkdir(parents=True,exist_ok=True)
    # A restarting producer and the render watcher share these atomic manifests.
    # Serialize their publication, including metadata caches, within each batch.
    with (folder/('publish-'+batch+'.lock')).open('a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX)
        publish(batch)
        if batch=='r03':
            from low_body_support_metadata import flush
            flush()
        if batch=='r06':
            from coiled_support_metadata import flush
            flush()
if __name__=='__main__':main(sys.argv[1])
