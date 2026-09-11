"""Contact sheet of actual enlarged faces, rejecting superseded captures."""
import json,sys
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
from biota_review_state import motion_matches
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/bestiary'))
from biota_roster import recipes
BASE=ROOT/'docs/production/media/biota'
PROTOTYPES={'biota_spindle_armor_25','biota_spindle_armor_26','biota_lobopod_armor_26','biota_radial_armor_26','biota_flat_armor_25','biota_chain_armor_26','biota_bilateral_armor_26','biota_crown_armor_25','biota_crown_armor_26','biota_amphora_armor_25','biota_branch_armor_25','biota_branch_armor_26'}
LABELS={'cervid':'사슴형 · 가로 동공','proboscid':'거수형 · 작은 안와','canid':'개과형 · 둥근 홍채','felid':'고양이형 · 세로 동공','chelonian':'거북형 · 비늘 눈두덩','crocodilian':'악어형 · 등쪽 눈','giraffoid':'장경형 · 긴 눈매','camelid':'낙타형 · 두꺼운 눈꺼풀','rhinocerid':'중갑형 · 깊은 안와','bovid':'들소형 · 가로 동공','anuran':'개구리형 · 넓은 홍채','monotreme':'오리너구리형 · 작은 눈','pangolin':'천산갑형 · 보호 안와','armadillo':'절갑형 · 깊은 안와','gekkonid':'도마뱀붙이형 · 세로 동공','skink':'유선형 · 작은 세로 동공','macropod':'도약형 · 가로 동공','lagomorph':'토끼형 · 측면 눈','mustelid':'족제비형 · 작은 홍채','serpent':'뱀형 · 비늘 눈두덩','wader':'섭금류형 · 측면 눈','owl':'올빼미형 · 전방 원반 눈','arachnid':'거미형 · 여섯 홑눈','scorpion':'전갈형 · 등쪽 홑눈','crab':'게형 · 자루 겹눈','hermit':'소라게형 · 자루 겹눈','mantid':'사마귀형 · 넓은 겹눈','beetle':'딱정벌레형 · 측면 겹눈'}

def main():
    source='--source' in sys.argv;area='blender' if source else 'game'
    rows=[r for r in recipes() if r.get('replacement') and r['organ_system']=='armor' and ('--prototypes' not in sys.argv or r['id'] in PROTOTYPES)]
    forms={r['id']:r for r in json.loads((ROOT/'우주-비즈니스/data/bestiary/biota_preview_forms.json').read_text())['forms']}
    font=ImageFont.truetype('/System/Library/Fonts/AppleSDGothicNeo.ttc',21)
    prefix='faces-'+area+('-prototypes' if '--prototypes' in sys.argv else '')
    out=BASE/'midpoints';out.mkdir(exist_ok=True);index=[]
    for start in range(0,len(rows),12):
        batch=rows[start:start+12];board=Image.new('RGB',(1600,((len(batch)+3)//4)*370),'#12232b');draw=ImageDraw.Draw(board)
        for i,row in enumerate(batch):
            picture_path=BASE/('faces-'+area)/(row['id']+'.png')
            metadata=ROOT/'art/blender/biota'/(row['id']+'.json');made=json.loads(metadata.read_text()) if metadata.exists() else {}
            current=picture_path.exists() and made.get('recipe_revision')==row['recipe_revision']
            if source:current=bool(current and picture_path.stat().st_mtime_ns>=(ROOT/made['source']).stat().st_mtime_ns)
            else:
                p=BASE/'render-records'/(row['id']+'.json');record=json.loads(p.read_text()) if p.exists() else {};form=forms.get(row['id'],{})
                current=bool(current and form and record.get('model_sha256')==form['lods']['near']['sha256'] and not record.get('failures') and motion_matches(record,form))
            x=(i%4)*400;y=(i//4)*370
            if current:
                picture=Image.open(picture_path).convert('RGB');picture.thumbnail((396,330));board.paste(picture,(x+(400-picture.width)//2,y))
            else:draw.text((x+12,y+150),'Awaiting current face',font=font,fill='#d2aa72')
            draw.text((x+10,y+337),LABELS[row['anatomical_type']],font=font,fill='#c4eeec')
            index.append({'id':row['id'],'page':start//12+1,'current':current,'model_sha256':made.get('lods',{}).get('near',{}).get('sha256')})
        board.save(out/(prefix+'-%02d.jpg'%(start//12+1)),quality=95)
    (out/(prefix+'-index.json')).write_text(json.dumps(index,indent=2)+'\n')
    print(prefix,'current',sum(i['current'] for i in index),'of',len(rows))

if __name__=='__main__':main()
