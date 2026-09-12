"""Audit and package actual per-species R03 renders. Enablement is explicit after visual inspection."""
from pathlib import Path
import json,hashlib,sys,math
from PIL import Image,ImageDraw,ImageFont
from package_batch import glb_check,sha
ROOT=Path(__file__).resolve().parents[2];MEDIA=ROOT/'docs/production/media/creature-remodel/r03';OUTPUT=ROOT/'output/creature-remodel/r03'
FONT=ROOT/'우주-비즈니스/assets/fonts/NotoSansKR.ttf'
def audit():
    forms=json.loads((ROOT/'우주-비즈니스/data/creature_remodel_r03.json').read_text())['forms'];rows=[];topologies=set();hashes=set()
    queue=json.loads((ROOT/'docs/production/media/creature-remodel/queue.json').read_text())
    for name,digest in queue['catalog_sha256'].items():assert sha(ROOT/f'우주-비즈니스/data/bestiary/{name}.json')==digest
    for form in forms:
        evidence_file=OUTPUT/(form['id']+'_evidence.json');assert evidence_file.exists(),form['id']
        evidence=json.loads(evidence_file.read_text());assert evidence['renderer']=='forward_plus';r=evidence['species']
        assert r['host_attack']=='none' and r['root_error']<.00001 and r['bone_motion']>.01
        assert r['max_foot_target_error']<.025,(form['id'],r['max_foot_target_error'])
        assert r['limb_phase_checks']==form['morphology']['limb_count']==form['locomotion_chains']
        assert form['normalized_geometry_sha256'] not in hashes,(form['id'],'duplicate geometry');hashes.add(form['normalized_geometry_sha256'])
        graph=form['skeleton_topology']
        def branch(parent):return '('+''.join(sorted(branch(n) for n,p in graph.items() if p==parent))+')'
        topologies.add(branch(None))
        for lod,asset in form['lods'].items():
            assert sha(ROOT/asset['path'])==asset['sha256']==r['asset_sha256'][lod]
            glb_check(ROOT/asset['path'],form)
        for state in ['idle','walk','run','feed','prepare','strike','recover','down','far']:assert (OUTPUT/f"{form['id']}_{state}.png").exists()
        rows.append(r)
    result={'renderer':'forward_plus','reviewed_count':len(rows),'unique_normalized_geometry':len(hashes),'unique_skeleton_parent_graphs':len(topologies),'max_foot_target_error':max(r['max_foot_target_error'] for r in rows),'original_catalog_hashes_unchanged':True,'species':rows}
    (MEDIA/'evidence.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print('R03_AUDIT',len(rows),'geometries;',len(topologies),'skeletal parent graphs; IK',result['max_foot_target_error'])
    return forms,result

def boards(forms):
    font=ImageFont.truetype(str(FONT),13)
    for kind in sorted({r['construction'] for r in forms}):
        group=[r for r in forms if r['construction']==kind]
        for state in ['idle','run','strike']:
            columns=4;width=360;height=288;canvas=Image.new('RGB',(columns*width,math.ceil(len(group)/columns)*height),'#cbd5d0');draw=ImageDraw.Draw(canvas)
            for index,r in enumerate(group):
                x=(index%columns)*width;y=(index//columns)*height
                tile=Image.open(OUTPUT/f"{r['id']}_{state}.png").convert('RGB');tile=tile.resize((width,270),Image.Resampling.LANCZOS);canvas.paste(tile,(x,y))
                draw.text((x+5,y+270),f"{r['id']} · {r['bone_count']} bones",font=font,fill='#203a36')
            canvas.save(MEDIA/f'{kind}-{state}.jpg',quality=94)

def enable(forms):
    config_path=ROOT/'우주-비즈니스/data/creature_remodel_runtime.json';config=json.loads(config_path.read_text());config.setdefault('entry_paths',{})
    for row in forms:
        # No full R03 manifest load during an individual actor's first appearance.
        config['entry_paths'][row['source_id']]=f"res://data/creature_remodel/r03/{row['id']}.json"
        if row['source_id'] not in config['enabled_ground_species']:config['enabled_ground_species'].append(row['source_id'])
        row['status']='game-render-reviewed';path=ROOT/'art/blender/creature_remodel/r03'/(row['id']+'.json');path.write_text(json.dumps(row,ensure_ascii=False,indent=2)+'\n')
    config_path.write_text(json.dumps(config,ensure_ascii=False,indent=2)+'\n')
    path=ROOT/'우주-비즈니스/data/creature_remodel_r03.json';data=json.loads(path.read_text());data['forms']=forms;path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    print('R03_ENABLED',len(forms))
if __name__=='__main__':
    forms,evidence=audit();boards(forms)
    if '--enable-reviewed' in sys.argv:enable(forms)
