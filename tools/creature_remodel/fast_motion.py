"""Blender-authored, anatomy-sized fast gait libraries on the existing editable rigs.

Original meshes/actions are read only. Each .blend library contains the original
armature and new actions; append its actions into the recorded model source to edit.
The compact gzip .motion export carries local bone deltas, never mesh replacements.
"""
import gzip
import hashlib
import json
import math
import sys
import time
from pathlib import Path

import bpy
from mathutils import Matrix, Vector as V

ROOT = Path(__file__).resolve().parents[2]
sys.path[:0] = [str(ROOT / 'tools'), str(Path(__file__).parent)]
from build_creature_studies import smooth
from build_batch import AnatomicalStudy
from animation_capture import PoseCapture

SRC = ROOT / 'art/blender/creature_fast_motion'
OUT = ROOT / '우주-비즈니스/assets/animations/creatures'
META = ROOT / '우주-비즈니스/data/creature_fast_motion'
REVIEW = ROOT / 'output/creature-fast-motion/blender'
VERSION = 1
QUADRUPEDS = {'quadruped','canid','felid','cervid','bovid','rhinocerid','giraffoid','camelid','mustelid','grazer'}
HOPPERS = {'hopper','macropod','anuran','lagomorph'}
HEAVY = {'tripod','pressure','amphora','tower','lithic','tripod_bell','walking_calyx','quill_amphora','gyre_tower'}


def catalogue():
    forms = {}
    for name in ['forms','xenofauna_forms','xenoflora_forms','biota_forms']:
        for row in json.loads((ROOT / f'우주-비즈니스/data/bestiary/{name}.json').read_text())['forms']:
            if row['category'] == 'animal':
                forms[row['id']] = row
    result = {}
    for batch in ['r01','r02','r03','r04','r05','r06','combat','flight']:
        for row in json.loads((ROOT / f'우주-비즈니스/data/creature_remodel_{batch}.json').read_text())['forms']:
            row = dict(row)
            row['medium'] = forms[row['source_id']].get('locomotion_medium', row.get('locomotion_medium', 'ground'))
            result[row['source_id']] = row
    assert len(result) == 5600 and set(result) == set(forms)
    return result


def rig_from_source(row):
    bpy.ops.wm.open_mainfile(filepath=str(ROOT / row['source']))
    s = AnatomicalStudy.__new__(AnatomicalStudy)
    s.spec = row
    s.arm = bpy.data.objects['StudySkeleton']
    s.bones, s.binds, s.legs = {}, {}, []
    s.arm.animation_data_clear()
    for b in s.arm.data.bones:
        s.bones[b.name] = dict(a=b.head_local.copy(), b=b.tail_local.copy(), parent=b.parent.name if b.parent else None)
        s.binds[b.name] = b.matrix_local.copy()
    for name, bone in s.bones.items():
        if not name.endswith('_upper'):
            continue
        key = name[:-6]
        if key + '_lower' not in s.bones or key + '_foot' not in s.bones:
            continue
        lower, foot = s.bones[key + '_lower'], s.bones[key + '_foot']
        direction = foot['b'] - foot['a']
        direction.z = 0
        if direction.length < .001:
            direction = V((0,-1,0))
        s.legs.append(dict(name=key, hip=bone['a'], knee=bone['b'], foot=foot['a'], parent=bone['parent'],
                           upper=(bone['b']-bone['a']).length, lower=(lower['b']-lower['a']).length, forward=direction.normalized()))
    return s


