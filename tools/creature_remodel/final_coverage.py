"""Final coverage receipt for the completed animal pass; does not enable or import assets."""
from collections import Counter
from pathlib import Path
import json,subprocess
from review_digest import sha
from import_completed import digest,destinations,save_digests

ROOT=Path(__file__).resolve().parents[2]
GAME=ROOT/'우주-비즈니스'
MEDIA=ROOT/'docs/production/media/creature-remodel'
COUNTS={'r01':9,'r02':56,'r03':4333,'r04':178,'r05':384,'r06':640}

def main():
    baseline=json.loads(subprocess.check_output(['git','show','HEAD:docs/production/media/creature-remodel/queue.json'],cwd=ROOT))
    catalog=[]
    for name,value in baseline['catalog_sha256'].items():
        path=GAME/f'data/bestiary/{name}.json';assert sha(path)==value,('catalog changed',name)
        catalog.extend(json.loads(path.read_text())['forms'])
    animals={r['id'] for r in catalog if r['category']=='animal'}
    assert len(catalog)==8000 and len(animals)==5600
    config=json.loads((GAME/'data/creature_remodel_runtime.json').read_text())
    ground=set(config['enabled_ground_species']);air=set(config['enabled_air_species'])
    assert not ground.intersection(air) and ground|air==animals
    assert not config.get('pending_host_attack_adaptation',[])
    initial={r['id']:r for r in json.loads((MEDIA/'integration/r01-normalized-geometry.json').read_text())}
    geometries={};graphs=set();covered=set();batch_results={};all_forms={}
    for batch,count in COUNTS.items():
        forms=json.loads((GAME/f'data/creature_remodel_{batch}.json').read_text())['forms']
        assert len(forms)==count,(batch,len(forms))
        evidence=json.loads((MEDIA/batch/'evidence.json').read_text())
        records={r['id']:r for r in evidence.get('species',[])}
        for f in forms:
            assert f['source_id'] not in covered;covered.add(f['source_id']);all_forms[f['source_id']]=f
            anatomy=initial[f['id']] if batch=='r01' else f
            key=anatomy['normalized_geometry_sha256'];assert key not in geometries,(f['id'],geometries.get(key));geometries[key]=f['id']
            graph=anatomy['skeleton_topology'];children={}
            for name,parent in graph.items():children.setdefault(parent,[]).append(name)
            def branch(parent):return '('+''.join(sorted(branch(n) for n in children.get(parent,[])))+')'
            graphs.add(branch(None))
            assert (ROOT/f['source']).stat().st_size>10000
            if batch=='r01':assert sha(ROOT/f['source'])==anatomy['source_sha256']
            else:
                r=records[f['id']]
                assert r['asset_sha256']=={k:v['sha256'] for k,v in f['lods'].items()}
                assert r.get('contact_metadata_version',0)==f.get('contact_metadata_version',0)
                assert r.get('body_support_version',0)==f.get('body_support_version',0)
                assert batch=='r05' or r.get('authored_pose_capture_version',0)>=2
                if batch!='r02':assert sha(ROOT/f['source'])==r['source_sha256']
        batch_results[batch]={'species':count,'matching_review_records':len(records) if batch!='r01' else len(initial)}
    assert covered==animals and set(config['entry_paths'])=={f['source_id'] for b in ['r03','r04','r05','r06'] for f in json.loads((GAME/f'data/creature_remodel_{b}.json').read_text())['forms']}
    # Resolve overlays in the same order as the runtime; initial combat/flight
    # adaptations replace the earlier approved reference GLBs for those species.
    runtime={}
    for source in config['sources']:
        for f in json.loads((GAME/source.removeprefix('res://')).read_text())['forms']:
            if f['source_id'] in animals:runtime[f['source_id']]=f
    for id,path in config['entry_paths'].items():
        f=json.loads((GAME/path.removeprefix('res://')).read_text());assert f['source_id']==id
        for field in ['lods','motion_profile','sockets']:assert f[field]==all_forms[id][field],(id,field)
        runtime[id]=f
    assert set(runtime)==animals
    assets=[]
    for id,f in runtime.items():
        assert set(f['lods'])=={'near','far'}
        for lod,a in f['lods'].items():
            source=ROOT/a['path'];assert digest(source)==a['sha256']
            sidecar=source.with_suffix('.glb.import');assert sidecar.is_file()
            dest=destinations(sidecar.read_text());assert dest and all((GAME/p).is_file() for p in dest)
            md5=GAME/(dest[0].rsplit('.',1)[0]+'.md5')
            assert md5.is_file() and 'source_md5="'+digest(source,'md5')+'"' in md5.read_text(),(id,lod,'stale import')
            assets.append({'source_id':id,'lod':lod,'sha256':a['sha256'],'path':a['path']})
    assert len(assets)==11200
    save_digests()
    result={'scope':'Completed animal remodeling and installed presentation assets. Existing gameplay statistics, origin catalogues and save IDs retained. Controlled render/host/incident/flight checks are not a whole-campaign playthrough.',
            'animal_species':5600,'categories':dict(Counter(f['category'] for f in catalog)),'enabled_ground_species':len(ground),'enabled_air_species':len(air),'installed_lods':len(assets),
            'unique_normalized_geometry_hashes':len(geometries),'unique_skeleton_parent_graphs':len(graphs),'bone_count_range':[min(f['bone_count'] for f in runtime.values()),max(f['bone_count'] for f in runtime.values())],
            'catalog_sha256':baseline['catalog_sha256'],'batches':batch_results,'assets':assets}
    (MEDIA/'integration/final-coverage.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print('CREATURE_ROLLOUT_COMPLETE',5600,'species',len(assets),'installed LODs',len(graphs),'parent graphs',flush=True)
if __name__=='__main__':main()
