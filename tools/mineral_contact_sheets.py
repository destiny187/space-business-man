"""Compose actual Blender / Godot captures; requires Pillow. No artwork is synthesized."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json
ROOT=Path(__file__).resolve().parents[1]
rows=json.loads((ROOT/'art/blender/minerals/manifest.json').read_text())
folder=ROOT/'docs/production/media/minerals'
font=ImageFont.truetype(str(ROOT/'우주-비즈니스/assets/fonts/NotoSansKR.ttf'),23)
for source in ['blender','godot']:
 board=Image.new('RGB',(1600,1160),'#152434');draw=ImageDraw.Draw(board)
 for i,row in enumerate(rows):
  im=Image.open(folder/source/(row['id']+'.png'))
  # Godot source includes its own title; retain it in individual captures, use footer on board.
  if source=='godot':im=im.crop((170,100,830,610))
  im.thumbnail((320,250),Image.Resampling.LANCZOS)
  x=i%5*320;y=i//5*290;board.paste(im,(x+(320-im.width)//2,y+(250-im.height)//2));draw.text((x+16,y+252),row['name'],font=font,fill='white')
 board.save(folder/(source+'-board.png'))

# Paired A/B silhouettes, one row per material (two columns of material pairs).
for source in ['blender','godot']:
 board=Image.new('RGB',(1440,2400),'#152434');draw=ImageDraw.Draw(board)
 for i,row in enumerate(rows):
  x=(i%2)*720;y=(i//2)*240
  for j,suffix in enumerate(['','_b']):
   im=Image.open(folder/source/(row['id']+suffix+'.png'))
   if source=='godot':im=im.crop((170,100,830,610))
   im.thumbnail((340,205),Image.Resampling.LANCZOS)
   board.paste(im,(x+j*350+(340-im.width)//2,y+(205-im.height)//2))
  draw.text((x+15,y+208),row['name']+'    A / B',font=font,fill='white')
 board.save(folder/(source+'-variants-board.png'))
