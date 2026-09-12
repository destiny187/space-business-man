"""First additional animal anatomies: an annular feeder and a five-rayed walker.
Uses Blender and the approved INK surface/skin workflow. Never rewrites native catalogs.
"""
from pathlib import Path
import sys,math,json,hashlib
import bpy
from mathutils import Vector as V,Matrix
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
from build_creature_studies import Study,smooth,source_render,biota_rig
import build_creature_studies as reference
from refine_creature_motion import socket,mesh_digest,pulse
SRC=ROOT/'art/blender/creature_remodel/r01';OUT=ROOT/'우주-비즈니스/assets/models/creature_remodel/r01';MEDIA=ROOT/'docs/production/media/creature-remodel/r01'
for p in [SRC,OUT,MEDIA/'blender']:p.mkdir(parents=True,exist_ok=True)
SPECS=[
 dict(id='annulus',name='환공 여과수',kind='annular',source_id='bio_torus_loom_01',palette=['536e70','b4b89b','334950','c9965e'],attack='spit',habitat='광물성 암반 · 진동 감각공과 고리 안쪽 여과기관'),
 dict(id='pentafold',name='오지 접힘수',kind='radial',source_id='bio_pentapalm_03',palette=['846755','c0ac84','405954','b47b47'],attack='slam',habitat='열수·온토 · 다섯 방사 사지와 말단 섭식부'),
 dict(id='tethermaw',name='줄목 추적수',kind='cantilever',source_id='bio_pendulum_grazer_01',palette=['677e76','c5b58d','3e505c','b38a5d'],attack='bite',habitat='현수 식도 · 긴 관절 목 끝의 머리와 회수 동작')]
PROFILES={
 'annulus':dict(duration=2.8,prepare=.8,release=[1.0,1.12,1.24],active_end=1.36,settle=2.64,travel=0,stride=.34,stance=.8,period=1.0,damage=9,strike_radius=.10,target_z=3.2,target_height=.8,effect='acid',flight_seconds=.32,arc_height=.10,hit_pause=0,knockback=.10,run=dict(stride=.50,stance=.78,period=.7)),
 'pentafold':dict(duration=2.8,prepare=.72,release=[1.30],active_end=1.48,settle=2.6,travel=.42,stride=.35,stance=.76,period=1.0,damage=30,strike_radius=.85,target_z=2.1,target_height=.10,effect='slam',hit_pause=.035,knockback=.23,run=dict(stride=.58,stance=.72,period=.6),landing_sockets=['Socket_ray0','Socket_ray0']),
 'tethermaw':dict(duration=2.8,prepare=.80,release=[1.04],active_end=1.23,settle=2.64,travel=.30,stride=.48,stance=.76,period=1.0,damage=24,strike_radius=.22,strike_lead=.025,strike_tail=.12,target_z=3.72,target_height=1.0,effect='ram',hit_pause=.035,knockback=.18,run=dict(stride=.70,stance=.73,period=.6))}

def limb(s,name,hip,knee,foot,direction,width=.15,parent='chest',phase=0):
    hip,knee,foot,direction=map(V,[hip,knee,foot,direction])
    s.bone(name+'_upper',hip,knee,parent);s.bone(name+'_lower',knee,foot,name+'_upper');s.bone(name+'_foot',foot,foot+direction*.25,name+'_lower')
    s.tube(name+' continuous load tissue',[hip,knee,foot],[width*1.6,width*.8,width*.50],soft=True)
    s.oval(name+' contact cushion',foot,(width*1.05,width*1.05,.075),'ventral',name+'_foot')
    side=V((-direction.y,direction.x,0))
    for sign in [-1,1]:s.tube(name+' divided tension toe',[foot+side*width*.4*sign,foot+direction*.17+side*width*.5*sign,foot+direction*.30+side*width*.65*sign],[.07,.046,.012],'keratin',name+'_foot')
    s.legs.append(dict(name=name,hip=list(hip),knee=list(knee),foot=list(foot),parent=parent,phase=phase,upper=(hip-knee).length,lower=(knee-foot).length,forward=list(direction)))

