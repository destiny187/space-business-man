"""Register verified plant/microbe assets and compose sheets from actual Godot portraits."""
from pathlib import Path
import json,collections
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[2];DATA=ROOT/'우주-비즈니스/data';DEST=ROOT/'docs/production/media/xenoflora'
forms=json.loads((DATA/'bestiary/xenoflora_forms.json').read_text())['forms'];assert len(forms)==100
font=ImageFont.truetype(str(ROOT/'우주-비즈니스/assets/fonts/NotoSansKR.ttf'),25)
small=ImageFont.truetype(str(ROOT/'우주-비즈니스/assets/fonts/NotoSansKR.ttf'),18)
families={}
for r in forms:families.setdefault(r['family'],[]).append(r)
def portrait(row,size):
    im=Image.open(ROOT/'우주-비즈니스/assets/ui/previews'/f"{row['id']}.png").convert('RGBA')
    assert im.getextrema()[-1]==(0,255)
    im=im.crop(im.getbbox());im.thumbnail(size,Image.Resampling.LANCZOS);return im
def place(board,row,x,y,size=(320,300)):
    im=portrait(row,size);board.paste(im,(x+(360-im.width)//2,y+(size[1]-im.height)//2),im)
(DEST/'boards').mkdir(exist_ok=True)
for family,rows in families.items():
    board=Image.new('RGB',(1800,490),'#e4e6dc');d=ImageDraw.Draw(board)
    d.text((24,15),rows[0]['family_name']+' / '+('식물' if rows[0]['category']=='plant' else '미생물 군락')+' 기본형 5종',fill='#183b35',font=font)
    for i,row in enumerate(rows):
        x=i*360;place(board,row,x,67)
        d.text((x+20,389),row['name'],fill='#183b35',font=font);d.text((x+20,430),row['environment_label'],fill='#506358',font=small)
    board.save(DEST/'boards'/f'{family}.jpg',quality=94)
board=Image.new('RGB',(1800,1510),'#e4e6dc');d=ImageDraw.Draw(board)
d.text((24,15),'특이 식물 60종 · 미생물 군락 40종 / 20개 구조군 대표',fill='#183b35',font=font)
for i,rows in enumerate(families.values()):
    x=i%5*360;y=75+i//5*350;place(board,rows[0],x,y,(320,275))
    d.text((x+15,y+287),rows[0]['family_name'],fill='#183b35',font=font)
    d.text((x+15,y+320),'식물' if rows[0]['category']=='plant' else '미생물 군락',fill='#506358',font=small)
board.save(DEST/'overview.jpg',quality=95)
for page in range(4):
    board=Image.new('RGB',(1500,1375),'#e4e6dc');d=ImageDraw.Draw(board)
    for i,row in enumerate(forms[page*25:page*25+25]):
        im=portrait(row,(285,225));x=i%5*300;y=i//5*275
        board.paste(im,(x+(300-im.width)//2,y+(225-im.height)//2),im)
        d.text((x+12,y+235),row['name'],fill='#183b35',font=small)
    board.save(DEST/f'all-review-{page+1}.jpg',quality=94)
records=[json.loads((DEST/'render-records'/f"{r['id']}.json").read_text()) for r in forms]
assert all(not rec['failures'] and rec['model_sha256']==r['lods']['near']['sha256'] for r,rec in zip(forms,records))
assets_path=DATA/'render_assets.json';assets=json.loads(assets_path.read_text());ids={r['id'] for r in forms};assets=[r for r in assets if r['id'] not in ids]
for r in forms:
    assets.append({'id':r['id'],'title':'XENOFLORA / '+r['family_name'],'name':r['name'],'group':'발견·환경',
        'model':'res://'+r['lods']['near']['path'].removeprefix('우주-비즈니스/'),'source':r['source'],
        'geometry':'authored-xenoflora','foliage':r['category']=='plant','floor_y':r['geometry']['near']['floor_y'],
        'catalogue':'xenoflora','review_status':'Godot INK near/far and five states; 20 family sheets; Blender source representatives'})
assets_path.write_text(json.dumps(assets,ensure_ascii=False,indent=2)+'\n')
verify={'new_species':100,'new_categories':dict(collections.Counter(r['category'] for r in forms)),'structure_groups':20,
    'blender_sources':len(list((ROOT/'art/blender/xenoflora').glob('*.blend'))),'game_glbs':len(list((ROOT/'우주-비즈니스/assets/models/xenoflora').glob('*.glb'))),
    'blender_source_renders':len(list((DEST/'blender').glob('*.png'))),'game_renders':len(records),
    'near_triangles':{'min':min(r['lods']['near']['triangles'] for r in forms),'max':max(r['lods']['near']['triangles'] for r in forms),'mean':round(sum(r['lods']['near']['triangles'] for r in forms)/100)},'failures':0}
(DEST/'asset-verification.json').write_text(json.dumps(verify,ensure_ascii=False,indent=2)+'\n')
lines=['# 추가 식물·미생물 100종 구조 목록','','2026-09-10. 식물 60개·미생물 군락 40개의 별도 기본 모델이다. 전체 생물 기본형은 동물 700 + 식물 185 + 미생물 115 = 1,000개다. 색·크기 외형 프로필은 기본종에 중복 계산하지 않는다. 미생물 모델은 눈에 보이는 군락이며 단일 세포를 사람 크기로 확대한 것이 아니다.','','[등장 확률과 생태 소관](09-discovery-research-and-ecology.md) · [제작과 실제 확인](../production/123-xenoflora-100.md)','']
for family,rows in families.items():
    lines+=['## '+rows[0]['family_name']+' — '+('식물' if rows[0]['category']=='plant' else '미생물 군락'),'',rows[0]['anatomy_note'].split(' / ')[0]+'.','',f'![기본형 5개 비교](../production/media/xenoflora/boards/{family}.jpg)','','| 기본형 | 서식 환경 | 구조 레시피 |','| --- | --- | --- |']
    for r in rows:lines.append('| '+r['name']+' | '+r['environment_label']+' | '+r['anatomy_note'].split(' / ')[1]+' |')
    lines.append('')
(ROOT/'docs/game/25-xenoflora-catalogue.md').write_text('\n'.join(lines)+'\n')
print(json.dumps(verify,ensure_ascii=False))
