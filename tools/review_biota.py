"""Assemble current Blender/Godot representative boards for human anatomy review."""
import hashlib,json,sys
from pathlib import Path
from collections import defaultdict
from PIL import Image,ImageDraw,ImageFont
from biota_review_state import motion_matches
ROOT=Path(__file__).resolve().parents[1]
def main():
    source='game' if '--game' in sys.argv else 'blender';base=ROOT/'docs/production/media/biota';groups=defaultdict(dict)
    motion_hash=hashlib.sha256((ROOT/'우주-비즈니스/scripts/actors/creatures/bestiary_actor.gd').read_bytes()).hexdigest()
    catalogue=ROOT/'우주-비즈니스/data/bestiary'/('biota_preview_forms.json' if '--preview' in sys.argv else 'biota_forms.json')
    for row in json.loads(catalogue.read_text())['forms']:
        if row['anatomy'] not in [0,8,24,49]:continue
        path=base/source/(row['id']+'.png')
        if not path.exists():continue
        if source=='blender' and path.stat().st_mtime_ns<(ROOT/row['source']).stat().st_mtime_ns:continue
        if source=='game':
            record=base/'render-records'/(row['id']+'.json')
            if not record.exists():continue
            data=json.loads(record.read_text())
            if data['model_sha256']!=row['lods']['near']['sha256'] or not motion_matches(data,row) or data.get('failures'):continue
        groups[row['family']][row['anatomy']]=(row,path)
    out=base/'review';out.mkdir(exist_ok=True)
    recipes=json.loads((ROOT/'우주-비즈니스/data/bestiary/biota_recipes.json').read_text())['species']
    families=sorted({row['family'] for row in recipes});font=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',14)
    index=[]
    for start in range(0,len(families),4):
        selected=families[start:start+4];board=Image.new('RGB',(1280,len(selected)*285+42),'#12232b');draw=ImageDraw.Draw(board)
        draw.text((14,12),f'BIOTA / {source.upper()} / type and anatomy review {start//4+1}',font=font,fill='#c4eeec')
        for y,family in enumerate(selected):
            index.append({'family':family,'page':start//4+1,'anatomies':sorted(groups[family])})
            for x,anatomy in enumerate([0,8,24,49]):
                px=x*320;py=y*285+42
                if anatomy not in groups[family]:draw.text((px+12,py+130),'Awaiting current model/render',font=font,fill='#738f9a');continue
                row,path=groups[family][anatomy];im=Image.open(path).convert('RGB');im.thumbnail((316,242));board.paste(im,(px+(320-im.width)//2,py))
                draw.text((px+8,py+242),row['id'].replace('biota_',''),font=font,fill='#d1e8ed')
                draw.text((px+8,py+262),row['adaptation_id']+' / '+str(row['rig']['bone_count'])+' bones',font=font,fill='#8aa9b0')
        path=out/f'{source}-groups-{start//4+1:02d}.jpg';board.save(path,quality=91)
    (out/(source+'-index.json')).write_text(json.dumps(index,ensure_ascii=False,indent=2)+'\n')
    print(source,sum(bool(g) for g in groups.values()),'groups',sum(len(g) for g in groups.values()),'representatives',str(out))
if __name__=='__main__':main()