def annulus(s):
    s.bone('chest',(0,0,.7),(0,0,1.1));s.bone('head',(0,-.12,1.50),(0,-.60,1.34),'chest')
    center=V((0,0,1.45));points=[]
    for i in range(17):
        a=math.tau*i/16;points.append(center+V((math.cos(a)*.65,0,math.sin(a)*.79)))
    s.tube('Continuous hollow muscular annulus',points,[.18]*17,soft=True)
    for i in range(8):
        a=math.tau*i/8;start=center+V((math.cos(a)*.65,0,math.sin(a)*.79));end=center+V((math.cos(a+.45)*.65,0,math.sin(a+.45)*.79))
        s.bone('ring'+str(i),start,end,'chest')
        s.tube('Flexible mineral shield '+str(i),[start+V((0,.08,0)),(start+end)*.5+V((0,.10,0)),end+V((0,.08,0))],[.13,.17,.07],'shell','ring'+str(i))
        s.oval('Recessed vibration pore '+str(i),start+V((0,-.155,0)),(.049,.028,.049),'dark','ring'+str(i))
    # The feeding organ hangs inside the opening; it is not a mammal face.
    s.tube('Suspended contractile feeding siphon',[(0,0,2.02),(0,-.13,1.71),(0,-.38,1.54),(0,-.72,1.30)],[.16,.13,.12,.17],soft=True)
    s.oval('Recessed siphon mouth',(0,-.795,1.29),(.15,.045,.12),'mouth','head')
    for side in [-1,1]:
        n='jaw'+str(side);s.bone(n,(side*.13,-.66,1.32),(side*.11,-.88,1.27),'head');s.jaws.append(n)
        s.tube('Flexible split lip '+str(side),[(side*.13,-.66,1.34),(side*.18,-.79,1.31),(side*.10,-.88,1.24)],[.065,.063,.015],'ventral',n)
    for i in range(3):
        a=-math.pi/2+i*math.tau/3;direction=V((math.cos(a),math.sin(a),0))
        limb(s,'support'+str(i),direction*.34+V((0,0,.87)),direction*.78+V((0,0,.52)),direction*.95+V((0,0,.10)),direction,.15,'chest',i/3)
        s.tube('Support root tendon '+str(i),[direction*.32+V((0,0,1.03)),direction*.52+V((0,0,.85)),direction*.76+V((0,0,.58))],[.20,.16,.10],soft=True)
    s.muzzle=V((0,-.85,1.29))

def pentafold(s):
    s.bone('chest',(0,0,.40),(0,0,.75));s.bone('head',(0,0,.52),(0,-.10,.52),'chest',False)
    s.oval('Continuous pentaradial central mantle',(0,0,.62),(.62,.62,.30),soft=True)
    for i in range(5):
        a=-math.pi/2+i*math.tau/5;direction=V((math.cos(a),math.sin(a),0));side=V((-direction.y,direction.x,0));name='ray'+str(i)
        root=direction*.25+V((0,0,.65));s.bone(name+'_base',root,direction*.60+V((0,0,.63)),'chest')
        s.tube('Radial shoulder lobe '+str(i),[root,direction*.63+V((0,0,.65)),direction*.86+V((0,0,.54))],[.26,.25,.18],soft=True)
        limb(s,name,direction*.62+V((0,0,.65)),direction*1.15+V((0,0,.47)),direction*1.48+V((0,0,.12)),direction,.16,name+'_base',(i*2%5)/5)
        for k in range(2):
            start=direction*(.35+k*.24)+V((0,0,.87-k*.07))
            s.membrane('Overlapping living shield '+str(i)+'_'+str(k),[start-side*.18,start+direction*.34-side*.22,start+direction*.40,start+direction*.34+side*.22,start+side*.18],'shell',name+'_base')
        foot=direction*1.48+V((0,0,.12));mouth=foot+direction*.14+V((0,0,.035))
        s.oval('Terminal feeding pad '+str(i),mouth,(.12,.12,.055),'mouth',name+'_foot')
        for sign in [-1,1]:
            n='jaw'+str(i)+'_'+str(sign);base=mouth+side*.09*sign;s.bone(n,base,base+direction*.17,name+'_foot');s.jaws.append(n)
            s.tube('Sensory feeding lip '+n,[base,base+direction*.11+V((0,0,.04)),base+direction*.20],[.055,.043,.01],'ventral',n)
        s.oval('Covered thermosensory pit '+str(i),direction*.38+V((0,0,.89)),(.055,.055,.025),'dark',name+'_base')
    s.oval('Central flexible pressure diaphragm',(0,0,.88),(.20,.20,.055),'ventral','chest')
    s.muzzle=V((0,-1.67,.15))

