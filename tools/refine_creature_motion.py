"""Retain the approved six meshes; author grounded animation and attack contacts.
Blender --background --python tools/refine_creature_motion.py -- [form_id]
V1 sources, GLBs and approval renders remain byte-for-byte untouched.
"""
from pathlib import Path
import json, sys, math, hashlib
import bpy
from mathutils import Vector as V, Matrix
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from build_creature_studies import Study, smooth, source_render, biota_rig
import build_creature_studies as original

SRC=ROOT/'art/blender/creature_studies_motion'
OUT=ROOT/'우주-비즈니스/assets/models/creature_studies_motion'
MEDIA=ROOT/'docs/production/media/creature-motion'
for p in [SRC,OUT,MEDIA/'blender']:p.mkdir(parents=True,exist_ok=True)
PROFILES=json.loads((ROOT/'우주-비즈니스/data/creature_motion_profiles.json').read_text())['profiles']
TAU=math.tau

def pulse(t,start,peak,end):return smooth(start,peak,t)*(1-smooth(peak,end,t))
def travel(p,t):
    end=p['release'][0] if p['effect']!='slash' else p['prepare']+.22
    return p['travel']*smooth(p['prepare'],end,t)

def mesh_digest():
    h=hashlib.sha256()
    for ob in sorted((o for o in bpy.context.scene.objects if o.type=='MESH'),key=lambda o:o.name):
        h.update(ob.name.encode())
        for v in ob.data.vertices:h.update(('|'.join(f'{c:.8f}' for c in v.co)).encode())
        for f in ob.data.polygons:h.update(str(tuple(f.vertices)).encode())
    return h.hexdigest()

def from_source(row):
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/row['source']))
    s=Study.__new__(Study);s.spec=row;s.arm=bpy.data.objects['StudySkeleton'];s.bones={};s.binds={};s.legs=[]
    for b in s.arm.data.bones:
        s.bones[b.name]=dict(a=b.head_local.copy(),b=b.tail_local.copy(),parent=b.parent.name if b.parent else None,deform=b.use_deform)
        s.binds[b.name]=b.matrix_local.copy()
    s.flex=[n for n in s.bones if n.startswith('tail')];s.lids=[n for n in s.bones if n.endswith('_lid')]
    s.jaws=[n for n in s.bones if n.startswith(('jaw','petal'))];s.wings=[n for n in s.bones if n.startswith('wing')]
    for name in s.bones:
        if not name.endswith('_upper'):continue
        key=name[:-6];upper=s.bones[name];lower=s.bones[key+'_lower'];phase=0
        if row['kind']=='quadruped':phase={'fore-1':0,'fore1':.5,'hind-1':.75,'hind1':.25}[key]
        elif row['kind']=='hexapod':phase=(0 if '-1' in key else .5)+(int(key[3])%2)*.5
        elif row['kind']=='tripod':phase=int(key[-1])/3
        elif row['kind']=='glider':phase=0 if '-1' in key else .5
        s.legs.append(dict(name=key,hip=list(upper['a']),knee=list(upper['b']),foot=list(lower['b']),parent=upper['parent'],phase=phase,upper=(upper['a']-upper['b']).length,lower=(lower['a']-lower['b']).length))
    s.muzzle=V((row['muzzle'][0],-row['muzzle'][2],row['muzzle'][1]));return s

def socket(s,name,bone,point):
    ob=bpy.data.objects.get(name)
    if ob is None:ob=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(ob)
    ob.parent=s.arm;ob.parent_type='BONE';ob.parent_bone=bone
    bpy.context.view_layer.update();ob.matrix_world=Matrix.Translation(V(point))
    s.socket_bindings[name]={'bone':bone,'point':[point[0],point[2],-point[1]]}

