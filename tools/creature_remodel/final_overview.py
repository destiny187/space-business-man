"""Package eight actual renderer captures as a compact visual index.

Requires the corresponding existing per-species captures; never fabricates views.
"""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,hashlib
root=Path(__file__).resolve().parents[2];out=root/'output/creature-remodel';media=root/'docs/production/media/creature-remodel';font_path=str(root/'우주-비즈니스/assets/fonts/NotoSansKR.ttf');font=ImageFont.truetype(font_path,19);title_font=ImageFont.truetype(font_path,26)
rows=[('외투막과 낮은 지지 다리','r03','biota_mantle_antennal_fans_13','run'),('분기된 다중 구강','r03','biota_crown_siphons_10','strike'),('열린 나선 몸통','r06','bio_spiral_hinge_07','run'),('사족 포식형의 타격','r04','biota_lobopod_antennal_fans_26','strike'),('관절 전지의 베기','r04','biota_branch_antennal_fans_25','strike'),('현수형 머리와 이동','r02','bio_pendulum_grazer_05','run'),('막과 날개 손가락','r05','biota_bilateral_tendrils_40','0540'),('압력낭과 부유 기관','r05','biota_amphora_antennal_fans_09','0060')]
canvas=Image.new('RGB',(1920,844),'#cbd5d0');draw=ImageDraw.Draw(canvas);draw.text((22,13),'동물 리모델링 · 체형별 실제 게임 화면',font=title_font,fill='#203a36');records=[]
for i,(label,batch,id,state) in enumerate(rows):
 p=out/batch/(id+'_'+state+'.png');assert p.exists(),p
 x=i%4*480;y=60+i//4*392;canvas.paste(Image.open(p).convert('RGB').resize((480,360),Image.Resampling.LANCZOS),(x,y));draw.text((x+12,y+365),label,font=font,fill='#203a36');records.append({'label':label,'batch':batch,'id':id,'state':state,'capture_sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
canvas.save(media/'final-type-overview.jpg',quality=95);(media/'final-type-overview.json').write_text(json.dumps({'renderer':'forward_plus','scope':'Eight illustrative type samples from actual captures; this is not the full catalogue or a rig-count limit.','samples':records},ensure_ascii=False,indent=2)+'\n');print('FINAL_TYPE_OVERVIEW_READY',flush=True)