def tethermaw(s):
    s.bone('chest',(0,.40,1.12),(0,-.37,1.18))
    s.oval('Suspended visceral body',(0,.22,1.16),(.49,.70,.37),soft=True)
    points=[(0,-.35,1.22),(0,-.91,1.49),(0,-1.57,1.31),(0,-2.20,1.02),(0,-2.67,1.01)]
    for i in range(3):s.bone('neck'+str(i),points[i],points[i+1],'chest' if i==0 else 'neck'+str(i-1))
    s.bone('head',points[3],points[4],'neck2')
    s.tube('Continuous long suspension neck',points,[.23,.18,.16,.18,.23],soft=True)
    s.oval('Distal jaw musculature',(0,-2.53,1.03),(.28,.40,.21),soft=True)
    for side in [-1,1]:
        s.tube('Curved dorsal load arch',[(side*.36,.70,1.20),(side*.44,.45,1.72),(side*.38,-.15,1.76),(side*.21,-.52,1.38)],[.12,.15,.12,.055],'shell','chest')
        s.membrane('Flexible shoulder arch web',[(side*.39,.60,1.31),(side*.45,.40,1.65),(side*.36,-.10,1.69),(side*.28,-.38,1.35)],'ventral','chest')
        s.eye('Distal lateral sense '+str(side),(side*.245,-2.59,1.13),side,.066,'head',False)
        for i in range(3):
            p=V(points[i+1]);s.tube('Neck protective fold '+str(side)+'_'+str(i),[p+V((side*.10,.14,-.04)),p+V((side*.17,0,.08)),p+V((side*.10,-.13,-.03))],[.032,.045,.018],'ventral','neck'+str(i))
    for i in range(3):
        a=-math.pi/2+i*math.tau/3;direction=V((math.cos(a),math.sin(a),0))
        limb(s,'anchor'+str(i),direction*.36+V((0,.22,1.18)),direction*.76+V((0,.25,.63)),direction*.93+V((0,.20,.10)),direction,.18,'chest',i/3)
    s.bone('jaw',(0,-2.31,.89),(0,-2.93,.91),'head');s.jaws=['jaw']
    s.oval('Dark distal oral opening',(0,-2.78,.98),(.19,.22,.07),'mouth','head')
    s.tube('Long lower grasping jaw',[(0,-2.35,.85),(0,-2.72,.84),(0,-3.02,.98)],[.18,.14,.025],'ventral','jaw')
    for side in [-1,1]:s.tube('Curved gripping tooth '+str(side),[(side*.18,-2.83,1.06),(side*.15,-2.98,1.03),(side*.11,-3.03,.93)],[.055,.037,.008],'keratin','head')
    s.muzzle=V((0,-3.02,.97))