def animate(s,p,only_run=False):
    rig=s.arm;scene=bpy.context.scene;scene.render.fps=30;s.actions={}
    rig.animation_data_clear()
    for old in list(bpy.data.actions):
        if not only_run or old.name=='run_loop':bpy.data.actions.remove(old)
    if only_run:s.actions={a.name:a for a in bpy.data.actions}
    kinds=[('idle_loop',2),('move_loop',2),('feed',2.4),('attack',p['duration']),('hurt',.8),('blocked',.9),('stop',.6),('turn_left',1),('turn_right',1)]
    kinds += [('run_loop',p['run']['period']*2)]
    if only_run:kinds=[k for k in kinds if k[0]=='run_loop']
    for state,duration in kinds:
        rig.animation_data_create();action=bpy.data.actions.new(state);action.use_fake_user=True;rig.animation_data.action=action
        count=round(duration*30);scene.frame_start=1;scene.frame_end=count+1
        for frame in range(count+1):
            t=frame/30;scene.frame_set(frame+1)
            for b in rig.pose.bones:b.rotation_mode='XYZ';b.matrix_basis=Matrix.Identity(4)
            kind=s.spec['kind'];run=state=='run_loop';move=state in ['move_loop','run_loop'];gait=p['run'] if run else p;cycle=t/gait['period'] if move else t;attack=state=='attack';turn=state.startswith('turn_');hurt=state in ['hurt','blocked'];phase=cycle*TAU
            windup=smooth(.06,p['prepare'],t)*(1-smooth(p['prepare'],p['release'][0]+.12,t)) if attack else 0
            release=sum(pulse(t,v-.055,v+.035,v+.30) for v in p['release']) if attack else 0
            recover=pulse(t,p['active_end'],p['active_end']+.13,p['settle']) if attack else 0
            recoil=pulse(t,0,.065,duration) if hurt else 0
            forward=travel(p,t) if attack else (t*gait['stride']/gait['stance']/gait['period'] if move else 0)
            root=V((0,-forward,0));body_z=0.0;roll=0.0
            if move:
                body_z=(.027 if run else .014)*math.cos(phase*2);roll=(.014 if run else .022)*math.sin(phase)
                if kind=='hopper':
                    flight=max(0,min(1,((cycle%1)-.27)/.53));root.z=(.34 if run else .26)*math.sin(flight*math.pi);body_z=-.065*pulse(cycle%1,.03,.20,.31)-.07*pulse(cycle%1,.77,.83,.98)
            if attack:
                body_z=-.09*windup-.07*recover
                if kind=='hopper':
                    flight=max(0,min(1,(t-p['air_start'])/(p['air_end']-p['air_start'])));root.z=p['air_height']*math.sin(flight*math.pi);body_z=-.17*windup-.14*recover
            if kind=='glider':root.z=.26+.025*math.sin(phase);body_z=0
            if state=='stop':body_z=-.025*pulse(t,0,.13,.58)
            root.z+=body_z
            s.local('root',location=s.binds['root'].to_3x3().inverted()@root)
            s.local('pelvis',(.012*math.sin(phase),roll,0));s.local('chest',(.014*math.sin(phase+.35)-.08*windup,0,-roll*.5),scale=(1+.008*math.sin(phase),1,1+.009*math.sin(phase)))
            s.local('neck',(.015*math.sin(phase+.7),0,.025*math.sin(phase*.5)));s.local('head',(-.01*math.sin(phase+.9),0,0))
            if state=='feed':
                g=smooth(.0,.8,t)*(1-smooth(1.7,2.4,t));s.local('neck',(.58*g if kind=='quadruped' else .18*g,0,0));s.local('head',(.13*g,0,.025*math.sin(t*6)))
            if turn:
                sign=1 if state=='turn_left' else -1;g=math.sin(t*math.pi)
                s.local('head',(0,0,sign*.12*g));s.local('neck',(0,0,sign*.12*g));s.local('chest',(0,sign*.035*g,sign*.045*g));s.local('pelvis',(0,0,-sign*.025*g))
            if hurt:
                s.local('chest',(-.19*recoil,0,.075*recoil));s.local('neck',(.15*recoil,0,-.045*recoil));s.local('head',(-.12*recoil,0,0));s.local('pelvis',(.04*recoil,0,0))
            if attack:
                if kind=='quadruped':
                    s.local('neck',(.52*windup+.45*release+.10*recover,0,0));s.local('head',(.20*windup-.08*release,0,0));s.local('chest',(-.06*windup+.07*release-.06*recover,0,0))
                elif kind=='hexapod':
                    torsion=pulse(t,.73,.92,1.13)-pulse(t,1.05,1.26,1.51)
                    s.local('chest',(-.08*windup,0,.105*torsion));s.local('head',(-.06*windup,0,-.06*torsion))
                elif kind=='tripod':
                    s.local('chest',(0,0,0),scale=(1+.105*windup-.045*release,1+.035*windup-.04*release,1+.105*windup-.045*release));s.local('neck',(-.15*windup+.10*release,0,0));s.local('head',(-.13*windup+.13*release,0,0))
                elif kind=='hopper':s.local('chest',(.12*windup-.12*root.z+.16*recover,0,0));s.local('head',(-.05*windup-.07*recover,0,0))
                elif kind=='serpent':s.local('chest',(-.10*windup,0,0),scale=(1+.07*windup,1,1+.06*windup));s.local('neck',(-.32*windup+.085*release,0,0));s.local('head',(.15*windup-.11*release,0,0))
                elif kind=='glider':s.local('chest',(-.055*windup+.065*release,0,0));s.local('neck',(-.055*windup+.06*release,0,0))
            for i,name in enumerate(s.flex):
                amount=(.21 if run else .17) if kind=='serpent' else .07
                s.local(name,(0,.025*math.sin(phase-i*.65),amount*math.sin(phase-i*.70)*(1 if move else .18)*(1-.65*windup)))
            for name in s.lids:
                blink=max(0,1-abs(t%2-1.65)/.08) if not attack else 0;s.local(name,(blink*.40+recoil*.25,0,0))
            for i,name in enumerate(s.jaws):
                a=.12*(.5+.5*math.sin(t*9)) if state=='feed' else (.20*windup+.40*release if attack else 0)
                if kind=='tripod':s.local(name,(a,0,0))
                elif kind=='serpent':
                    # Petals open around their own radial hinge rather than alternating side yaw.
                    angle=i*TAU/3;s.local(name,(math.sin(angle)*a,0,math.cos(angle)*a))
                elif kind=='hexapod':s.local(name,(0,0,(-1 if i%2 else 1)*a))
                else:s.local(name,(-a,0,0))
            if kind=='glider':
                for name in s.wings:
                    side=-1 if '-1' in name else 1;seg=int(name.rsplit('_',1)[1]);beat=math.sin(phase*1.5-seg*.42)
                    lift=(.12 if seg==0 else -.09)+beat*(.38 if move else .13)*(1-.80*windup)
                    s.local(name,(0,0,side*lift))
            bpy.context.view_layer.update()
            for leg in s.legs:
                foot=V(leg['foot']);offset=leg['phase']
                if run and kind=='quadruped':offset={'fore-1':0,'fore1':.5,'hind-1':.5,'hind1':0}[leg['name']]
                f=(cycle+offset)%1
                if move and kind not in ['glider','hopper']:
                    relative=(-.5+f/gait['stance'])*gait['stride'] if f<gait['stance'] else (.5-smooth(0,1,(f-gait['stance'])/(1-gait['stance'])))*gait['stride']
                    foot.y+=-forward+relative
                    if f>=gait['stance']:foot.z+=math.sin((f-gait['stance'])/(1-gait['stance'])*math.pi)*((.17 if run else .13) if kind=='quadruped' else (.13 if run else .10))
                elif move and kind=='hopper':
                    flight=max(0,min(1,(cycle%1-.27)/.53));step=math.floor(cycle)+smooth(.27,.8,cycle%1)
                    foot.y-=step*gait['stride']/gait['stance'];foot.z+=root.z+.10*math.sin(flight*math.pi)
                if attack and kind in ['quadruped','hexapod']:
                    front=leg['name'].startswith(('fore','leg0'))
                    start=p['prepare']-.12 if front else p['prepare']+.01;end=start+.31
                    step=smooth(start,end,t);foot.y-=p['travel']*step;foot.z+=.15*pulse(t,start,start+.14,end)
                    if kind=='hexapod' and front:
                        strike=p['release'][0 if '-1' in leg['name'] else 1]
                        lift=pulse(t,strike-.27,strike-.13,strike+.12);swing=pulse(t,strike-.18,strike+.015,strike+.24)
                        foot.z+=.36*lift+.16*swing;foot.y-=.55*swing;foot.x*=1-.60*swing
                elif attack and kind=='hopper':foot.y-=forward;foot.z+=root.z+.15*math.sin(max(0,min(1,(t-p['air_start'])/(p['air_end']-p['air_start'])))*math.pi)
                if kind=='glider':foot+=V((0,.34,.48));foot.z+=root.z
                if turn:
                    lift=max(0,math.sin((t+leg['phase'])*TAU));foot.z+=.09*lift;foot.x+=(-.07 if state=='turn_left' else .07)*math.sin(t*math.pi)*lift
                s.solve_leg(leg,foot)
            # Horizontal root displacement is supplied by the runtime from the same profile.
            # Leg solutions retain world-planted stance goals, without translating feet twice.
            s.local('root',location=s.binds['root'].to_3x3().inverted()@V((0,0,root.z)))
            for b in rig.pose.bones:
                for prop in ['location','rotation_euler','scale']:b.keyframe_insert(data_path=prop,frame=frame+1,group=b.name)
        s.actions[state]=action;rig.animation_data.action=None
    rig.animation_data.action=s.actions['idle_loop'];scene.frame_set(1)

