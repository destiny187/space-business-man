"""Package matching renderer evidence; never count a missing or stale capture as reviewed."""
from pathlib import Path
import json,sys,math
from PIL import Image,ImageDraw,ImageFont
from package_batch import glb_check,sha
ROOT=Path(__file__).resolve().parents[2]
STATES=['idle','walk','run','feed','prepare','strike','recover','down','far']

def audit(batch):
    media=ROOT/'docs/production/media/creature-remodel'/batch
    output=ROOT/'output/creature-remodel'/batch
    manifest=json.loads((ROOT/f'우주-비즈니스/data/creature_remodel_{batch}.json').read_text())
    queue=json.loads((ROOT/'docs/production/media/creature-remodel/queue.json').read_text())
    for name,digest in queue['catalog_sha256'].items():assert sha(ROOT/f'우주-비즈니스/data/bestiary/{name}.json')==digest
    previous=media/'evidence.json';verified=json.loads(previous.read_text()).get('species',[]) if previous.exists() else []
    verified={r['id']:r for r in verified};forms=[];records=[];geometries=set();topologies=set()
    for f in manifest['forms']:
        path=output/(f['id']+'_evidence.json')
        if not path.exists():continue
        e=json.loads(path.read_text());r=e.get('species',e)
        assert r['id']==f['id'] and e['renderer']=='forward_plus',f['id']
        hashes={lod:l['sha256'] for lod,l in f['lods'].items()}
        if r['asset_sha256']!=hashes:continue
        if batch!='r05' and r.get('authored_pose_capture_version',0)<2:continue
        if r.get('contact_metadata_version',0)!=f.get('contact_metadata_version',0):continue
        if r.get('body_support_version',0)!=f.get('body_support_version',0):continue
        if f.get('body_support_version'):assert r.get('max_body_contact_error',1)<.01,f['id']
        assert r['root_error']<.00001 and r.get('max_foot_target_error',r.get('max_ground_foot_error',1))<.025,f['id']
        if batch!='r05':
            assert r['bone_motion']>.01 and r['limb_phase_checks']==f['locomotion_chains']
            if batch=='r03':assert r['host_attack']=='none' and r['limb_phase_checks']==f['morphology']['limb_count']
            for state in STATES:assert (output/f"{f['id']}_{state}.png").exists()
        else:
            assert r['actual_seeded_flight_path']==f['air_motion']
            if f['air_motion']:assert len(r['phases'])==4 and r['dormant_and_introduced_remain_grounded']
        assert (ROOT/f['source']).stat().st_size>10000 and (media/'blender'/(f['id']+'.png')).exists()
        assert f['normalized_geometry_sha256'] not in geometries,f['id'];geometries.add(f['normalized_geometry_sha256'])
        graph=f['skeleton_topology'];children={}
        for name,parent in graph.items():children.setdefault(parent,[]).append(name)
        def branch(parent):return '('+''.join(sorted(branch(n) for n in children.get(parent,[])))+')'
        topologies.add(branch(None))
        checks={}
        for lod,asset in f['lods'].items():
            assert sha(ROOT/asset['path'])==asset['sha256']
            old=verified.get(f['id'],{})
            checks[lod]=old['glb_checks'][lod] if old.get('asset_sha256')==hashes and old.get('all_loops_checked') else glb_check(ROOT/asset['path'],f)
        forms.append(f);records.append({**r,'glb_checks':checks,'all_loops_checked':True,'source_sha256':sha(ROOT/f['source'])})
    assert forms,'No matching complete renderer evidence'
    result={'renderer':'forward_plus','reviewed_count':len(forms),'unique_normalized_geometry':len(geometries),'unique_skeleton_parent_graphs':len(topologies),'original_catalog_hashes_unchanged':True,'species':records}
    media.mkdir(parents=True,exist_ok=True);(media/'evidence.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(batch,'AUDIT',len(forms),'geometry',len(geometries),'parent graphs',len(topologies),flush=True)
    return forms,result

def boards(batch,forms,prefix='',states=None,refresh_ids=None):
    media=ROOT/'docs/production/media/creature-remodel'/batch;output=ROOT/'output/creature-remodel'/batch
    font=ImageFont.truetype(str(ROOT/'우주-비즈니스/assets/fonts/NotoSansKR.ttf'),13)
    # Nine clearly legible species per page, rather than an unbounded miniature sheet.
    for page in range(math.ceil(len(forms)/9)):
        if refresh_ids is not None and not any(r['id'] in refresh_ids for r in forms[page*9:page*9+9]):continue
        for state in (states or (['0000','0540'] if batch=='r05' else ['idle','run','strike'])):
            canvas=Image.new('RGB',(1080,864),'#cbd5d0');draw=ImageDraw.Draw(canvas)
            for i,r in enumerate(forms[page*9:page*9+9]):
                path=output/f"{r['id']}_{state}.png"
                if not path.exists() and batch=='r05':path=output/f"{r['id']}_0060.png"
                tile=Image.open(path).convert('RGB').resize((360,270),Image.Resampling.LANCZOS);x=i%3*360;y=i//3*288;canvas.paste(tile,(x,y));draw.text((x+4,y+272),r.get('anatomical_type',r['construction'])+' '+r['id'],font=font,fill='#203a36')
            canvas.save(media/f'{prefix}{state}-{page:03}.jpg',quality=94)

def enable(batch,forms):
    path=ROOT/'우주-비즈니스/data/creature_remodel_runtime.json';config=json.loads(path.read_text())
    for f in forms:
        config.setdefault('entry_paths',{})[f['source_id']]=f"res://data/creature_remodel/{batch}/{f['id']}.json"
        key='enabled_air_species' if batch=='r05' else 'enabled_ground_species'
        if f['source_id'] not in config.setdefault(key,[]):config[key].append(f['source_id'])
    path.write_text(json.dumps(config,ensure_ascii=False,indent=2)+'\n');print(batch,'ENABLED',len(forms),flush=True)

if __name__=='__main__':
    batch=sys.argv[1];assert batch in ['r03','r04','r05','r06']
    forms,evidence=audit(batch)
    if '--boards' in sys.argv:boards(batch,forms)
    if '--enable-reviewed' in sys.argv:enable(batch,forms)
