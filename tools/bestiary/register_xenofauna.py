"""Register the reviewed extension and make bounded sheets from actual engine renders."""
from pathlib import Path
import json,hashlib
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[2]
DATA=ROOT/'우주-비즈니스/data'
DEST=ROOT/'docs/production/media/xenofauna'
forms=json.loads((DATA/'bestiary/xenofauna_forms.json').read_text())['forms']
font=ImageFont.truetype(str(ROOT/'우주-비즈니스/assets/fonts/NotoSansKR.ttf'),24)
small=ImageFont.truetype(str(ROOT/'우주-비즈니스/assets/fonts/NotoSansKR.ttf'),18)
families={}
for row in forms:families.setdefault(row['family'],[]).append(row)
(DEST/'boards').mkdir(exist_ok=True)
def portrait(row,size):
    im=Image.open(ROOT/'우주-비즈니스/assets/ui/previews'/f"{row['id']}.png").convert('RGBA')
    im=im.crop(im.getbbox());im.thumbnail(size,Image.Resampling.LANCZOS)
    return im
for family,rows in families.items():
    board=Image.new('RGB',(1800,980),'#e5e2d6');d=ImageDraw.Draw(board)
    d.text((28,16),rows[0]['family_name']+' / 서로 다른 기본형 10종',fill='#152631',font=font)
    for i,row in enumerate(rows):
        im=portrait(row,(330,345));x=i%5*360;y=70+i//5*450
        board.paste(im,(x+(360-im.width)//2,y+(345-im.height)//2),im)
        d.text((x+20,y+359),row['name'],fill='#152631',font=font)
        d.text((x+20,y+394),row['environment_label'],fill='#3d5158',font=small)
    board.save(DEST/'boards'/f'{family}.jpg',quality=91)
overview=Image.new('RGB',(1800,2100),'#e5e2d6');d=ImageDraw.Draw(overview)
d.text((24,14),'새 동물 300종 / 30개 신체 구조군 대표',fill='#172833',font=font)
for i,(family,rows) in enumerate(families.items()):
    im=portrait(rows[0],(310,275))
    x=i%5*360;y=70+i//5*330
    overview.paste(im,(x+(360-im.width)//2,y+(275-im.height)//2),im)
    d.text((x+20,y+287),rows[0]['family_name'],fill='#152631',font=font)
overview.save(DEST/'overview.jpg',quality=92)
records=[json.loads((DEST/'render-records'/f"{r['id']}.json").read_text()) for r in forms]
assert all(not r['failures'] for r in records)
assets_path=DATA/'render_assets.json';assets=json.loads(assets_path.read_text());ids={r['id'] for r in forms}
assets=[r for r in assets if r['id'] not in ids]
for row in forms:
    assets.append({'id':row['id'],'title':'XENOFAUNA / '+row['family_name'],'name':row['name'],'group':'발견·환경',
                   'model':'res://'+row['lods']['near']['path'].removeprefix('우주-비즈니스/'),
                   'source':row['source'],'geometry':'authored-xenofauna','foliage':False,
                   'floor_y':row['geometry']['near']['floor_y'],'catalogue':'xenofauna',
                   'review_status':'Godot INK near/far and five states; 30 family sheets; representative Blender source renders'})
assets_path.write_text(json.dumps(assets,ensure_ascii=False,indent=2)+'\n')
verify={'new_species':300,'new_body_plans':30,'blender_sources':len(list((ROOT/'art/blender/xenofauna').glob('*.blend'))),
        'game_glbs':len(list((ROOT/'우주-비즈니스/assets/models/xenofauna').glob('*.glb'))),
        'blender_representatives':len(list((DEST/'blender').glob('*.png'))),'game_renders':len(records),
        'near_triangles':{'min':min(r['lods']['near']['triangles'] for r in forms),'max':max(r['lods']['near']['triangles'] for r in forms),
                          'mean':round(sum(r['lods']['near']['triangles'] for r in forms)/300)},
        'failures':sum(len(r['failures']) for r in records)}
(DEST/'asset-verification.json').write_text(json.dumps(verify,ensure_ascii=False,indent=2)+'\n')
lines=['# 추가 동물 300종 구조 목록','','2026-09-10. 색·크기 프로필을 제외한 별도 Blender/GLB 기본형 300개다. 출현 규칙은 [생태 소관](09-discovery-research-and-ecology.md), 실제 검수는 [제작 기록](../production/122-xenofauna-300.md)을 따른다.','']
for family,rows in families.items():
    lines += ['## '+rows[0]['family_name'],'',rows[0]['anatomy_note'].split(' / ')[0]+'.','',f'![구조 비교](../production/media/xenofauna/boards/{family}.jpg)','','| 기본 종 | 서식 환경 | 구조 차이 | 감각기관 |','| --- | --- | --- | --- |']
    for r in rows:lines.append(f"| {r['name']} | {r['environment_label']} | {r['anatomy_note'].split(' / ')[1]} | {r['sensory_type']} |")
    lines.append('')
(ROOT/'docs/game/24-xenofauna-catalogue.md').write_text('\n'.join(lines)+'\n')
print(json.dumps(verify,ensure_ascii=False))
