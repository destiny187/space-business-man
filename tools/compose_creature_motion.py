"""Package real contact-lab captures and verify the recorded outcomes and audio."""
from pathlib import Path
import json,math,hashlib,struct,subprocess,wave,sys
import numpy as np
from PIL import Image,ImageDraw,ImageFont
import imageio_ffmpeg

ROOT=Path(__file__).resolve().parents[1];RAW=ROOT/'output/creature-motion';CAP=RAW/'render';OUT=ROOT/'docs/production/media/creature-motion'
SPEED='--speed' in sys.argv
if SPEED:CAP=RAW/'speed-render';OUT=ROOT/'docs/production/media/creature-speed'
OUT.mkdir(parents=True,exist_ok=True)
movie_stem='speed-review' if SPEED else 'contact-review'
log_name='speed-final.log' if SPEED else 'movie-final.log'
rows=json.loads((ROOT/'우주-비즈니스/data/creature_motion_studies.json').read_text())['forms']
evidence=json.loads((CAP/'evidence.json').read_text());profiles={r['id']:r['motion_profile'] for r in rows}
assert len(evidence['cases'])==18
for case in evidence['cases']:
    p=profiles[case['form']];damage=p['damage']*len(p['release'])
    assert case['health']==(100-damage if case['case']=='hit' else 100),case
    assert case['shield']==(120-damage if case['case']=='shield' else 0),case
keys=[(e['form'],e['case'],e['stroke']) for e in evidence['events']];assert len(keys)==len(set(keys))
records=[]
for row in rows:
    for lod,spec in row['lods'].items():
        b=(ROOT/spec['path']).read_bytes();d=json.loads(b[20:20+struct.unpack_from('<I',b,12)[0]])
        assert hashlib.sha256(b).hexdigest()==spec['sha256']
        assert len(d['skins'])==1 and set(a['name'] for a in d['animations'])==set(row['clips'])
    records.append({'id':row['id'],'source':row['source'],'approved_mesh_digest':row['approved_mesh_digest'],'bones':row['bone_count'],'clips':row['clips'],'lods':row['lods']})
