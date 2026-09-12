"""Package R01 anatomy and contact renders; update only verified production states."""
from pathlib import Path
import json,hashlib,struct,subprocess,math
from PIL import Image,ImageDraw,ImageFont
import imageio_ffmpeg
ROOT=Path(__file__).resolve().parents[1];RAW=ROOT/'output/creature-remodel/r01';OUT=ROOT/'docs/production/media/creature-remodel/r01';OUT.mkdir(parents=True,exist_ok=True)
catalog=json.loads((ROOT/'우주-비즈니스/data/creature_remodel_r01.json').read_text())
rows=[r for r in catalog['forms'] if r['id'] in ['annulus','pentafold','tethermaw']]
first=json.loads((RAW/'first-two-evidence.json').read_text());last=json.loads((RAW/'render/evidence.json').read_text())
cases=first['cases']+last['cases'];events=first['events']+last['events'];assert len(cases)==9
models={r['id']:r for r in rows}
for case in cases:
    p=models[case['form']]['motion_profile'];damage=p['damage']*len(p['release'])
    assert case['health']==(100-damage if case['case']=='hit' else 100),case
    assert case['shield']==(120-damage if case['case']=='shield' else 0),case
assert len(events)==len(set((e['form'],e['case'],e['stroke']) for e in events))
long_hit=next(e for e in events if e['form']=='tethermaw' and e['case']=='hit')
assert long_hit['time']>=1.04-.025 and long_hit['contact_distance_from_body']>2.7
for row in rows:
    for spec in row['lods'].values():
        b=(ROOT/spec['path']).read_bytes();doc=json.loads(b[20:20+struct.unpack_from('<I',b,12)[0]])
        assert hashlib.sha256(b).hexdigest()==spec['sha256']
        assert len(doc['skins'])==1 and len(doc['animations'])==10
        assert len(doc['skins'][0]['joints'])==row['bone_count']
queue_path=ROOT/'docs/production/media/creature-remodel/queue.json';queue=json.loads(queue_path.read_text())
for name,digest in queue['catalog_sha256'].items():assert hashlib.sha256((ROOT/'우주-비즈니스/data/bestiary'/f'{name}.json').read_bytes()).hexdigest()==digest

font_path=ROOT/'우주-비즈니스/assets/fonts/NotoSansKR.ttf'
def font(n):
    f=ImageFont.truetype(str(font_path),n);f.set_variation_by_name('Medium');return f
def label(im,xy,text,size):ImageDraw.Draw(im).text(xy,text,font=font(size),fill='#24453c')
board=Image.new('RGB',(1920,650),'#f1f3ec');label(board,(24,16),'전체 리모델링 첫 추가 구조 — 고리 · 오방사 · 긴 공격 목',34)
for i,row in enumerate(rows):
    im=Image.open(RAW/'hero'/(row['id']+'.png')).convert('RGB');im=im.crop((0,85,960,600)).resize((640,440),Image.Resampling.LANCZOS)
    board.paste(im,(i*640,76));label(board,(i*640+20,530),row['name'],30)
    label(board,(i*640+20,577),f"전용 본 {row['bone_count']}개 · 동작 10개",22)
board.save(OUT/'r01-board.jpg',quality=95,subsampling=0)
animation=[]
for kind,count in [('move',90),('hit',48),('shield',48),('miss',48)]:
    for index in range(count):
        im=Image.new('RGB',(1440,430),'#f1f3ec');label(im,(20,10),{'move':'걷기 → 빠른 이동 → 감속','hit':'공격 기관의 실제 접촉','shield':'실드 방어','miss':'회피와 빗나간 공격 회수'}[kind],28)
        for i,row in enumerate(rows):
            frame=Image.open(RAW/'render'/row['id']/f'{kind}-{index:03}.png').convert('RGB');frame=frame.crop((0,90,960,600)).resize((480,330),Image.Resampling.LANCZOS)
            im.paste(frame,(i*480,55));label(im,(i*480+16,392),row['name'],22)
        animation.append(im)
animation[0].save(OUT/'r01-motion.webp',save_all=True,append_images=animation[1:],duration=67,loop=0,quality=86,method=4)
ff=imageio_ffmpeg.get_ffmpeg_exe()
subprocess.run([ff,'-hide_banner','-loglevel','error','-y','-i',str(RAW/'review.avi'),'-i',str(RAW/'tethermaw.avi'),'-filter_complex','[0:v][0:a][1:v][1:a]concat=n=2:v=1:a=1[v][a]','-map','[v]','-map','[a]','-c:v','libx264','-preset','fast','-crf','19','-pix_fmt','yuv420p','-c:a','aac','-b:a','160k','-movflags','+faststart',str(OUT/'r01-review.mp4')],check=True)
report={'scope':'Three new anatomy assets rendered in R01 staging; no campaign replacement','renderer':last['renderer'],'device':last['device'],'models':rows,'cases':cases,'events':events,'locomotion':first['locomotion']+last['locomotion'],'all_nine_outcomes_verified':True,'catalogs_unchanged':True,'long_head_contact':long_hit,'audio':'Existing ElevenLabs sources replayed; no new species recording generated','movie_sha256':hashlib.sha256((OUT/'r01-review.mp4').read_bytes()).hexdigest()}
(OUT/'evidence.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
for row in queue['forms']:
    if row['asset_id'] in models:row['art_status']='rendered-r01';row['individual_review']='flat-stage locomotion and contact reviewed; native terrain pending'
queue['progress']={'approved_references':6,'additional_anatomies_rendered':3,'campaign_replacements':0,'other_animal_ids':5591}
queue_path.write_text(json.dumps(queue,ensure_ascii=False,indent=2)+'\n')
print('R01: 3 new anatomies; 9 contact outcomes; native catalogs unchanged; long-head contact distance',round(long_hit['contact_distance_from_body'],3),'m')