def build(row):
    prior_path=SRC/(row['id']+'.json')
    prior=json.loads(prior_path.read_text()) if prior_path.exists() else None
    s=from_source(prior or row);before=mesh_digest();p=PROFILES[row['id']];s.socket_bindings={}
    s.arm.animation_data.action=None
    for b in s.arm.pose.bones:b.matrix_basis=Matrix.Identity(4)
    bpy.context.view_layer.update()
    socket(s,'Socket_Strike','head',(0,-1.60,2.44) if row['kind']=='quadruped' else s.muzzle)
    socket(s,'Socket_Muzzle','head',s.muzzle)
    for leg in s.legs:socket(s,'Socket_'+leg['name'],leg['name']+'_foot',V(leg['foot'])+V((0,-.24,.025)))
    if prior:s.socket_bindings.update(prior['sockets'])
    animate(s,p,only_run=prior is not None);assert mesh_digest()==before,'Approved mesh geometry changed'
    source=SRC/(row['id']+'.blend');bpy.ops.wm.save_as_mainfile(filepath=str(source))
    data={**row,'source':str(source.relative_to(ROOT)),'status':'approved-shape-motion-v3-speed-lab','approved_mesh_digest':before,'clips':list(s.actions),'motion_profile':p,'sockets':s.socket_bindings,'lods':{}}
    biota_rig.consolidate()
    for lod in ['near','far']:
        if lod=='far':
            s.arm.data.pose_position='REST'
            for ob in bpy.context.scene.objects:
                if ob.type!='MESH' or len(ob.data.polygons)<160:continue
                bpy.context.view_layer.objects.active=ob;mod=ob.modifiers.new('Motion study LOD','DECIMATE');mod.ratio=.43;bpy.ops.object.modifier_apply(modifier=mod.name)
            s.arm.data.pose_position='POSE'
        path=OUT/(row['id']+'_'+lod+'.glb')
        bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',export_yup=True,export_animations=True,export_animation_mode='ACTIONS',export_merge_animation='ACTION',export_force_sampling=True,export_frame_range=False,export_cameras=False,export_lights=False)
        data['lods'][lod]={**row['lods'][lod],'path':str(path.relative_to(ROOT)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
    (SRC/(row['id']+'.json')).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    bpy.ops.wm.open_mainfile(filepath=str(source));s.arm=bpy.data.objects['StudySkeleton'];s.actions={name:bpy.data.actions[name] for name in data['clips']}
    original.MEDIA=MEDIA;source_render(s)
    print('MOTION_V3',row['id'],'approved geometry preserved',before,flush=True)

if __name__=='__main__':
    wanted=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    rows=json.loads((ROOT/'우주-비즈니스/data/creature_studies.json').read_text())['forms']
    for row in rows:
        if not wanted or row['id'] in wanted:build(row)
    result=[json.loads((SRC/(r['id']+'.json')).read_text()) for r in rows if (SRC/(r['id']+'.json')).exists()]
    (ROOT/'우주-비즈니스/data/creature_motion_studies.json').write_text(json.dumps({'version':3,'scope':'six approved shapes; movement/contact lab','forms':result},ensure_ascii=False,indent=2)+'\n')
