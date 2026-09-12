"""Validate the produced R02 assets and package actual INK renders; no fabricated renders."""
from pathlib import Path
from collections import Counter
import json,hashlib,struct,math,sys,subprocess
from PIL import Image,ImageDraw,ImageFont
import imageio_ffmpeg
import numpy as np
from recipes import recipes
from review_digest import sha
ROOT=Path(__file__).resolve().parents[2]
MEDIA=ROOT/'docs/production/media/creature-remodel/r02'
RENDER=ROOT/'output/creature-remodel/r02'
LABELS={'torus_loom':'고리형','pentapalm':'방사형','pendulum_grazer':'현수형','quill_amphora':'압력낭형','hinge_book':'접판형','mirror_fork':'분기형'}
REPRESENTATIVES=['bio_torus_loom_02','bio_pentapalm_07','bio_pendulum_grazer_05','bio_quill_amphora_10','bio_hinge_book_08','bio_mirror_fork_09']
FONT=ROOT/'우주-비즈니스/assets/fonts/NotoSansKR.ttf'
def glb_check(path,expected):
    raw=path.read_bytes();magic,version,size=struct.unpack_from('<III',raw,0);assert magic==0x46546C67 and version==2 and size==len(raw)
    length,kind=struct.unpack_from('<II',raw,12);data=json.loads(raw[20:20+length]);assert kind==0x4E4F534A
    start=20+length;bin_length,bin_kind=struct.unpack_from('<II',raw,start);binary=raw[start+8:start+8+bin_length];assert bin_kind==0x004E4942
    def accessor(index):
        a=data['accessors'][index];view=data['bufferViews'][a['bufferView']];n={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
        code,bytesize={5121:('B',1),5123:('H',2),5125:('I',4),5126:('f',4)}[a['componentType']]
        stride=view.get('byteStride',n*bytesize);offset=view.get('byteOffset',0)+a.get('byteOffset',0)
        dtype={5121:np.dtype('u1'),5123:np.dtype('<u2'),5125:np.dtype('<u4'),5126:np.dtype('<f4')}[a['componentType']]
        return np.ndarray((a['count'],n),dtype=dtype,buffer=binary,offset=offset,strides=(stride,bytesize))
    assert set(a['name'] for a in data['animations'])==set(expected['clips'])
    assert len(data['skins'])==1 and len(data['skins'][0]['joints'])==expected['bone_count']
    count=0;max_weight_error=0
    for mesh in data['meshes']:
        for p in mesh['primitives']:
            attrs=p['attributes'];positions=accessor(attrs['POSITION']);assert np.isfinite(positions).all()
            assert 'WEIGHTS_0' in attrs and 'JOINTS_0' in attrs
            weights=accessor(attrs['WEIGHTS_0']);joints=accessor(attrs['JOINTS_0'])
            assert np.isfinite(weights).all() and (weights>=0).all()
            error=float(np.abs(weights.astype(np.float64).sum(axis=1)-1).max());max_weight_error=max(max_weight_error,error);assert error<.0001
            assert (joints>=0).all() and (joints<expected['bone_count']).all();count+=len(positions)
    for animation in data['animations']:
        assert animation['channels']
        for sampler in animation['samplers']:
            values=accessor(sampler['output']);assert np.isfinite(values).all()
            if animation['name'].endswith('_loop') or animation['name']=='feed':
                # Regression for the feed endpoint: every exported skeletal track closes its loop.
                assert float(np.abs(values[0]-values[-1]).max())<.0001,(path,animation['name'])
    return {'weighted_vertices':count,'max_weight_sum_error':max_weight_error}

def audit():
    forms=json.loads((ROOT/'우주-비즈니스/data/creature_remodel_r02.json').read_text())['forms'];expected={r['id'] for r in recipes()}
    assert len(forms)==56 and {f['id'] for f in forms}==expected
    evidence=json.loads((RENDER/'evidence.json').read_text());review={r['id']:r for r in evidence['species']}
    assert set(review)==expected and evidence['renderer']=='forward_plus'
    queue=json.loads((ROOT/'docs/production/media/creature-remodel/queue.json').read_text())
    for name,digest in queue['catalog_sha256'].items():assert sha(ROOT/f'우주-비즈니스/data/bestiary/{name}.json')==digest
    hashes=set();topologies=set();checks={}
    for f in forms:
        assert f['normalized_geometry_sha256'] not in hashes;hashes.add(f['normalized_geometry_sha256'])
        # Ignore names and bone ordering when counting actual joint connection patterns.
        graph=f['skeleton_topology']
        def branch(parent):return '('+''.join(sorted(branch(n) for n,p in graph.items() if p==parent))+')'
        topologies.add(branch(None))
        assert (ROOT/f['source']).stat().st_size>10000
        assert (MEDIA/'blender'/f"{f['id']}.png").exists()
        r=review[f['id']];assert r['host_attack']=='none' and r['root_error']<.00001 and r['bone_motion']>.01 and r['lods']==2
        assert r['max_foot_target_error']<.025,(f['id'],r['max_foot_target_error'])
        assert r['limb_phase_checks']==f['locomotion_chains']==f['morphology']['limb_count']
        checks[f['id']]={'source_sha256':sha(ROOT/f['source'])}
        for lod,row in f['lods'].items():
            path=ROOT/row['path'];assert sha(path)==row['sha256']==r['asset_sha256'][lod]
            checks[f['id']][lod]=glb_check(path,f)
        for state in ['idle','walk','run','feed','prepare','strike','recover','down','far']:
            assert (RENDER/f"{f['id']}_{state}.png").exists()
    print('R02_ASSETS',len(forms),'unique normalized geometries;',len(topologies),'parent graphs; max IK target error',max(r['max_foot_target_error'] for r in review.values()))
    return forms,{**evidence,'unique_normalized_geometries':len(hashes),'unique_skeleton_parent_graphs':len(topologies),'glb_checks':checks,'catalog_hashes_unchanged':True}

def board(forms,state='idle'):
    columns=5;rows=math.ceil(len(forms)/columns);canvas=Image.new('RGB',(columns*384,rows*302),'#cbd5d0')
    font=ImageFont.truetype(str(FONT),15);draw=ImageDraw.Draw(canvas)
    for i,f in enumerate(forms):
        tile=Image.open(RENDER/f"{f['id']}_{state}.png").convert('RGB').resize((384,288),Image.Resampling.LANCZOS)
        x=(i%columns)*384;y=(i//columns)*302;canvas.paste(tile,(x,y))
        draw.text((x+8,y+282),f"{f['id']} · {f['locomotion_chains']}지지 · {f['bone_count']}본",font=font,fill='#243c36')
    return canvas

def encode_video(forms):
    # Image2 at 30 fps preserves each sampled pose; concat still images use a 25 fps time base.
    staging=RENDER/'video-frames';staging.mkdir(exist_ok=True)
    index=0
    for f in forms:
        for i in range(360):
            link=staging/f'{index:05d}.png'
            if link.is_symlink():link.unlink()
            assert not link.exists()
            link.symlink_to((RENDER/f"{f['id']}_motion_{i:03d}.png").resolve());index+=1
    subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(),'-y','-v','error','-framerate','30','-i',str(staging/'%05d.png'),'-frames:v',str(index),'-c:v','libx264','-crf','19','-pix_fmt','yuv420p','-movflags','+faststart',str(MEDIA/'r02-review.mp4')],check=True)

