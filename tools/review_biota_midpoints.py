"""Review actual replacement captures; keep before/after images separate."""
from pathlib import Path
import json,sys
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'docs/production/media/biota'
sys.path.insert(0,str(ROOT/'tools/bestiary'))
from biota_roster import recipes
from biota_review_state import motion_matches

def main():
    source='--source' in sys.argv
    representative='--representatives' in sys.argv
    area='blender' if source else 'game'
    selected=[r for r in recipes() if r.get('replacement') and (not representative or r['organ_system']=='armor')]
    forms={r['id']:r for r in json.loads((ROOT/'우주-비즈니스/data/bestiary/biota_preview_forms.json').read_text())['forms']}
    out=BASE/'midpoints';out.mkdir(exist_ok=True)
    font=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',15)
    index=[];prefix=area+('-representatives' if representative else '')
    for start in range(0,len(selected),12):
        batch=selected[start:start+12];board=Image.new('RGB',(1440,((len(batch)+3)//4)*330),'#12232b');draw=ImageDraw.Draw(board)
        for i,row in enumerate(batch):
            path=BASE/area/(row['id']+'.png');x=(i%4)*360;y=(i//4)*330
            metadata=ROOT/'art/blender/biota'/(row['id']+'.json')
            made=json.loads(metadata.read_text()) if metadata.exists() else {}
            current=made.get('recipe_revision')==row.get('recipe_revision')
            if source:
                current=bool(current and path.exists() and path.stat().st_mtime_ns>=(ROOT/made['source']).stat().st_mtime_ns)
            if not source:
                record_path=BASE/'render-records'/(row['id']+'.json')
                record=json.loads(record_path.read_text()) if record_path.exists() else {}
                form=forms.get(row['id'],{})
                expected=made.get('lods',{}).get('near',{}).get('sha256')
                current=bool(current and form and record.get('model_sha256')==expected and record.get('imported_model_sha256',{}).get('near')==expected and not record.get('failures') and motion_matches(record,form))
            if path.exists() and current:
                picture=Image.open(path).convert('RGB');picture.thumbnail((358,298));board.paste(picture,(x+(360-picture.width)//2,y))
            else:draw.text((x+15,y+130),'Awaiting current model',font=font,fill='#d2aa72')
            draw.text((x+9,y+299),row['anatomical_type']+' / '+row['organ_system'],font=font,fill='#c4eeec')
            draw.text((x+9,y+315),row['id'].removeprefix('biota_'),font=font,fill='#c4eeec')
            index.append({'id':row['id'],'page':start//12+1,'current':current,'near_sha256':made.get('lods',{}).get('near',{}).get('sha256')})
        board.save(out/(prefix+'-%02d.jpg'%(start//12+1)),quality=93)
    (out/(prefix+'-index.json')).write_text(json.dumps(index,indent=2)+'\n')
    print('MIDPOINT_BOARDS',area,len(selected),'forms',len({i['page'] for i in index}),'pages')

if __name__=='__main__':main()
