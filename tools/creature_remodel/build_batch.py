"""Incremental Blender anatomical batch production. Same fused tissue/INK workflow as approved studies."""
from pathlib import Path
import sys,json,math,hashlib,time
import bpy
import numpy as np
from mathutils import Vector as V,Matrix
ROOT=Path(__file__).resolve().parents[2];sys.path[:0]=[str(ROOT/'tools'),str(Path(__file__).parent)]
from recipes import recipes
from build_creature_studies import Study,smooth,biota_rig
from build_creature_remodel_r01 import limb
from refine_creature_motion import socket,pulse
import ink_blender as ink
SRC=ROOT/'art/blender/creature_remodel/r02';OUT=ROOT/'우주-비즈니스/assets/models/creature_remodel/r02';MEDIA=ROOT/'docs/production/media/creature-remodel/r02'
for p in [SRC,OUT,MEDIA/'blender']:p.mkdir(parents=True,exist_ok=True)
VERSION='r02-1'

class AnatomicalStudy(Study):
    """Calculate the same rest-space IK without repeated dependency-graph evaluations per joint."""
    def world(self,name):
        rest=self.binds[name];parent=self.bones[name]['parent'];pb=self.arm.pose.bones[name]
        return (self.world(parent)@self.binds[parent].inverted()@rest if parent else rest)@pb.matrix_basis
    def aim_bone(self,name,a,b):
        a,b=V(a),V(b);rest=self.binds[name];old=(self.bones[name]['b']-self.bones[name]['a']).normalized()
        target=Matrix.LocRotScale(a,old.rotation_difference((b-a).normalized())@rest.to_quaternion(),V((1,1,1)))
        parent=self.bones[name]['parent']
        self.arm.pose.bones[name].matrix_basis=rest.inverted()@(self.binds[parent]@self.world(parent).inverted()@target if parent else target)
    def solve_leg(self,leg,foot):
        name=leg['name'];parent=leg['parent'];p=self.world(parent)@self.binds[parent].inverted()
        hip=p@V(leg['hip']);restknee=p@V(leg['knee']);d=V(foot)-hip
        length=min(max(d.length,abs(leg['upper']-leg['lower'])+.002),leg['upper']+leg['lower']-.002);direction=d.normalized()
        along=(leg['upper']**2-leg['lower']**2+length**2)/(2*length)
        pole=restknee-hip;pole-=direction*pole.dot(direction)
        if pole.length<.001:pole=direction.cross(V((1,0,0)))
        knee=hip+direction*along+pole.normalized()*math.sqrt(max(0,leg['upper']**2-along**2));goal=hip+direction*length
        self.aim_bone(name+'_upper',hip,knee);self.aim_bone(name+'_lower',knee,goal)
        self.aim_bone(name+'_foot',goal,goal+V(leg['forward'])*.25)


def directions(n,phase=-math.pi/2):return [V((math.cos(phase+i*math.tau/n),math.sin(phase+i*math.tau/n),0)) for i in range(n)]
def senses(s,points,bones):
    count=s.spec['morphology']['eye_count'];mode=s.spec['morphology']['mode']
    for i,p in enumerate(points):
        bone=bones[i%len(bones)];p=V(p)
        s.oval('Protected sensory recess '+str(i),p,(.060,.040,.052),'dark',bone)
        if count>0 and i<count:s.oval('Inset sensory lens '+str(i),p+V((0,-.022,.008)),(.028,.025,.027),'iris',bone)
        elif mode in [5,8]:
            for j in range(3):s.tube('Pressure sensing fold',[p+V((-.05,0,j*.025)),p+V((0,-.035,j*.025)),p+V((.05,0,j*.025))],[.01,.015,.005],'ventral',bone,sides=8,steps=3)

