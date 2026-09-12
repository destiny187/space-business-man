"""Arrange actual Blender/Godot captures; never synthesizes creature imagery."""
from pathlib import Path
import json, shutil, struct, hashlib, sys
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[1]
INPUT=ROOT/'output/creature-studies/godot'
OUT=ROOT/'docs/production/media/creature-studies'
OUT.mkdir(parents=True,exist_ok=True)
FONT=ROOT/'우주-비즈니스/assets/fonts/NotoSansKR.ttf'
def font(size):
    result=ImageFont.truetype(str(FONT),size)
    try: result.set_variation_by_name('Medium')
    except ValueError: pass
    return result
INK='#203a36'; WHITE='#f2f4ef'; MUTED='#567168'
rows=json.loads((ROOT/'우주-비즈니스/data/creature_studies.json').read_text())['forms']
roles=['사족 보행 · 목을 낮춘 돌진','여섯발 보행 · 낮은 돌입과 교차 베기','삼족 지지 · 압력 충전과 곡사 포격','두발 도약 · 압축과 착지 충격','전신 파동 · 삼갈래 구강 분사','막날개 활공 · 조준과 골침 발사']

def text(draw,at,value,size=26,fill=INK): draw.text(at,value,font=font(size),fill=fill)
def header(image,title,subtitle):
    d=ImageDraw.Draw(image);text(d,(38,22),title,44);text(d,(40,83),subtitle,23,MUTED)

board=Image.new('RGB',(2400,1660),WHITE)
header(board,'새로운 행성의 동물 — 유형별 대표 6종','특이한 조형을 살리고 지지·감각·섭식·공격 기관을 연결한 시안  /  Godot Forward+ · INK v1')
details=Image.new('RGB',(2400,1590),WHITE)
header(details,'얼굴과 발사 기관','안와·홑눈·감각공·압력 밸브·삼갈래 구강  /  실제 모델 근접 렌더')
for i,row in enumerate(rows):
    x=(i%3)*800;y=140+(i//3)*755
    hero=Image.open(INPUT/(row['id']+'-hero.png')).convert('RGB');hero.resize((800,625),Image.Resampling.LANCZOS)
    board.paste(hero.resize((800,625),Image.Resampling.LANCZOS),(x,y))
    d=ImageDraw.Draw(board);text(d,(x+26,y+635),f'{i+1:02d}  {row["name"]}',30);text(d,(x+26,y+681),roles[i],23,MUTED)
    detail=Image.open(INPUT/(row['id']+'-detail.png')).convert('RGB')
    dy=140+(i//3)*720;details.paste(detail.resize((800,625),Image.Resampling.LANCZOS),(x,dy));text(ImageDraw.Draw(details),(x+26,dy+637),row['name'],28)
    for suffix in ['hero','detail']:shutil.copy2(INPUT/(row['id']+'-'+suffix+'.png'),OUT/(row['id']+'-'+suffix+'.png'))
board.save(OUT/'type-board.jpg',quality=94,subsampling=0);details.save(OUT/'detail-board.jpg',quality=93,subsampling=0)

for mode,indices,titles in [('attack',[94,99,103,109],['준비','충전 / 힘 모으기','방출 / 타격','회복']),('movement',[22,27,32,37],['보행 0.16초','보행 0.56초','보행 0.96초','보행 1.36초'])]:
    sheet=Image.new('RGB',(2560,3520),WHITE);header(sheet,'공격 동작과 투사체' if mode=='attack' else '몸통·관절·날개의 이동 동작','각 행은 같은 모델의 연속 시점  /  유형별 대표 시안 · 현장 피해 판정은 미연결')
    for i,row in enumerate(rows):
        y=145+i*555
        for k,frame in enumerate(indices):
            sheet.paste(Image.open(INPUT/row['id']/f'{frame:03}.png').convert('RGB'),(k*640,y))
            text(ImageDraw.Draw(sheet),(k*640+18,y+501),f'{row["name"]} · {titles[k]}' if k==0 else titles[k],23)
    sheet.save(OUT/(mode+'-sequence.jpg'),quality=93,subsampling=0)

combined=[]
for frame in range(120):
    canvas=Image.new('RGB',(1920,1220),WHITE);d=ImageDraw.Draw(canvas)
    time=frame*.08;phase='호흡 / 감각 반응' if time<1.6 else ('이동' if time<4.8 else ('섭식 / 구강 반응' if time<7.2 else '공격 준비 → 방출 → 회복'))
    text(d,(28,12),'유형별 동작 시안',32);text(d,(900,18),phase,27,MUTED)
    for i,row in enumerate(rows):
        x=(i%3)*640;y=70+(i//3)*565
        canvas.paste(Image.open(INPUT/row['id']/f'{frame:03}.png').convert('RGB'),(x,y))
        text(d,(x+18,y+502),row['name'],25)
    d.rectangle((28,1200,28+int(1864*frame/119),1205),fill='#548c76')
    combined.append(canvas)
combined[0].save(OUT/'type-motion.webp',save_all=True,append_images=combined[1:],duration=80,loop=0,quality=83,method=4)
for i,row in enumerate(rows):
    if len(sys.argv)>1 and row['id'] not in sys.argv[1:]: continue
    sequence=[]
    for frame in range(120):
        c=Image.new('RGB',(640,552),WHITE);c.paste(Image.open(INPUT/row['id']/f'{frame:03}.png').convert('RGB'),(0,0));text(ImageDraw.Draw(c),(16,509),row['name'],24);sequence.append(c)
    sequence[0].save(OUT/(row['id']+'-motion.webp'),save_all=True,append_images=sequence[1:],duration=80,loop=0,quality=87,method=4)

evidence=json.loads((INPUT/'evidence.json').read_text())
for row in rows:
    row['glb_check']={}
    for lod,spec in row['lods'].items():
        b=(ROOT/spec['path']).read_bytes();size=struct.unpack_from('<I',b,12)[0];doc=json.loads(b[20:20+size]);sha=hashlib.sha256(b).hexdigest()
        assert sha==spec['sha256']
        clips=[a['name'] for a in doc.get('animations',[])];assert set(clips)=={'idle_loop','move_loop','feed','attack'}
        assert len(doc.get('skins',[]))==1
        row['glb_check'][lod]={'sha256':sha,'animations':clips,'skins':1,'meshes':len(doc['meshes'])}
(OUT/'evidence.json').write_text(json.dumps({'scope':'six isolated representative studies; no campaign replacement','gpu':evidence,'frames_per_type':120,'fps':12.5,'audio':'silent visual study; species-specific audio not generated','models':rows},ensure_ascii=False,indent=2)+'\n')
print('COMPOSED',len(rows),'studies; verified near/far hashes, skins and clips')
