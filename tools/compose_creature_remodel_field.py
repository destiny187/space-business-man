"""Package actual campaign actor rendering and update only verified rollout states."""
from pathlib import Path
import json,hashlib,subprocess
from PIL import Image
import imageio_ffmpeg
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'output/creature-remodel/field'; MEDIA=ROOT/'docs/production/media/creature-remodel/field'
MEDIA.mkdir(parents=True,exist_ok=True)

def main():
    first_path=OUT/'first-eight-evidence.json'
    first=json.loads((first_path if first_path.exists() else OUT/'evidence.json').read_text())
    current=json.loads((OUT/'evidence.json').read_text())
    rows={r['id']:r for r in first['species']}
    rows.update({r['id']:r for r in current['species']})
    assert len(rows)==8
    runtime=json.loads((ROOT/'우주-비즈니스/data/creature_remodel_runtime.json').read_text())
    enabled=set(runtime['enabled_ground_species'])
    forms=json.loads((ROOT/'우주-비즈니스/data/creature_remodel_r01.json').read_text())['forms']
    forms=[f for f in forms if f['source_id'] in enabled]
    assert len(forms)==6
    native={f['id']:f for name in ['forms','xenofauna_forms','xenoflora_forms','biota_forms'] for f in json.loads((ROOT/f'우주-비즈니스/data/bestiary/{name}.json').read_text())['forms']}
    combat=json.loads((ROOT/'우주-비즈니스/data/wildlife_combat.json').read_text())
    for form in forms:
        original=native[form['source_id']]
        attack=combat['anatomical_attacks'].get(original.get('construction',''),original['attack'])
        assert attack=='none', (form['id'],attack)
        for lod in form['lods'].values():assert hashlib.sha256((ROOT/lod['path']).read_bytes()).hexdigest()==lod['sha256']
    for row in rows.values():
        assert row['root_error']<.00001 and row['pause_held'] and row['mouth_follows_live_skeleton']
        assert row['max_foot_target_error']<.02
        assert {'move_loop','run_loop','stop','turn_right','feed'} <= set(row['phases'])
        assert row['bone_motion']>.01 and row['lods']==2
    queue_path=ROOT/'docs/production/media/creature-remodel/queue.json'
    queue=json.loads(queue_path.read_text())
    for name,digest in queue['catalog_sha256'].items():
        assert hashlib.sha256((ROOT/f'우주-비즈니스/data/bestiary/{name}.json').read_bytes()).hexdigest()==digest
    frames=[]
    for i in range(150):
        canvas=Image.new('RGB',(1440,600),'#ced7d0')
        for j,f in enumerate(forms):
            image=Image.open(OUT/f"{f['id']}_{i:03d}.png").convert('RGB').resize((480,300),Image.Resampling.LANCZOS)
            canvas.paste(image,((j%3)*480,(j//3)*300))
        frames.append(canvas)
    frames[45].save(MEDIA/'field-board.jpg',quality=95)
    frames[0].save(MEDIA/'field-motion.webp',save_all=True,append_images=frames[1:],duration=67,loop=0,quality=82,method=4)
    listing=OUT/'field-video.txt'
    paths=[OUT/f"{f['id']}_{i:03d}.png" for f in forms for i in range(150)]
    listing.write_text(''.join("file '"+str(p).replace("'","'\\''")+"'\nduration 0.066666667\n" for p in paths)+"file '"+str(paths[-1])+"'\n")
    subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(),'-y','-v','error','-f','concat','-safe','0','-i',str(listing),'-r','30','-c:v','libx264','-crf','19','-pix_fmt','yuv420p','-movflags','+faststart',str(MEDIA/'field-review.mp4')],check=True)
    evidence={**first,'species':list(rows.values()),'campaign_species':sorted(enabled),'campaign_count':6,
              'pending_host_attack_adaptation':runtime['pending_host_attack_adaptation'],
              'native_incidents':'Original matching models retained for saved incident dimensions and attack timelines',
              'scope':'Actual imported campaign actors on controlled GPU-rendered terrain; full campaign session and multiplayer not exercised',
              'audio':'Video is silent. Existing campaign footfall cue return is preserved; no new audio generated.',
              'catalog_hashes_unchanged':True,'source_mesh_hashes_unchanged':True,
              'video_sha256':hashlib.sha256((MEDIA/'field-review.mp4').read_bytes()).hexdigest()}
    (MEDIA/'evidence.json').write_text(json.dumps(evidence,ensure_ascii=False,indent=2)+'\n')
    for row in queue['forms']:
        if row['species_id'] in enabled:
            row['runtime_status']='surface-actor-integrated';row['individual_review']='Imported near/far rigs, real-speed gait, slope IK, pause, turn, variant, feed, live mouth socket; full campaign session pending'
        elif row['species_id'] in runtime['pending_host_attack_adaptation']:
            row['runtime_status']='pending-host-attack-adaptation';row['individual_review']='Authored field locomotion reviewed; campaign charge/leap animation adaptation pending'
    queue['progress'].update(campaign_replacements=6,ground_locomotion_rendered=8)
    queue_path.write_text(json.dumps(queue,ensure_ascii=False,indent=2)+'\n')
    print('FIELD_PACKAGE',len(rows),'locomotion reviews;',len(forms),'surface replacements; max planted-foot error',max(r['max_foot_target_error'] for r in rows.values()))
if __name__=='__main__':main()