def package(forms,evidence):
    MEDIA.mkdir(parents=True,exist_ok=True)
    for family in LABELS:
        group=[f for f in forms if f['family']==family]
        board(group).save(MEDIA/(family+'-board.jpg'),quality=94)
        board(group,'strike').save(MEDIA/(family+'-strike.jpg'),quality=94)
    reps=[next(f for f in forms if f['id']==id) for id in REPRESENTATIVES]
    overview=Image.new('RGB',(1440,720),'#cbd5d0')
    for i,f in enumerate(reps):overview.paste(Image.open(RENDER/f"{f['id']}_idle.png").convert('RGB').resize((480,360),Image.Resampling.LANCZOS),((i%3)*480,(i//3)*360))
    overview.save(MEDIA/'r02-board.jpg',quality=95)
    # Full 56-species renders remain reconstructable output; retain compact family review boards.
    frames=[]
    for i in range(0,360,2):
        frame=Image.new('RGB',(1440,720),'#cbd5d0')
        for j,f in enumerate(reps):frame.paste(Image.open(RENDER/f"{f['id']}_motion_{i:03d}.png").convert('RGB').resize((480,360),Image.Resampling.LANCZOS),((j%3)*480,(j//3)*360))
        frames.append(frame)
    frames[0].save(MEDIA/'r02-motion.webp',save_all=True,append_images=frames[1:],duration=67,loop=0,quality=83,method=4)
    encode_video(reps)
    evidence.update(representatives=REPRESENTATIVES,audio='Silent; no new audio generated',scope='56 native actors in a controlled slope render. Authored attack organs posed for review; no host damage activation or campaign playthrough.',video_frames=2160,video_fps=30,video_sha256=sha(MEDIA/'r02-review.mp4'))
    (MEDIA/'evidence.json').write_text(json.dumps(evidence,ensure_ascii=False,indent=2)+'\n')

def enable_reviewed(forms):
    """Explicit final step after inspecting the packaged family boards and motion captures."""
    assert (MEDIA/'evidence.json').exists() and (MEDIA/'r02-review.mp4').exists()
    for f in forms:
        f['status']='game-render-reviewed'
        (ROOT/'art/blender/creature_remodel/r02'/f"{f['id']}.json").write_text(json.dumps(f,ensure_ascii=False,indent=2)+'\n')
    manifest_path=ROOT/'우주-비즈니스/data/creature_remodel_r02.json'
    manifest=json.loads(manifest_path.read_text());manifest['forms']=forms
    manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    runtime_path=ROOT/'우주-비즈니스/data/creature_remodel_runtime.json'
    runtime=json.loads(runtime_path.read_text());runtime['version']=2
    runtime['scope']='Presentation only; reviewed R01/R02 ground species. Host combat, incidents and flight enablement remain separate.'
    source='res://data/creature_remodel_r02.json'
    if source not in runtime['sources']:runtime['sources'].append(source)
    for f in forms:
        if f['source_id'] not in runtime['enabled_ground_species']:runtime['enabled_ground_species'].append(f['source_id'])
    assert len(runtime['enabled_ground_species'])==62
    runtime_path.write_text(json.dumps(runtime,ensure_ascii=False,indent=2)+'\n')
    subprocess.run([sys.executable,str(ROOT/'tools/plan_creature_remodel.py')],check=True)
    path=ROOT/'docs/production/media/creature-remodel/queue.json';queue=json.loads(path.read_text());ids={f['source_id'] for f in forms}
    for row in queue['forms']:
        if row['species_id'] not in ids:continue
        row.update(art_status='render-reviewed',runtime_status='surface-actor-integrated',individual_review='Imported near/far; 240 motion steps; nine Forward+ pose captures; family boards inspected. Full campaign and host attack activation pending.')
    queue['progress'].update(models_built=65,additional_anatomies_rendered=59,ground_locomotion_rendered=64,campaign_replacements=62,r02_built=56,r02_rendered=56,other_animal_ids=5535)
    path.write_text(json.dumps(queue,ensure_ascii=False,indent=2)+'\n')
    print('R02_ENABLED 56 additional species; total 62 surface replacements and 65 built models')

if __name__=='__main__':
    forms,evidence=audit()
    if '--enable-reviewed' in sys.argv:enable_reviewed(forms)
    elif '--audit-only' not in sys.argv:package(forms,evidence)
