"""Assemble unchanged Blender/Godot review captures into comparison sheets (Pillow)."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
root=Path(__file__).resolve().parents[1];folder=root/'docs/production/media/planet-surfaces-v2'
font=ImageFont.truetype(str(root/'우주-비즈니스/assets/fonts/NotoSansKR.ttf'),23)
small=ImageFont.truetype(str(root/'우주-비즈니스/assets/fonts/NotoSansKR.ttf'),19)
def board(name,rows,cols,width=640,height=400):
 canvas=Image.new('RGB',(cols*width,len(rows)*(height+43)),(20,29,34));d=ImageDraw.Draw(canvas)
 for y,row in enumerate(rows):
  for x,(file,label) in enumerate(row):
   frame=Image.open(folder/file).convert('RGB').resize((width,height),Image.Resampling.LANCZOS)
   canvas.paste(frame,(x*width,y*(height+43)+43));d.text((x*width+16,y*(height+43)+8),label,font=font if width>=600 else small,fill=(226,233,234))
 canvas.save(folder/name)
families=[('sedimentary','퇴적 분지'),('crystalline','결정질 고원'),('alkaline','알칼리 광화대')]
rows=[[(f'orbit/seeded-{k}.png',n+' · 궤도') for k,n in families],[(f'close-{k}.png',n+' · 실제 지표') for k,n in families]]
board('new-families-board.png',rows,3)
board('material-comparison.png',[[('before-oxidized.png','산화 사막 · 기존 셰이더'),('ground-oxidized.png','산화 사막 · 공유 텍스처 적용')],[('close-tundra.png','툰드라 · 본래 한랭 상태'),('tundra-thawed.png','툰드라 · 현장 온도 18°C')]],2)
ids=['oxidized','continental','cratered','fractured','tundra','frozen','volcanic','salt','ochre','sedimentary','crystalline','alkaline']
board('landable-coverage.png',[ [('ground-'+id+'.png',id) for id in ids[i:i+4]] for i in range(0,12,4)],4,400,250)