def animate(s,p):
    rig=s.arm;scene=bpy.context.scene;scene.render.fps=30;s.actions={}
    states=[('idle_loop',2),('move_loop',2*p['period']),('run_loop',2*p['run']['period']),('feed',2.4),('attack',2.8),('hurt',.8),('blocked',.9),('stop',.6),('turn_left',1),('turn_right',1)]
    for state,duration in states:
        rig.animation_data_create();action=bpy.data.actions.new(state);action.use_fake_user=True;rig.animation_data.action=action
        scene.frame_start=1;count=round(duration*30);scene.frame_end=count+1
        for frame in range(count+1):
            scene.frame_set(frame+1);t=frame/30;moving=state in ['move_loop','run_loop'];gait=p['run'] if state=='run_loop' else p
            cycle=t/gait['period'] if moving else t;phase=cycle*math.tau
            for bone in rig.pose.bones:bone.rotation_mode='XYZ';bone.matrix_basis=Matrix.Identity(4)
            forward=t*gait['stride']/gait['stance']/gait['period'] if moving else (p['travel']*smooth(p['prepare'],p['release'][0],t) if state=='attack' else 0)
            wind=pulse(t,0,p['prepare'],p['release'][0]+.12) if state=='attack' else 0
            strike=sum(pulse(t,v-.08,v+.02,v+.24) for v in p['release']) if state=='attack' else 0
            hurt=pulse(t,0,.08,duration) if state in ['hurt','blocked'] else 0
            body_z=(.014*math.cos(phase*2) if moving else .006*math.sin(phase))-.06*wind
            root=V((0,-forward,body_z));s.local('root',location=s.binds['root'].to_3x3().inverted()@root)
            s.local('chest',(-.08*hurt,0,.045*hurt),scale=(1+.01*math.sin(phase),1+.01*math.sin(phase),1-.012*math.sin(phase)))
            if s.spec['kind']=='annular':
                s.local('head',(.10*wind-.08*strike+(.22*pulse(t,0,.8,2.4) if state=='feed' else 0),0,.018*math.sin(phase)))
                for i in range(8):s.local('ring'+str(i),(0,.022*math.sin(phase-i*.5),.009*math.sin(phase-i*.4)),scale=(1+.025*wind,1,1+.025*wind))
            elif s.spec['kind']=='radial':
                for i in range(5):s.local('ray'+str(i)+'_base',(0,.022*math.sin(phase-i*.5),.035*wind))
            else:
                s.local('neck0',(.26*wind-.20*strike,0,.018*math.sin(phase)))
                s.local('neck1',(-.38*wind+.18*strike,0,-.012*math.sin(phase-.4)))
                s.local('neck2',(.16*wind-.08*strike,0,.012*math.sin(phase-.8)))
                s.local('head',(.12*wind-.15*strike,0,-.018*math.sin(phase-.8)))
            for i,n in enumerate(s.jaws):s.local(n,(0,.26*strike+(.23*(.5+.5*math.sin(t*7-i)) if state=='feed' else 0),(-1 if i%2 else 1)*.10*wind))
            bpy.context.view_layer.update()
            for leg in s.legs:
                foot=V(leg['foot']);f=(cycle+leg['phase'])%1
                if moving:
                    rel=(-.5+f/gait['stance'])*gait['stride'] if f<gait['stance'] else (.5-smooth(0,1,(f-gait['stance'])/(1-gait['stance'])))*gait['stride']
                    foot.y+=-forward+rel
                    if f>=gait['stance']:foot.z+=math.sin((f-gait['stance'])/(1-gait['stance'])*math.pi)*.13
                elif state=='attack' and s.spec['kind']=='radial':
                    foot.y-=forward
                    if leg['name']=='ray0':foot.z+=.45*pulse(t,.50,.95,1.30)
                elif state=='attack' and s.spec['kind']=='cantilever':
                    foot.y-=forward;foot.z+=.09*pulse(t,.65,.83,1.04)
                if state.startswith('turn_'):foot.z+=max(0,math.sin((t+leg['phase'])*math.tau))*.08
                s.solve_leg(leg,foot);at=rig.pose.bones[leg['name']+'_foot'].matrix.translation.copy();s.aim_bone(leg['name']+'_foot',at,at+V(leg['forward'])*.25)
            s.local('root',location=s.binds['root'].to_3x3().inverted()@V((0,0,root.z)))
            for bone in rig.pose.bones:
                for prop in ['location','rotation_euler','scale']:bone.keyframe_insert(data_path=prop,frame=frame+1,group=bone.name)
        s.actions[state]=action;rig.animation_data.action=None
    rig.animation_data.action=s.actions['idle_loop'];scene.frame_set(1)

