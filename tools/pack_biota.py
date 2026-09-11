"""Publish only a complete, uniformly revised and game-rendered asset catalogue.
--preview emits a separate subset for visual review and never enables new worlds.
"""
from pathlib import Path
import json,colorsys,sys,hashlib,os
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/bestiary'))
from biota_roster import recipes,COLLECTION
from biota_review_state import motion_matches
REV='biota-ink-4'
def pack(preview=False):
    forms=[];looks=[];reviewed=0
    actor_hash=hashlib.sha256((ROOT/'우주-비즈니스/scripts/actors/creatures/bestiary_actor.gd').read_bytes()).hexdigest()
    style_hash=hashlib.sha256((ROOT/'우주-비즈니스/data/render_style.json').read_bytes()).hexdigest()
    for spec in recipes():
        path=ROOT/'art/blender/biota'/(spec['id']+'.json')
        if not path.exists():continue
        try:row=json.loads(path.read_text())
        except json.JSONDecodeError:continue # Another worker may still be writing its checkpoint.
        if row.get('art_revision')!=REV or row.get('recipe_revision')!=spec.get('recipe_revision'):continue
        row['family_name']=spec['family_name']
        if spec.get('replacement'):row['body_plan']=spec['body_plan']
        if any(not (ROOT/row['lods'][lod]['path']).exists() for lod in ['near','far']):continue
        # The legacy exporter counts a differently named eye mesh. These values
        # follow the actual eye and sensory-pit constructors of this collection.
        row['eye_count']=spec['eye_count'] if spec.get('replacement') else (2 if row['category']=='animal' and row['construction'] in ['spindle','lobopod','avian'] else 0)
        row['photosensory_pit_count']=row['body_plan']['radial_count'] if row['category']=='animal' and row['organ_system']=='antennal_fans' else 0
        record_path=ROOT/'docs/production/media/biota/render-records'/(row['id']+'.json')
        try:record=json.loads(record_path.read_text()) if record_path.exists() else {}
        except json.JSONDecodeError:record={}
        if row.get('replacement') or row.get('recipe_revision')=='bract-stem-1':
            if record.get('imported_model_sha256')!={lod:row['lods'][lod]['sha256'] for lod in ['near','far']}:record={}
        if record.get('model_sha256')==row['lods']['near']['sha256'] and motion_matches(record,row) and record.get('style_sha256')==style_hash and record.get('failures')==[] and record.get('states')==5 and record.get('lods')==2 and (ROOT/'우주-비즈니스/assets/ui/previews'/(row['id']+'.png')).exists():
            row['render_status']='game-render-and-motion-checked';row['rig']['validation']='weighted-motion-and-two-lods-checked';reviewed+=1
        forms.append(row)
        for palette in range(5):
            colors=[]
            for color in row['palette']:
                h,s,v=colorsys.rgb_to_hsv(*(int(color[i:i+2],16)/255 for i in [0,2,4]));rgb=colorsys.hsv_to_rgb((h+(palette-2)*.016)%1,min(.92,s*(.90+palette*.05)),min(.88,v*(.90+palette*.04)))
                colors.append(''.join('%02x'%round(channel*255) for channel in rgb))
            for size in range(4):looks.append({'id':row['id']+f'_p{palette:02d}_s{size:02d}','form_id':row['id'],'environment':row['environment'],'palette_index':palette,'size_index':size,'palette':colors,'scale':round(.88+size*.08,3),'type':'appearance-variant','spawn_enabled':False})
    if (len(forms)==7000 and reviewed==7000) or preview:
        suffix='_preview' if preview else ''
        destination=ROOT/'우주-비즈니스/data/bestiary'
        for filename,data in [('forms',{'version':1,'collection':COLLECTION,'form_count':len(forms),'structural_groups':140,'forms':forms}),('appearances',{'version':1,'count':len(looks),'appearances':looks})]:
            path=destination/('biota'+suffix+'_'+filename+'.json');tmp=path.with_suffix('.json.%d.tmp'%os.getpid());tmp.write_text(json.dumps(data,ensure_ascii=False,separators=(',',':'))+'\n');tmp.replace(path)
    print('BIOTA_CATALOGUE',len(forms),'/7000',flush=True)
    print('BIOTA_GAME_REVIEW',reviewed,'/7000',flush=True)
    return forms
if __name__=='__main__':pack('--preview' in sys.argv)