def profile(s):
    row = s.spec
    n, kind, medium = len(s.legs), row.get('anatomical_type',row['kind']), row['medium']
    length = min((l['upper']+l['lower'] for l in s.legs), default=1.)
    bounds = row['lods']['near']
    body = max(.3, bounds['max'][2]-bounds['min'][2])
    phases = {}
    if medium in ['surface_air','air']:
        mode = 'flight'
    elif medium in ['water','atmosphere']:
        mode = 'swim' if medium == 'water' else 'float'
    elif kind in HOPPERS:
        mode = 'hop'
    elif n == 4 and kind in QUADRUPEDS:
        mode = 'gallop'
    elif n == 2:
        mode = 'biped'
    elif n == 3 or kind in HEAVY:
        mode = 'heavy'
    elif n:
        mode = 'multi'
    else:
        mode = 'wave'
    stance = {'gallop':.38,'hop':.42,'biped':.44,'multi':.55,'heavy':.66}.get(mode,.65)
    period = {'gallop':.52,'hop':.62,'biped':.48,'multi':.48,'heavy':.65,'wave':.60,'flight':.50,'swim':.65,'float':.90}[mode]
    stride = min(length * (.66 if mode in ['gallop','hop','biped'] else .55), body * .55) if n else body * .48
    stride = max(.12, stride)
    # Large forward extension must remain within each actual leg, not merely the average.
    if n:
        available = min(math.sqrt(max(.01,(l['upper']+l['lower'])**2-(l['hip'].z-l['foot'].z-length*.09)**2)) for l in s.legs)
        stride = min(stride, available * 1.15)
    prior = row['motion_profile']['run']
    prior_speed = prior['stride']/prior['stance']/prior['period']
    if mode in ['multi','biped','gallop']:
        period = max(.36,min(period,stride/stance/(prior_speed*1.25)))
    if mode == 'flight':
        cfg = row.get('flight',{})
        period = max(.20,min(.75,1./(cfg.get('flap_hz',1.5)*1.2)))
        cruise = cfg.get('patrol_radius',4.5)*math.tau/max(1.,cfg.get('cycle_seconds',48)-cfg.get('rest_seconds',12)-2*cfg.get('transition_seconds',5))
        stride = cruise*1.7*stance*period
    front_y = sum(l['foot'].y for l in s.legs)/max(1,n)
    ordered = sorted(s.legs, key=lambda l:(l['foot'].y,l['foot'].x))
    for i,l in enumerate(ordered):
        if mode == 'gallop':
            phase = (.05 if l['foot'].y < front_y else .55) + (0 if l['foot'].x < 0 else .12)
        elif mode == 'hop':
            phase = 0.
        elif mode == 'biped':
            phase = 0 if l['foot'].x < 0 else .5
        elif n == 3:
            phase = i/3
        elif mode == 'heavy':
            phase = i/max(1,n)
        else:
            side = [v for v in ordered if (v['foot'].x<0)==(l['foot'].x<0)]
            phase = ((0 if l['foot'].x<0 else .5)+side.index(l)*(.18 if n>8 else .5))%1
        phases[l['name']] = phase
    return dict(mode=mode, medium=medium, stride=stride, stance=stance, period=period,
                limb_phases=phases, lift=min(.25,length*.18), crouch=length*.07 if n else 0.,
                body_bob=min(.11,length*.07), natural_speed=stride/stance/period,
                max_playback=1.18, acceleration=max(.9,stride/stance/period*1.8), turn_rate=3.4 if mode in ['heavy','float'] else 5.,
                bone_count=len(s.bones))


def shape_pose(s,p,cycle,charge=False,brake=0.):
    tau = math.tau
    for bone in s.arm.pose.bones:
        bone.rotation_mode='XYZ';bone.matrix_basis=Matrix.Identity(4)
    mode = p['mode']
    airborne = mode == 'hop' and cycle%1 >= p['stance']
    phase = cycle * tau
    bob = p['body_bob']*math.cos(phase*2) if mode in ['gallop','biped'] else p['body_bob']*.22*math.cos(phase*2)
    if mode == 'hop':
        bob = (math.sin((cycle%1-p['stance'])/(1-p['stance'])*math.pi)*.26 if airborne else -.06*math.sin(cycle%1/p['stance']*math.pi))
    root_z = -p['crouch'] + bob - .04*brake
    s.local('root',location=s.binds['root'].to_3x3().inverted()@V((0,0,root_z)))
    for index,name in enumerate(s.bones):
        if name.endswith(('_upper','_lower','_foot','_lid')) or name in ['root','head']:
            continue
        if name in ['chest','pelvis']:
            s.local(name,((.065*math.sin(phase+(.7 if name=='pelvis' else 0)) if mode=='gallop' else .012*math.sin(phase))+.10*brake,0,.015*math.sin(phase)))
        elif 'neck' in name:
            s.local(name,((.28 if charge else -.035)+.018*math.sin(phase-.5),0,.015*math.sin(phase)))
        elif name.startswith(('tail','steering_tail','swimming_axis','serpentine','axis','spine','ribbon_axis','coil','undulating','peristaltic','radial_trunk','spiral','helix','pedal','ventral_sole')):
            wave = math.sin(phase+s.bones[name]['a'].y*1.4)
            amplitude = .13 if mode in ['wave','swim'] else .045
            s.local(name,(.016*wave,0,amplitude*wave))
        elif mode in ['flight','float'] and name.startswith(('wing','primary','flight_digit','propulsive','posterior_propulsor','caudal','fin','buoyant','sail','pressure_keel','pressure_frame','trailing','float','suspension')):
            side = -1 if '-1' in name else 1
            # Left/right homologues share timing; distal membranes follow their carrying joint.
            segment = int(name[-1]) if name[-1].isdigit() else 0
            wave = math.sin(phase-segment*.42-s.bones[name]['a'].y*.5)
            delicate = name.startswith(('wingfinger','primary','flight_digit','fin_ray'))
            amplitude = (.035 if delicate else (.50 if segment==0 else .34)) if mode=='flight' else .07
            s.local(name,(amplitude*wave,0,side*(.016 if delicate else .04)))
        elif mode=='swim' and name.startswith(('propulsive','posterior_propulsor','caudal','fin','ray','pressure_frame','pressure_window','pressure_nozzle')):
            wave=math.sin(phase-s.bones[name]['a'].y*1.4)
            s.local(name,((.045 if name.startswith('fin_ray') else .24)*wave,0,.045*wave))
    if 'head' in s.bones:
        s.local('head',((.20 if charge else .025)-.012*math.sin(phase),0,0))
    for leg in s.legs:
        fraction=(cycle+p['limb_phases'][leg['name']])%1
        foot=V(leg['foot'])
        if mode=='flight':
            foot+=V((0,.15,(leg['hip'].z-leg['foot'].z)*.50))
        else:
            if fraction<p['stance']:
                foot.y+=(-.5+fraction/p['stance'])*p['stride']
            else:
                u=(fraction-p['stance'])/(1-p['stance'])
                foot.y+=(.5-smooth(0,1,u))*p['stride']
                foot.z+=math.sin(u*math.pi)*p['lift']
            if mode=='hop' and airborne:foot.z+=max(0,bob)*.75
        s.solve_leg(leg,foot)