def build(spec):
    s=Study(spec);{'annular':annulus,'radial':pentafold,'cantilever':tethermaw}[spec['kind']](s);s.fuse_skin();s.rig();s.socket_bindings={}
    socket(s,'Socket_Muzzle','head',s.muzzle)
    socket(s,'Socket_Strike','head',s.muzzle)
    for leg in s.legs:socket(s,'Socket_'+leg['name'],leg['name']+'_foot',leg['foot'])
    animate(s,PROFILES[spec['id']]);bpy.context.view_layer.update()
    source=SRC/(spec['id']+'.blend');bpy.ops.wm.save_as_mainfile(filepath=str(source))
    data={**spec,'source':str(source.relative_to(ROOT)),'status':'remodel-r01-built-awaiting-review','bone_count':len(s.bones),'locomotion_chains':len(s.legs),'clips':list(s.actions),'approved_mesh_digest':None,'mesh_digest':mesh_digest(),'muzzle':[s.muzzle.x,s.muzzle.z,-s.muzzle.y],'sockets':s.socket_bindings,'motion_profile':PROFILES[spec['id']],'lods':{}}
    biota_rig.consolidate()
    for lod in ['near','far']:
        if lod=='far':
            s.arm.data.pose_position='REST'
            for ob in list(bpy.context.scene.objects):
                if ob.type!='MESH' or len(ob.data.polygons)<160:continue
                bpy.context.view_layer.objects.active=ob;mod=ob.modifiers.new('R01 far budget','DECIMATE');mod.ratio=.43;bpy.ops.object.modifier_apply(modifier=mod.name)
            s.arm.data.pose_position='POSE'
        path=OUT/(spec['id']+'_'+lod+'.glb');bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',export_yup=True,export_animations=True,export_animation_mode='ACTIONS',export_merge_animation='ACTION',export_force_sampling=True,export_frame_range=False,export_cameras=False,export_lights=False)
        pts=[];triangles=0
        for ob in bpy.context.scene.objects:
            if ob.type!='MESH':continue
            ob.data.calc_loop_triangles();triangles+=len(ob.data.loop_triangles);pts.extend(ob.matrix_world@v.co for v in ob.data.vertices)
        pts=[(p.x,p.z,-p.y) for p in pts];data['lods'][lod]=dict(path=str(path.relative_to(ROOT)),triangles=triangles,sha256=hashlib.sha256(path.read_bytes()).hexdigest(),min=[min(p[i] for p in pts) for i in range(3)],max=[max(p[i] for p in pts) for i in range(3)])
    (SRC/(spec['id']+'.json')).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    bpy.ops.wm.open_mainfile(filepath=str(source));s.arm=bpy.data.objects['StudySkeleton'];s.actions={n:bpy.data.actions[n] for n in data['clips']};reference.MEDIA=MEDIA;source_render(s)
    print('REMODEL_R01_BUILT',spec['id'],len(s.bones),'bones',flush=True)

if __name__=='__main__':
    wanted=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    for spec in SPECS:
        if not wanted or spec['id'] in wanted:build(spec)
    approved=json.loads((ROOT/'우주-비즈니스/data/creature_motion_studies.json').read_text())['forms']
    forms=approved+[json.loads((SRC/(s['id']+'.json')).read_text()) for s in SPECS]
    (ROOT/'우주-비즈니스/data/creature_remodel_r01.json').write_text(json.dumps({'version':1,'scope':'R01 production/review staging; no native catalog or save writes','forms':forms},ensure_ascii=False,indent=2)+'\n')