def supports(s,height,radius,root_radius=.30):
    m=s.spec['morphology'];n=int(m['limb_count']);width=.12 if n>=6 else .16
    for i,d in enumerate(directions(n)):
        # Different leg counts and asymmetric load stations are real skeletal differences.
        reach=radius*(1+.10*math.sin(i*2.3+m['mode']*.7));hip=d*root_radius+V((0,0,height))
        knee=d*reach*.75+V((0,0,height*.56));foot=d*reach+V((0,0,.10))
        phase=(i*(n//2 if n%2 else 1)%n)/n if n%2 else (i%2)*.5+(i//2)*.08
        limb(s,'support'+str(i),hip,knee,foot,d,width,'chest',phase)
    s.support_height=height

def mouth(s,name,at,parent='chest',radius=.14,direction=(0,-1,0)):
    at=V(at);d=V(direction).normalized();side_axis=d.cross(V((0,0,1))).normalized();up=side_axis.cross(d).normalized();s.bone(name,at-d*.18,at+d*.18,parent)
    s.tube('Attached feeding tube '+name,[at-d*.25,at-d*.04,at+d*.10],[radius*.9,radius,radius*.85],'ventral',name)
    opening=s.oval('Recessed oral opening '+name,at+d*.12,(radius*.74,.035,radius*.63),'mouth',name)
    opening.rotation_mode='QUATERNION';opening.rotation_quaternion=V((0,-1,0)).rotation_difference(d)
    for side in [-1,1]:
        jaw=name+'_jaw'+str(side);p=at+side_axis*(side*radius*.75);s.bone(jaw,p,p+d*.24,name);s.jaws.append(jaw)
        s.tube('Flexible gripping lip '+jaw,[p,p+d*.17+side_axis*(side*.025)+up*.025,p+d*.29-side_axis*(side*.02)-up*.02],[radius*.32,radius*.28,.011],'keratin',jaw)
    s.organs.append((name,'mouth',0.));s.muzzles[name]=at+d*.23
    return name

def annular(s):
    m=s.spec['morphology'];w=.65*m['width'];h=.74*m['height'];z=h+.65;mode=m['mode'];s.bone('chest',(0,0,.62),(0,0,1.0))
    s.bone('head',(0,-.12,z+.12),(0,-.52,z-.10),'chest')
    loops=2 if mode in [1,7] else 1
    segments=int(m['radial_count'])*2
    for ring in range(loops):
        points=[];offset=V(((ring-.5)*.50 if loops==2 else 0,.18*ring,z))
        for i in range(33):
            a=math.tau*i/32;wave=1+(.10 if mode in [2,8,9] else .035)*math.cos(a*(3 if mode==2 else 2))
            points.append(offset+V((math.cos(a)*w*wave,math.sin(a*2)*(.18 if mode in [5,6] else .035),math.sin(a)*h)))
        s.tube('Continuous annular musculature '+str(ring),points,[.13 if loops==2 else .18]*33,soft=True,steps=3)
        for i in range(segments):
            a=math.tau*i/segments;b=a+math.tau/segments*.88
            p=offset+V((math.cos(a)*w,0,math.sin(a)*h));q=offset+V((math.cos(b)*w,0,math.sin(b)*h));name=f'ring{ring}_{i}'
            s.bone(name,p,q,'chest');s.organs.append((name,'ring',i*.5))
            s.tube('Living annular shield '+name,[p+V((0,.08,0)),(p+q)*.5+V((0,.10,0)),q+V((0,.08,0))],[.09,.13,.06],'shell',name)
        for branch in range(int(m['organ_branch'])):
            side=(branch-(m['organ_branch']-1)/2)*.22;at=V((side,-.58,z-.18-branch*.10))
            s.tube('Hanging inner siphon',[(side,0,z+h*.76),(side,-.08,z+.21),at],[.11,.10,.13],soft=True)
            mouth(s,'siphon'+str(ring)+'_'+str(branch),at,'head',.12)
    supports(s,.77,1.0*m['width'],.3)
    points=[V((math.cos(a)*w,-.17,z+math.sin(a)*h)) for a in np.linspace(0,math.tau,max(segments,m['eye_count']),endpoint=False)]
    senses(s,points,['chest']);s.muzzle=next(iter(s.muzzles.values()))

def radial(s):
    m=s.spec['morphology'];n=int(m['limb_count']);w=m['width'];h=.54*m['height'];s.bone('chest',(0,0,h-.15),(0,0,h+.15));s.bone('head',(0,0,h),(0,-.1,h),'chest',False)
    s.oval('Continuous radial central mantle',(0,0,h),(.51*w,.51*w,.24),soft=True)
    for i,d in enumerate(directions(n)):
        side=V((-d.y,d.x,0));start=d*.32*w+V((0,0,h));name='ray'+str(i);s.bone(name+'_base',start,start+d*.3,'chest');s.organs.append((name+'_base','ray',i*.8))
        radius=(1.34+.09*(m['mode']%3))*w*(1+.08*math.sin(i*2.4));shoulder=d*.52*w+V((0,0,h+.03))
        s.tube('Attached radial shoulder '+name,[start,shoulder,d*.79*w+V((0,0,h*.80))],[.23,.22,.16],soft=True)
        limb(s,name,shoulder,d*radius*.75+V((0,0,h*.55)),d*radius+V((0,0,.10)),d,.14,name+'_base',((i*(n//2 if n%2 else 1))%n)/n)
        for k in range(1+(m['mode']%3)):
            p=d*(.38+k*.20)*w+V((0,0,h+.22-k*.055))
            s.membrane('Overlapping radial armour',[p-side*.18,p+d*.32-side*.20,p+d*.43,p+d*.32+side*.20,p+side*.18],'shell',name+'_base')
        at=d*(radius+.05)+V((0,0,.16));mouth(s,name+'_mouth',at,name+'_foot',.10,d)
    s.oval('Pressure diaphragm',(0,0,h+.22),(.18,.18,.07),'ventral','chest')
    senses(s,[d*.35*w+V((0,0,h+.22)) for d in directions(max(n,m['eye_count']))],['chest']);s.support_height=h;s.muzzle=next(iter(s.muzzles.values()))

def cantilever(s):
    m=s.spec['morphology'];mode=m['mode'];z=.98+.16*m['height'];length=m['neck_length'];s.bone('chest',(0,.30,z),(0,-.25,z+.06))
    s.oval('Suspended visceral chamber',(0,.12,z),(.38*m['width'],.54,.34),soft=True)
    for sign in [-1,1]:
        s.tube('Dorsal suspension arch',[(sign*.3,.55,z),(sign*.46,.28,z+.56),(sign*.38,-.20,z+.60),(sign*.20,-.48,z+.08)],[.11,.14,.12,.06],'shell','chest')
        s.membrane('Flexible load arch web',[(sign*.32,.48,z+.09),(sign*.44,.20,z+.49),(sign*.36,-.17,z+.51),(sign*.23,-.37,z+.07)],'ventral','chest')
    chains=2 if mode in [1,5,7] else 1
    for chain in range(chains):
        x=(chain-.5)*.38 if chains==2 else 0
        points=[(x,-.25,z),(x,-.65,z+.25),(x,-length*.75,z-.02),(x,-length-.45,z-.24)]
        for i in range(3):
            name=f'neck{chain}_{i}';s.bone(name,points[i],points[i+1],'chest' if i==0 else f'neck{chain}_{i-1}');s.organs.append((name,'neck',i*.5+chain*.3))
        s.tube('Continuous suspended neck '+str(chain),points,[.19,.16,.14,.18],soft=True)
        at=V(points[-1])+V((0,-.25,.02));s.oval('Distal jaw muscle '+str(chain),at,(.22,.33,.18),soft=True)
        head=mouth(s,'head' if chain==0 else 'head'+str(chain),at,f'neck{chain}_2',.15)
        for i in range(3):s.tube('Protective neck fold',[V(points[i+1])+V((-.12,.08,.05)),V(points[i+1])+V((0,0,.14)),V(points[i+1])+V((.12,-.08,.05))],[.025,.04,.025],'ventral',f'neck{chain}_{i}')
        senses(s,[at+V((side*.21,-.06,.10)) for side in [-1,1]],[head])
    supports(s,z,.92*m['width'],.30);s.muzzle=s.muzzles['head']

def pressure(s):
    m=s.spec['morphology'];mode=m['mode'];w=.46*m['width'];h=.67*m['height'];base=.78;s.bone('chest',(0,0,.67),(0,0,1.0));s.bone('head',(0,0,base+h*.9),(0,-.08,base+h*1.45),'chest')
    s.oval('Contractile pressure reservoir',(0,0,base+h*.55),(w,w*.86,h),soft=True)
    n=int(m['radial_count']);z=base+h*.6
    for i,d in enumerate(directions(n,0)):
        name='rib'+str(i);s.bone(name,d*w*.6+V((0,0,base-.1)),d*w*.6+V((0,0,base+h*1.35)),'chest');s.organs.append((name,'rib',i*.6))
        s.tube('Curved load rib '+str(i),[d*w*.42+V((0,0,base-.1)),d*w*1.09+V((0,0,z)),d*w*.58+V((0,0,base+h*1.40))],[.075,.115,.065],'shell',name)
        if mode in [2,4,8,9]:s.tube('Growing recurved rib tip',[d*w*.58+V((0,0,base+h*1.40)),d*w*.81+V((0,0,base+h*1.65)),d*w*.36+V((0,0,base+h*1.69))],[.05,.045,.008],'keratin',name)
    tubes=1 if mode not in [1,5,7,9] else (2 if mode!=9 else 3)
    for i in range(tubes):
        x=(i-(tubes-1)/2)*.26;at=V((x,-.12,base+h*1.42));name='valve'+str(i)
        s.tube('Pressure conduit '+str(i),[(x,0,z),(x,-.02,z+h*.5),at],[.15,.12,.16],soft=True)
        mouth(s,name,at,'head',.14,(0,-.4,.9))
    supports(s,.81,.94*m['width'],.28)
    senses(s,[d*w*.86+V((0,-.035,z+.12)) for d in directions(max(4,m['eye_count']))],['chest']);s.muzzle=next(iter(s.muzzles.values()))

def bivalve(s):
    m=s.spec['morphology'];w=.82*m['width'];h=1.05*m['height'];z=.76;s.bone('chest',(0,.35,z),(0,-.35,z));s.bone('head',(0,-.28,z),(0,-.65,z),'chest')
    s.tube('Continuous muscular keel',[(0,.68,z),(0,.15,z+.08),(0,-.52,z+.02),(0,-.77,z-.08)],[.22,.31,.24,.13],soft=True)
    for side in [-1,1]:
        layers=2 if m['mode'] in [5,7,9] else 1
        for j in range(layers):
            name=f'panel{side}_{j}';hinge=V((side*.13,.34-j*.45,z));s.bone(name,hinge,hinge+V((0,-.50,0)),'chest');s.organs.append((name,'panel',side*(1+j*.15)))
            outline=[hinge+V((side*.07,.27,0)),hinge+V((side*w*.63,.18,h*.74)),hinge+V((side*w,.02,h)),hinge+V((side*w*.94,-.47,h*.86)),hinge+V((side*.12,-.60,.05))]
            s.membrane('Thick living valve '+name,outline,'shell',name)
            s.tube('Curved protective valve rim '+name,outline+[outline[0]],[.055]*6,'keratin',name)
            for k in range(int(m['radial_count'])):
                t=(k+1)/(m['radial_count']+1);p=hinge+V((side*.16,-t*.43,0));q=hinge+V((side*w*.83,-t*.35,h*(.71+.13*math.sin(t*math.pi))))
                s.tube('Attached respiratory lamella '+name+str(k),[p,(p+q)*.5+V((side*.045,0,.10)),q],[.065,.045,.012],'ventral',name)
            senses(s,[outline[2]+V((0,-.05,-.10)),outline[3]+V((0,-.02,-.10))],[name])
    mouth(s,'keel_mouth',(0,-.82,z-.05),'head',.17)
    supports(s,.72,.94*m['width'],.22);s.muzzle=s.muzzles['keel_mouth']

def forked(s):
    m=s.spec['morphology'];mode=m['mode'];z=.84+.13*m['height'];w=.56*m['width'];s.bone('chest',(0,.50,z),(0,-.15,z+.06));s.bone('head',(0,-.24,z),(0,-.45,z),'chest',False)
    s.tube('Single rear trunk and fork root',[(0,.70,z),(0,.20,z+.04),(0,-.32,z)],[.22,.37,.29],soft=True)
    for side in [-1,1]:
        length=.95+(.16*mode)%1.05;spread=w*(1.0 if mode not in [4,8] else 1.45);points=[(side*.12,-.22,z),(side*spread,-.55,z+.28),(side*spread*.94,-length,z+.10),(side*spread*.72,-length-.34,z-.08)]
        for i in range(3):
            name=f'fork{side}_{i}';s.bone(name,points[i],points[i+1],'chest' if i==0 else f'fork{side}_{i-1}');s.organs.append((name,'neck',i*.5+(0 if side<0 else .8)))
        s.tube('Continuous bifurcated forebody '+str(side),points,[.22,.17,.16,.20],soft=True)
        at=V(points[-1]);s.oval('Distal feeding muscle '+str(side),at+V((0,-.12,0)),(.23,.32,.19),soft=True)
        mouth(s,'forkmouth'+str(side),at+V((0,-.3,0)),f'fork{side}_2',.16)
        s.membrane('Cervical stabilizing vane '+str(side),[V(points[1])+V((side*.02,.1,.07)),V(points[1])+V((side*.20,.13,.43)),V(points[2])+V((side*.10,0,.15)),V(points[2])+V((0,-.06,.04))],'shell',f'fork{side}_1')
        senses(s,[at+V((side*.18,-.14,.13)),at+V((side*.15,-.02,.18))],[f'fork{side}_2'])
    supports(s,z,.92*m['width'],.29);s.muzzle=s.muzzles['forkmouth-1']

BUILDERS={'annular':annular,'radial':radial,'cantilever':cantilever,'pressure':pressure,'bivalve':bivalve,'forked':forked}

def animate(s):
    p=s.profile;rig=s.arm;scene=bpy.context.scene;scene.render.fps=30;s.actions={}
    states=[('idle_loop',2),('move_loop',2),('run_loop',1.2),('feed',2.4),('attack',2.8),('hurt',.8),('blocked',.9),('stop',.6),('turn_left',1),('turn_right',1),('down',1.2)]
    for state,duration in states:
        rig.animation_data_create();action=bpy.data.actions.new(state);action.use_fake_user=True;rig.animation_data.action=action
        scene.frame_start=1;count=round(duration*30);scene.frame_end=count+1
        for f in range(count+1):
            scene.frame_set(f+1);t=f/30;moving=state in ['move_loop','run_loop'];gait=p['run'] if state=='run_loop' else p;cycle=t/gait['period'] if moving else (t/duration if state=='feed' else t);phase=cycle*math.tau
            for b in rig.pose.bones:b.rotation_mode='XYZ';b.matrix_basis=Matrix.Identity(4)
            forward=t*gait['stride']/gait['stance']/gait['period'] if moving else 0
            wind=pulse(t,0,.78,1.18) if state=='attack' else 0
            strike=pulse(t,.88,1.08,1.36) if state=='attack' else 0
            hurt=pulse(t,0,.09,duration) if state in ['hurt','blocked'] else 0
            down=smooth(0,1.1,t) if state=='down' else 0
            root_z=(.012*math.cos(phase*2) if moving else .006*math.sin(phase))-.05*wind-s.support_height*.40*down
            root=V((0,-forward,root_z));s.local('root',location=s.binds['root'].to_3x3().inverted()@root)
            s.local('chest',(-.12*hurt,0,.09*hurt+.14*down),scale=(1+.012*math.sin(phase),1+.012*math.sin(phase),1-.012*math.sin(phase)))
            for name,role,offset in s.organs:
                if role=='ring':s.local(name,(0,.020*math.sin(phase-offset),.012*math.sin(phase-offset)),scale=(1+.035*wind,1,1+.035*wind))
                elif role=='neck':s.local(name,((.18 if int(offset*2)%2==0 else -.22)*wind+(.16 if int(offset*2)%2 else -.14)*strike,0,.015*math.sin(phase-offset)))
                elif role=='mouth':s.local(name,(.10*wind-.08*strike,0,.035*math.sin(phase-offset) if state=='feed' else 0))
                elif role=='panel':s.local(name,(0,offset*(.06*math.sin(phase)+.26*wind-.36*strike+(.18*(.5+.5*math.sin(phase)) if state=='feed' else 0)),0))
                elif role=='rib':s.local(name,(.04*math.sin(phase-offset),0,0),scale=(1+.10*wind,1+.10*wind,1))
                elif role=='ray':s.local(name,(0,.02*math.sin(phase-offset),.035*wind))
            for i,name in enumerate(s.jaws):s.local(name,(0,0,(-1 if i%2 else 1)*(.14*wind-.26*strike+(.18*(.5+.5*math.sin(phase*2-i)) if state=='feed' else 0))))
            for leg in s.legs:
                foot=V(leg['foot']);fraction=(cycle+leg['phase'])%1
                if moving:
                    foot.y+=-forward+((-.5+fraction/gait['stance'])*gait['stride'] if fraction<gait['stance'] else (.5-smooth(0,1,(fraction-gait['stance'])/(1-gait['stance'])))*gait['stride'])
                    if fraction>=gait['stance']:foot.z+=math.sin((fraction-gait['stance'])/(1-gait['stance'])*math.pi)*(.13 if state=='run_loop' else .09)
                if state.startswith('turn_'):foot.z+=max(0,math.sin((t+leg['phase'])*math.tau))*.09
                if state=='attack' and s.spec['kind']=='radial' and leg['name']=='ray0':foot.z+=.34*pulse(t,.40,.78,1.04)
                s.solve_leg(leg,foot)
            s.local('root',location=s.binds['root'].to_3x3().inverted()@V((0,0,root_z)))
            for b in rig.pose.bones:
                for prop in ['location','rotation_euler','scale']:b.keyframe_insert(data_path=prop,frame=f+1,group=b.name)
        s.actions[state]=action;rig.animation_data.action=None
    rig.animation_data.action=s.actions['idle_loop'];scene.frame_set(1)

def fingerprint(spec):
    h=hashlib.sha256(json.dumps(spec,sort_keys=True).encode())
    for file in [Path(__file__),Path(__file__).with_name('recipes.py'),ROOT/'tools/build_creature_studies.py',ROOT/'tools/build_creature_remodel_r01.py']:
        h.update(file.read_bytes())
    return h.hexdigest()

def source_render(s):
    scene=bpy.context.scene;scene.frame_set(1);bpy.context.view_layer.update()
    points=[o.matrix_world@V(p) for o in bpy.context.scene.objects if o.type=='MESH' for p in o.bound_box];lo=V(tuple(min(p[i] for p in points) for i in range(3)));hi=V(tuple(max(p[i] for p in points) for i in range(3)));center=(lo+hi)*.5;size=max(hi-lo)
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.04));bpy.context.object.data.materials.append(ink.material('structural_dark'))
    bpy.ops.object.camera_add(location=center+V((1.2,-1.7,1.1)).normalized()*size*3);cam=bpy.context.object;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=size*1.6;scene.camera=cam
    scene.world=bpy.data.worlds.new('Studio');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.20,.23,.28,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.5
    for offset,energy in [((1,-1.5,2),130),((-1,-.2,.8),60),((.5,1.3,1.4),100)]:
        bpy.ops.object.light_add(type='AREA',location=center+V(offset)*size);lamp=bpy.context.object;lamp.data.energy=energy*size*size;lamp.data.size=size*1.1;lamp.rotation_euler=(center-lamp.location).to_track_quat('-Z','Y').to_euler()
    scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True;scene.render.resolution_x=640;scene.render.resolution_y=560;scene.render.resolution_percentage=100
    scene.render.filepath=str(MEDIA/'blender'/(s.spec['id']+'.png'));bpy.ops.render.render(write_still=True)

def build(spec):
    stamp=fingerprint(spec);metadata=SRC/(spec['id']+'.json')
    if metadata.exists():
        old=json.loads(metadata.read_text())
        if old.get('build_fingerprint')==stamp and (ROOT/old['source']).exists() and (MEDIA/'blender'/(spec['id']+'.png')).exists() and all((ROOT/l['path']).exists() and hashlib.sha256((ROOT/l['path']).read_bytes()).hexdigest()==l['sha256'] for l in old['lods'].values()):
            print('BATCH_SKIP',spec['id'],flush=True);return old
    start=time.monotonic();s=AnatomicalStudy(spec);s.organs=[];s.muzzles={};BUILDERS[spec['kind']](s)
    s.fuse_skin();s.rig();s.socket_bindings={};socket(s,'Socket_Muzzle','head',s.muzzle)
    # Bind each actual distal organ, including both heads; the primary muzzle uses its own bone.
    for name,point in s.muzzles.items():socket(s,'Socket_'+name,name,point)
    primary=next(iter(s.muzzles));socket(s,'Socket_Muzzle',primary,s.muzzles[primary]);socket(s,'Socket_Strike',primary,s.muzzles[primary])
    for leg in s.legs:socket(s,'Socket_'+leg['name'],leg['name']+'_foot',leg['foot'])
    average=sum(l['upper']+l['lower'] for l in s.legs)/len(s.legs);stride=min(.40,average*.32)
    s.profile=dict(duration=2.8,prepare=.78,release=[1.08],active_end=1.36,settle=2.64,travel=0,stride=stride,stance=.73,period=1.0,run=dict(stride=stride*1.55,stance=.70,period=.60),limb_phases={l['name']:l['phase'] for l in s.legs})
    animate(s);bpy.context.view_layer.update()
    source=SRC/(spec['id']+'.blend');bpy.ops.wm.save_as_mainfile(filepath=str(source))
    points=np.array([tuple(ob.matrix_world@v.co) for ob in bpy.context.scene.objects if ob.type=='MESH' for v in ob.data.vertices]);points=(points-points.min(axis=0))/max(np.ptp(points,axis=0));normalized_hash=hashlib.sha256(np.round(points,5).tobytes()).hexdigest()
    row={**spec,'version':VERSION,'build_fingerprint':stamp,'normalized_geometry_sha256':normalized_hash,'source':str(source.relative_to(ROOT)),'status':'built-awaiting-game-render','bone_count':len(s.bones),'locomotion_chains':len(s.legs),'clips':list(s.actions),'sockets':s.socket_bindings,'motion_profile':s.profile,'muzzle':[s.muzzle.x,s.muzzle.z,-s.muzzle.y],'lods':{},'skeleton_topology':{n:d['parent'] for n,d in s.bones.items()}}
    biota_rig.consolidate()
    for lod in ['near','far']:
        if lod=='far':
            s.arm.data.pose_position='REST'
            for ob in list(bpy.context.scene.objects):
                if ob.type!='MESH' or len(ob.data.polygons)<160:continue
                bpy.context.view_layer.objects.active=ob;mod=ob.modifiers.new('Approved far budget','DECIMATE');mod.ratio=.43;bpy.ops.object.modifier_apply(modifier=mod.name)
            s.arm.data.pose_position='POSE'
        path=OUT/(spec['id']+'_'+lod+'.glb');bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',export_yup=True,export_animations=True,export_animation_mode='ACTIONS',export_merge_animation='ACTION',export_force_sampling=True,export_frame_range=False,export_cameras=False,export_lights=False)
        pts=[];triangles=0
        for ob in bpy.context.scene.objects:
            if ob.type=='MESH':ob.data.calc_loop_triangles();triangles+=len(ob.data.loop_triangles);pts.extend(ob.matrix_world@v.co for v in ob.data.vertices)
        pts=[(p.x,p.z,-p.y) for p in pts];row['lods'][lod]=dict(path=str(path.relative_to(ROOT)),sha256=hashlib.sha256(path.read_bytes()).hexdigest(),triangles=triangles,min=[min(p[i] for p in pts) for i in range(3)],max=[max(p[i] for p in pts) for i in range(3)])
    row['build_seconds']=round(time.monotonic()-start,3)
    bpy.ops.wm.open_mainfile(filepath=str(source));s.arm=bpy.data.objects['StudySkeleton'];source_render(s)
    row['source_render_seconds']=round(time.monotonic()-start-row['build_seconds'],3)
    metadata.write_text(json.dumps(row,ensure_ascii=False,indent=2)+'\n');print('BATCH_BUILT',spec['id'],row['bone_count'],row['build_seconds'],row['source_render_seconds'],flush=True);return row

if __name__=='__main__':
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    for spec in recipes():
        if not args or spec['id'] in args or spec['family'] in args:build(spec)
    rows=[json.loads(p.read_text()) for p in sorted(SRC.glob('bio_*.json'))]
    (ROOT/'우주-비즈니스/data/creature_remodel_r02.json').write_text(json.dumps({'version':1,'scope':'Incrementally built anatomy assets; runtime enablement is separate','forms':rows},ensure_ascii=False,indent=2)+'\n')
