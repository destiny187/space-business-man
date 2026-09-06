"""Assemble native Godot renders; no painted/generated replacement artwork."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont,ImageStat
import json,hashlib,collections,sys,math
from functools import lru_cache
ROOT=Path(__file__).resolve().parents[2]
DEST=ROOT/'docs/production/media/bestiary'
forms=json.loads((ROOT/'우주-비즈니스/data/bestiary/forms.json').read_text())['forms']
looks=json.loads((ROOT/'우주-비즈니스/data/bestiary/appearances.json').read_text())['appearances']
fontpath=str(ROOT/'우주-비즈니스/assets/fonts/NotoSansKR.ttf')
@lru_cache(maxsize=16)
def font(size):
 f=ImageFont.truetype(fontpath,size)
 try:f.set_variation_by_axes([600])
 except Exception:pass
 return f
aberrant_only="--aberrant" in sys.argv
if aberrant_only:
 forms=[r for r in forms if r.get("collection")=="aberrant"]
 ids={r["id"] for r in forms}
 looks=[r for r in looks if r["form_id"] in ids]
families=collections.defaultdict(list)
for row in forms:families[row['family']].append(row)
(DEST/'boards').mkdir(parents=True,exist_ok=True)
partial='--partial' in sys.argv
family_thumbs=[]
for family,rows in families.items():
 ready=[r for r in rows if (DEST/'models'/f"{r['id']}.png").exists()]
 if not ready:continue
 board=Image.new('RGB',(1800,130+math.ceil(len(ready)/5)*330),'#efeee2');d=ImageDraw.Draw(board)
 d.text((35,23),f"{rows[0]['family_name']}  /  {len(ready)} BASE FORMS",font=font(36),fill='#233b40')
 for i,row in enumerate(ready):
  im=Image.open(DEST/'models'/f"{row['id']}.png").convert('RGB')
  # Crop away studio headings/footer, retaining all 3D pixels in the specimen area.
  im=im.crop((0,220,1440,1090));im.thumbnail((354,260),Image.Resampling.LANCZOS)
  x=(i%5)*360;y=95+(i//5)*330
  board.paste(im,(x+(360-im.width)//2,y))
  d.text((x+12,y+265),row['id'].removeprefix('bio_'),font=font(15),fill='#233b40')
  d.text((x+12,y+290),row['name'],font=font(14),fill='#4c655c')
 board.save(DEST/'boards'/f'{family}.jpg',quality=92)
 # Native hero per family for the overview, exact generated render.
 hero=Image.open(DEST/'models'/f"{ready[0]['id']}.png").convert('RGB').crop((0,200,1440,1120))
 hero.thumbnail((470,350),Image.Resampling.LANCZOS)
 family_thumbs.append((family,rows[0]['family_name'],hero))
overview=Image.new('RGB',(2000,180+math.ceil(len(family_thumbs)/4)*395),'#efeee2');d=ImageDraw.Draw(overview)
d.text((42,20),'LOCUS / 생물 아트 라이브러리',font=font(43),fill='#233b40')
d.text((44,84),f'{len(families)}개 구조군 · 기본 형상 {len(forms)}개 · 외형 프로필 {len(looks):,}개',font=font(24),fill='#4c655c')
for i,(family,label,im) in enumerate(family_thumbs):
 x=(i%4)*500;y=150+(i//4)*395
 overview.paste(im,(x+(500-im.width)//2,y))
 d.text((x+24,y+346),label,font=font(22),fill='#233b40')
overview.save(DEST/('aberrant-overview.jpg' if aberrant_only else 'overview.jpg'),quality=94)
if partial:
 print('PARTIAL_BOARDS',len(family_thumbs));raise SystemExit()
for row in forms:
 target=DEST/'boards'/f"{row['id']}-appearances.jpg"
 form_looks=[x for x in looks if x['form_id']==row['id']]
 if target.exists() and all((DEST/'variants'/f"{x['id']}.png").stat().st_mtime<=target.stat().st_mtime for x in form_looks):continue
 board=Image.new('RGB',(1200,880),'#efeee2');d=ImageDraw.Draw(board)
 d.text((18,10),row['name']+' / 20 appearances',font=font(22),fill='#233b40')
 for i,look in enumerate([x for x in looks if x['form_id']==row['id']]):
  path=DEST/'variants'/f"{look['id']}.png";im=Image.open(path).convert('RGB')
  board.paste(im,((i%5)*240,55+(i//5)*205))
 board.save(DEST/'boards'/f"{row['id']}-appearances.jpg",quality=87)
images=[];per_form=collections.defaultdict(set)
for look in looks:
 path=DEST/'variants'/f"{look['id']}.png"
 with Image.open(path) as im:
  im.load();assert im.size==(240,200),path
  assert max(ImageStat.Stat(im.convert('RGB')).stddev)>5,path
  per_form[look['form_id']].add(hashlib.sha256(im.tobytes()).hexdigest())
 images.append(path)
native=0;lighting=0;lod=0
for row in forms:
 for folder,suffix,size in [('models','',(1440,1200)),('lighting','-shade',(480,400)),('lighting','-backlight',(480,400)),('lod','',(480,400))]:
  path=DEST/folder/f"{row['id']}{suffix}.png"
  with Image.open(path) as im:im.load();assert im.size==size,path
  if folder=='models':native+=1
  elif folder=='lod':lod+=1
  else:lighting+=1
duplicates={k:len(v) for k,v in per_form.items() if len(v)!=20}
report={'native_models':native,'lighting_views':lighting,'lod_views':lod,'appearance_images':len(images),'base_contact_sheets':len(families),'appearance_contact_sheets':len(forms),'forms_with_repeated_appearance_pixels':duplicates,'status':'pass' if not duplicates else 'failed','note':'Native Godot images; contact sheets are resizes/assemblies. Automated file/pixel checks do not substitute for visual review.'}
(DEST/('aberrant-render-verification.json' if aberrant_only else 'render-verification.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(report,ensure_ascii=False))
assert not duplicates