def animation_hashes(path):
    blob=path.read_bytes();size=struct.unpack_from('<I',blob,12)[0];doc=json.loads(blob[20:20+size]);binary=blob[28+size:]
    def raw(index):
        accessor=doc['accessors'][index];view=doc['bufferViews'][accessor['bufferView']]
        width={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[accessor['type']]*{5126:4,5123:2,5125:4}[accessor['componentType']]
        start=view.get('byteOffset',0)+accessor.get('byteOffset',0);stride=view.get('byteStride',width)
        return b''.join(binary[start+i*stride:start+i*stride+width] for i in range(accessor['count']))
    result={}
    for action in doc['animations']:
        chunks=[]
        for channel in action['channels']:
            sampler=action['samplers'][channel['sampler']];target=channel['target']
            key=doc['nodes'][target['node']]['name']+'/'+target['path']
            chunks.append((key,raw(sampler['input'])+raw(sampler['output'])))
        digest=hashlib.sha256()
        for key,data in sorted(chunks):digest.update(key.encode());digest.update(data)
        result[action['name']]=digest.hexdigest()
    return result
if SPEED:
    original_actions={};current_actions={}
    for row in rows:
        old=animation_hashes(RAW/'before-speed/models'/(row['id']+'_near.glb'))
        new=animation_hashes(ROOT/row['lods']['near']['path'])
        assert all(new.get(name)==digest for name,digest in old.items()),'Approved clip changed: '+row['id']
        assert set(new)-set(old)=={'run_loop'}
        original_actions[row['id']]=old;current_actions[row['id']]=new
    evidence['approved_actions_unchanged']=True;evidence['animation_hashes']=current_actions
    assert len(evidence['locomotion'])==6
    assert evidence['yellow_impact_rings'] is False

baseline=json.loads((ROOT/'docs/production/media/creature-studies/evidence.json').read_text())
for row in baseline['models']:
    for spec in row['lods'].values():assert hashlib.sha256((ROOT/spec['path']).read_bytes()).hexdigest()==spec['sha256'],'Approved V1 GLB was modified'
evidence['models']=records;evidence['approved_v1_glbs_unchanged']=True;evidence['all_18_outcomes_verified']=True;evidence['duplicate_damage_events']=0

FF=imageio_ffmpeg.get_ffmpeg_exe()
def run(args):subprocess.run([FF,'-hide_banner','-loglevel','error','-y',*map(str,args)],check=True)
assert 'Done recording movie' in (RAW/log_name).read_text()
run(['-i',RAW/(movie_stem+'.avi'),'-c:v','libx264','-preset','fast','-crf','19','-pix_fmt','yuv420p','-c:a','aac','-b:a','160k','-movflags','+faststart',OUT/'contact-review.mp4'])
audio=ROOT/('audio/review/creature-motion/speed-runtime.wav' if SPEED else 'audio/review/creature-motion/contact-runtime.wav');audio.parent.mkdir(parents=True,exist_ok=True)
run(['-i',RAW/(movie_stem+'.avi'),'-vn','-ac','1','-ar','48000','-c:a','pcm_s16le',audio])
with wave.open(str(audio)) as f:
    samples=np.frombuffer(f.readframes(f.getnframes()),dtype='<i2').astype(np.float64)/32768;duration=len(samples)/f.getframerate()
peak=float(np.abs(samples).max());rms=float(np.sqrt((samples*samples).mean()));assert peak>.001
evidence['audio']={'recording':str(audio.relative_to(ROOT)),'duration':duration,'peak_dbfs':20*math.log10(peak),'rms_dbfs':20*math.log10(rms),'nonzero_samples':int(np.count_nonzero(samples)),'clipped_samples':int(np.sum(np.abs(samples)>=.9999)),'listening':'Runtime recording and nonzero signal verified; subjective listening pending'}
evidence['movie']={'file':str((OUT/'contact-review.mp4').relative_to(ROOT)),'sha256':hashlib.sha256((OUT/'contact-review.mp4').read_bytes()).hexdigest(),'fps':30,'scope':'full six-type contact-lab render, no campaign claims'}

FONT=ROOT/'우주-비즈니스/assets/fonts/NotoSansKR.ttf'
def font(size):
    f=ImageFont.truetype(str(FONT),size);f.set_variation_by_name('Medium');return f
def label(image,xy,t,size=25):ImageDraw.Draw(image).text(xy,t,font=font(size),fill='#25453a')
def frame(row,kind,index,size):
    im=Image.open(CAP/row['id']/f'{kind}-{index:03}.png').convert('RGB');return im.crop((0,90,960,600)).resize(size,Image.Resampling.LANCZOS)
board=Image.new('RGB',(2160,1040),'#f1f3ec');label(board,(28,18),('빠른 이동과 타격 — 노란 원형 효과 제거' if SPEED else '생물별 이동·타격 — 승인 외형을 유지한 대표 검토'),38)
label(board,(30,75),('보폭·발 교대와 이동 속도 연결  /  승인 외형·공격 유지' if SPEED else '골격과 공격 기관은 체형별로 다르게  /  실제 접촉 · 실드 방어 · 회피'),23)
for i,row in enumerate(rows):
    e=next(e for e in evidence['events'] if e['form']==row['id'] and e['case']=='hit');index=min(47,math.ceil(e['time']*15))
    x=i%3*720;y=124+i//3*450;board.paste(frame(row,'hit',index,(720,383)),(x,y));label(board,(x+20,y+393),row['name'],27)
board.save(OUT/'impact-board.jpg',quality=95,subsampling=0)
animation=[]
for kind,count in [('move',90 if SPEED else 30),('hit',48),('shield',48),('miss',48)]:
    for index in range(count):
        im=Image.new('RGB',(1440,650),'#f1f3ec');label(im,(22,10),{'move':('걷기 → 가속 → 빠른 이동 → 감속' if SPEED else '이동 → 감속과 발 디딤'),'hit':'명중 → 접촉·피격·회복','shield':'실드 → 방어 반응','miss':'회피 → 빗나간 공격과 회복'}[kind],28)
        for i,row in enumerate(rows):
            x=i%3*480;y=58+i//3*290;im.paste(frame(row,kind,index,(480,255)),(x,y))
            name=row['name']
            if SPEED and kind=='move':
                gait=row['motion_profile'];fast=gait['run']['stride']/gait['run']['stance']/gait['run']['period'];name+=f'  최대 {fast:.2f} m/s'
            label(im,(x+14,y+259),name,18 if SPEED and kind=='move' else 20)
        animation.append(im)
animation[0].save(OUT/'contact-motion.webp',save_all=True,append_images=animation[1:],duration=67,loop=0,quality=85,method=4)
(OUT/'evidence.json').write_text(json.dumps(evidence,ensure_ascii=False,indent=2)+'\n')
manifest=ROOT/'audio/manifests/creature-motion-reuse.json';data=json.loads(manifest.read_text());data['runtime_signal']=evidence['audio'];data['runtime_plays']=evidence['audio_plays'];manifest.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
print('PACKAGED: 18 correct outcomes; approved meshes retained; 12 skinned GLBs with '+str(len(rows[0]['clips']))+' clips; audio peak',round(evidence['audio']['peak_dbfs'],2),'dBFS')