def build(row,render=False):
    source_sha=hashlib.sha256((ROOT/row['source']).read_bytes()).hexdigest()
    stamp=hashlib.sha256(Path(__file__).read_bytes()+json.dumps(row,sort_keys=True).encode()+source_sha.encode()).hexdigest()
    meta_path=META/(row['source_id']+'.json')
    if meta_path.exists():
        old=json.loads(meta_path.read_text())
        if old.get('fingerprint')==stamp and (ROOT/old['source']).exists() and (ROOT/old['asset']).exists():
            return old
    start=time.monotonic();s=rig_from_source(row);p=profile(s)
    actions={};clips={}
    names=['sprint_loop']+(['sprint_charge_loop'] if row.get('host_motion')=='charge' else [])
    for name in names:
        s.arm.animation_data_create();action=bpy.data.actions.new(name);action.use_fake_user=True;s.arm.animation_data.action=action
        capture=PoseCapture(s.arm,action);count=32;tracks={n:[] for n in s.bones}
        for frame in range(count+1):
            shape_pose(s,p,frame/count,charge=name=='sprint_charge_loop')
            capture.sample(frame*p['period']*30/count+1)
            for n in s.bones:
                pos,q,scale=s.arm.pose.bones[n].matrix_basis.decompose()
                tracks[n].append([*pos,q.x,q.y,q.z,q.w,*scale])
        capture.finish();actions[name]=action
        # Close the cycle exactly, avoiding numerical drift at the wrap.
        for values in tracks.values():values[-1]=values[0].copy()
        clips[name]={'duration':p['period'],'frames':count+1,'tracks':tracks}
    s.arm.animation_data.action=actions['sprint_loop'];bpy.context.scene.frame_set(1)
    source=SRC/(row['source_id']+'.blend')
    s.arm['original_model_source']=row['source'];s.arm['species_id']=row['source_id'];s.arm['fast_motion_profile']=json.dumps(p)
    # No mesh datablocks are referenced by the armature object: originals stay in their own .blend.
    bpy.data.libraries.write(str(source),{s.arm,*actions.values()},fake_user=True,compress=True)
    asset=OUT/(row['source_id']+'.motion')
    data={'version':VERSION,'species_id':row['source_id'],'profile':p,'clips':clips,'parents':{n:b['parent'] for n,b in s.bones.items()}}
    asset.write_bytes(gzip.compress(json.dumps(data,separators=(',',':')).encode(),mtime=0))
    result={'version':VERSION,'fingerprint':stamp,'species_id':row['source_id'],'id':row['id'],'kind':row['kind'],
            'profile':p,'source':str(source.relative_to(ROOT)),'original_source':row['source'],'original_source_sha256':source_sha,
            'asset':str(asset.relative_to(ROOT)),'asset_sha256':hashlib.sha256(asset.read_bytes()).hexdigest(),'clips':names,'seconds':round(time.monotonic()-start,3)}
    if render:
        # Use original weighted meshes in the actual Blender renderer for the edited actions.
        from types import SimpleNamespace
        import build_batch
        s.actions=actions
        build_batch.MEDIA=REVIEW
        (REVIEW/'blender').mkdir(parents=True,exist_ok=True)
        build_batch.source_render(s)
        result['blender_render']=str((REVIEW/'blender'/(row['id']+'.png')).relative_to(ROOT))
    assert source_sha==hashlib.sha256((ROOT/row['source']).read_bytes()).hexdigest()
    meta_path.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print('FAST_MOTION_BUILT',row['source_id'],p['mode'],round(p['natural_speed'],2),result['seconds'],flush=True)
    return result


def main():
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    for path in [SRC,OUT,META]:path.mkdir(parents=True,exist_ok=True)
    rows=catalogue()
    selected=list(rows) if '--all' in args else [k for k,r in rows.items() if k in args or r['id'] in args]
    worker = next((int(a.split('=')[1]) for a in args if a.startswith('--worker=')),0)
    workers = next((int(a.split('=')[1]) for a in args if a.startswith('--workers=')),1)
    selected=selected[worker::workers]
    assert selected,'Select exact species IDs, art IDs or --all'
    for id in selected:build(rows[id],render='--render' in args)
    print('FAST_MOTION_BATCH_DONE',len(selected),flush=True)


if __name__=='__main__':main()
