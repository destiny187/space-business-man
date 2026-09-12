"""Six authored movement/attack studies. Never rewrites the native species catalog.
Blender CLI: --background --python tools/build_creature_studies.py -- [id]
Editable source -> real skin/rig/clips -> two game LODs -> source render.
"""
from pathlib import Path
import sys, math, json, hashlib
import bpy
import numpy as np
from mathutils import Vector, Matrix, Quaternion

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT/'tools'), str(ROOT/'tools/bestiary')]
import ink_blender as ink
import biota_rig

SRC = ROOT/'art/blender/creature_studies'
OUT = ROOT/'우주-비즈니스/assets/models/creature_studies'
MEDIA = ROOT/'docs/production/media/creature-studies'
for p in [SRC, OUT, MEDIA/'blender']: p.mkdir(parents=True, exist_ok=True)
TAU = math.tau
V = Vector
SPECS = [
    dict(id='sailhorn',name='갈래돛 초식수',kind='quadruped',source_id='biota_spindle_armor_25',habitat='건조 분지 · 여과뿔과 저수 피부',attack='ram',palette=['79615b','c3ad7f','344f49','d5be87']),
    dict(id='shearprowler',name='여섯발 그늘사냥꾼',kind='hexapod',source_id='biota_lobopod_armor_26',habitat='열수림 · 낮은 매복과 감각 수염',attack='scythe',palette=['355a61','779786','253843','bb915c']),
    dict(id='pressureurn',name='숨항아리 포격수',kind='tripod',source_id='bio_quill_amphora_01',habitat='염류 분지 · 압력낭과 골질 늑판',attack='mortar',palette=['787c89','d2c6a3','3e5260','d28858']),
    dict(id='vaulthopper',name='접등 도약수',kind='hopper',source_id='biota_chain_armor_26',habitat='저중력 암지 · 탄성 뒷다리와 완충등',attack='slam',palette=['ad7346','e2c98c','4a5960','648b7a']),
    dict(id='reedserpent',name='갈대막 분사수',kind='serpent',source_id='biota_ribbon_armor_26',habitat='산성 습지 · 점액 복면과 세갈래 구강',attack='spit',palette=['496e64','b9bc86','354548','c9866d']),
    dict(id='veilglider',name='겹막 활공수',kind='glider',source_id='biota_bilateral_armor_11',habitat='고압 대기 · 두 쌍의 막날개와 조향 꼬리',attack='dart',palette=['635569','b89691','344f57','d6b87e']),
]

def linear(hexcolor):
    a=[int(hexcolor[i:i+2],16)/255 for i in (0,2,4)]
    return [v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in a]

def material(name,color,rough=.7):
    m=bpy.data.materials.new('Study_'+name); m.diffuse_color=(*linear(color),1);m.use_nodes=True
    p=m.node_tree.nodes['Principled BSDF'];p.inputs['Base Color'].default_value=m.diffuse_color;p.inputs['Roughness'].default_value=rough
    return m

class Study:
    def __init__(self,spec):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        self.spec=spec;self.meshes=[];self.soft=[];self.bones={};self.legs=[];self.flex=[];self.wings=[];self.lids=[];self.jaws=[]
        self.mats={k:material(k,c,r) for k,c,r in [('skin',spec['palette'][0],.76),('ventral',spec['palette'][1],.82),('shell',spec['palette'][2],.56),('keratin',spec['palette'][3],.46),('mouth','472e37',.24),('dark','151f26',.8),('iris','bc9e58',.23)]}
        self.bone('root',(0,0,0),(0,0,.2),None,False)

    def bone(self,name,a,b,parent='root',deform=True):
        self.bones[name]=dict(a=V(a),b=V(b),parent=parent,deform=deform)
        return name

    def finish(self,ob,name,slot='skin',bone=None,soft=False):
        ob.name=name;ob.data.materials.append(self.mats[slot])
        for p in ob.data.polygons:p.use_smooth=True
        ob['bind_bone']=bone or '';ob['soft_tissue']=soft
        self.meshes.append(ob)
        if soft:self.soft.append(ob)
        return ob

    def oval(self,name,p,s,slot='skin',bone=None,soft=False,seg=32,rings=20):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=seg,ring_count=rings,location=p)
        o=bpy.context.object;o.scale=s;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        return self.finish(o,name,slot,bone,soft)

    def tube(self,name,points,radii,slot='skin',bone=None,soft=False,sides=16,steps=5,flat=1.0):
        pts=[V(p) for p in points]; sample=[]; rs=[]
        for i in range(len(pts)-1):
            p0=pts[max(0,i-1)];p1=pts[i];p2=pts[i+1];p3=pts[min(len(pts)-1,i+2)]
            for j in range(steps):
                t=j/steps;sample.append(.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t*t*t));rs.append(radii[i]*(1-t)+radii[i+1]*t)
        sample.append(pts[-1]);rs.append(radii[-1]);verts=[];faces=[]
        previous_x=None;previous_tangent=None
        for i,p in enumerate(sample):
            tangent=(sample[min(i+1,len(sample)-1)]-sample[max(0,i-1)]).normalized()
            if previous_x is None:
                ref=V((0,0,1)) if abs(tangent.z)<.9 else V((0,1,0));x=tangent.cross(ref).normalized()
            else:
                x=previous_tangent.rotation_difference(tangent)@previous_x
                x=(x-tangent*x.dot(tangent)).normalized()
            y=tangent.cross(x).normalized();previous_x=x;previous_tangent=tangent
            for k in range(sides):
                angle=k*TAU/sides;verts.append(p+rs[i]*(x*math.cos(angle)+y*math.sin(angle)*flat))
        for j in range(len(sample)-1):
            for k in range(sides):a=j*sides+k;b=j*sides+(k+1)%sides;faces.append((a,b,b+sides,a+sides))
        faces += [tuple(reversed(range(sides))),tuple((len(sample)-1)*sides+k for k in range(sides))]
        return self.mesh(name,verts,faces,slot,bone,soft)

    def mesh(self,name,verts,faces,slot='skin',bone=None,soft=False):
        data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.update()
        ob=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(ob)
        return self.finish(ob,name,slot,bone,soft)

    def membrane(self,name,outline,slot='ventral',bone=None):
        # Curved fan with real thickness, broad unbroken colour planes.
        pts=[V(x) for x in outline];center=sum(pts,V())/len(pts);verts=[center+V((0,0,.055))];faces=[]
        for p in pts:verts.append(p)
        for i in range(len(pts)):faces.append((0,i+1,(i+1)%len(pts)+1))
        o=self.mesh(name,verts,faces,slot,bone)
        sub=o.modifiers.new('Soft membrane surface','SUBSURF');sub.levels=2
        solid=o.modifiers.new('Living membrane thickness','SOLIDIFY');solid.thickness=.025
        return o

    def eye(self,name,p,side,scale=.11,bone='head',slit=True):
        # Small protected sensory lens; the socket belongs to the skull silhouette.
        p=V(p);out=V((side*.75,-.66,.12)).normalized();rotation=V((1,0,0)).rotation_difference(out)
        for label,offset,shape,slot in [('orbital recess',.016,(scale*.32,scale,scale*.72),'dark'),('inset lens',.044,(scale*.23,scale*.80,scale*.58),'iris'),('aperture',.063,(scale*.10,scale*.62 if slit else scale*.37,scale*.14 if slit else scale*.35),'dark')]:
            ob=self.oval(name+' '+label,p+out*offset,shape,slot,bone);ob.rotation_mode='QUATERNION';ob.rotation_quaternion=rotation
        lidname=name+'_lid';self.bone(lidname,p+V((0,0,scale*.45)),p+V((side*.06,-.04,scale*.45)),bone)
        self.tube(name+' muscular brow',[p+out*.020+V((0,-scale,.025)),p+out*.022+V((0,0,scale*.77)),p+V((0,scale,.025))],[scale*.19,scale*.26,scale*.15],'skin',lidname)
        self.lids.append(lidname)

    def leg(self,name,hip,knee,foot,width=.15,parent='chest',phase=0,style='pad'):
        hip=V(hip);knee=V(knee);foot=V(foot)
        self.bone(name+'_upper',hip,knee,parent);self.bone(name+'_lower',knee,foot,name+'_upper');self.bone(name+'_foot',foot,foot+V((0,-.25,0)),name+'_lower')
        self.tube(name+' continuous muscle',[hip,knee,foot],[width*1.4,width*.75,width*.40],soft=True)
        self.oval(name+' attached muscle',(hip*2+knee)/3,(width*1.5,width*1.3,width*2.0),soft=True)
        if style=='hoof':
            for side in [-1,1]:self.oval(name+' cloven weight pad',foot+V((side*.058,-.06,-.006)),(.061,.17,.095),'keratin',name+'_foot')
        elif style=='hook':
            self.tube(name+' curved tarsal grip',[foot,foot+V((0,-.14,0)),foot+V((0,-.34,.03))],[.11,.075,.009],'keratin',name+'_foot')
        else:
            self.oval(name+' metatarsal pad',foot+V((0,-.045,0)),(width*.95,width*1.55,.08),'ventral',name+'_foot')
            for n in [-1,0,1]:self.tube(name+' tension toe',[foot+V((n*width*.55,-.06,0)),foot+V((n*width*.8,-.20,0)),foot+V((n*width*.85,-.32,.012))],[.06,.04,.008],'keratin',name+'_foot')
        self.legs.append(dict(name=name,hip=list(hip),knee=list(knee),foot=list(foot),parent=parent,phase=phase,upper=(hip-knee).length,lower=(knee-foot).length))

    def tail(self,points,radii,parent='pelvis',prefix='tail'):
        for i in range(len(points)-1):self.bone(prefix+str(i),points[i],points[i+1],parent if i==0 else prefix+str(i-1))
        self.tube('Continuous '+prefix,points,radii,soft=True)
        self.flex += [prefix+str(i) for i in range(len(points)-1)]

    def torso(self,points,radii):
        names=['pelvis','chest','neck','head']
        for i in range(len(points)-1):self.bone(names[i],points[i],points[i+1],'root' if i==0 else names[i-1])
        self.tube('Axial tissue',points,radii,soft=True)

    def fuse_skin(self):
        bpy.ops.object.select_all(action='DESELECT')
        for o in self.soft:o.select_set(True)
        bpy.context.view_layer.objects.active=self.soft[0];bpy.ops.object.join();skin=bpy.context.object
        bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
        skin.name='Continuous skin with anatomical attachments'
        rem=skin.modifiers.new('Fused anatomical volume','REMESH');rem.mode='VOXEL';rem.voxel_size=.036;rem.use_smooth_shade=True
        bpy.ops.object.modifier_apply(modifier=rem.name)
        smooth=skin.modifiers.new('Tissue continuity','SMOOTH');smooth.factor=1.2;smooth.iterations=5;bpy.ops.object.modifier_apply(modifier=smooth.name)
        dec=skin.modifiers.new('Surface budget','DECIMATE');dec.ratio=.38;bpy.ops.object.modifier_apply(modifier=dec.name)
        for p in skin.data.polygons:p.use_smooth=True
        skin.data.materials.clear();mat=material('skin_vertex_paint','ffffff',.76);skin.data.materials.append(mat)
        attr=skin.data.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='POINT')
        a=np.array(linear(self.spec['palette'][0]));b=np.array(linear(self.spec['palette'][1]));c=np.array(linear(self.spec['palette'][2]))
        coords=np.array([v.co[:] for v in skin.data.vertices]); lo=coords[:,2].min(); hi=coords[:,2].max()
        for i,p in enumerate(coords):
            vent=max(0,min(.70,(.46-(p[2]-lo)/max(.1,hi-lo))*1.5))
            marking=max(0,math.sin(p[1]*5.5+abs(p[0])*2.7)-.48)*.90 if p[2]>lo+(hi-lo)*.45 else 0
            col=(a*(1-vent)+b*vent)*(1-marking)+c*marking;attr.data[i].color=(*col,1)
        nodes=mat.node_tree.nodes;vc=nodes.new('ShaderNodeVertexColor');vc.layer_name='Color';mat.node_tree.links.new(vc.outputs['Color'],nodes['Principled BSDF'].inputs['Base Color'])
        self.skin=skin

    def rig(self):
        arm=bpy.data.armatures.new(self.spec['id']+'_anatomy');rig=bpy.data.objects.new('StudySkeleton',arm);bpy.context.collection.objects.link(rig)
        bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig;bpy.ops.object.mode_set(mode='EDIT')
        for name,data in self.bones.items():
            b=arm.edit_bones.new(name);b.head=data['a'];b.tail=data['b'];b.use_deform=data['deform']
            if data['parent']:b.parent=arm.edit_bones[data['parent']]
        bpy.ops.object.mode_set(mode='OBJECT');self.arm=rig;rig.show_in_front=True
        for ob in list(bpy.context.scene.objects):
            if ob.type!='MESH':continue
            bpy.context.view_layer.objects.active=ob
            for mod in list(ob.modifiers):bpy.ops.object.modifier_apply(modifier=mod.name)
            matrix=ob.matrix_world.copy();ob.data.transform(matrix);ob.matrix_world=Matrix.Identity(4);ob.parent=rig
            bind=ob.get('bind_bone','')
            if bind:
                ob.vertex_groups.new(name=bind).add(list(range(len(ob.data.vertices))),1.0,'REPLACE')
            else:
                names=[n for n,d in self.bones.items() if d['deform'] and not any(s in n for s in ['lid','jaw','petal','finger','antenna'])]
                vs=np.array([v.co[:] for v in ob.data.vertices]);ds=[]
                for n in names:
                    a=np.array(self.bones[n]['a']);b=np.array(self.bones[n]['b']);delta=b-a
                    t=np.clip(((vs-a)*delta).sum(axis=1)/(delta*delta).sum(),0,1)
                    ds.append(((vs-a-t[:,None]*delta)**2).sum(axis=1))
                ds=np.array(ds).T;nearest=np.argsort(ds,axis=1)[:,:3];weights=1/np.maximum(np.take_along_axis(ds,nearest,axis=1),.001)**2;weights/=weights.sum(axis=1)[:,None]
                groups=[ob.vertex_groups.new(name=n) for n in names];batches={}
                for i,(ns,ws) in enumerate(zip(nearest,weights)):
                    for n,w in zip(ns,ws):
                        quant=round(float(w)*256)
                        if quant:batches.setdefault((int(n),quant),[]).append(i)
                for (n,w),indices in batches.items():groups[n].add(indices,w/256,'REPLACE')
            mod=ob.modifiers.new('Anatomical skin','ARMATURE');mod.object=rig;mod.use_deform_preserve_volume=True
        # Real muzzle binding for the review's timed projectile releases.
        muzzle=bpy.data.objects.new('Socket_Muzzle',None);bpy.context.collection.objects.link(muzzle);muzzle.parent=rig;muzzle.parent_type='BONE';muzzle.parent_bone='head'
        bpy.context.view_layer.update();muzzle.matrix_world=Matrix.Translation(self.muzzle)
        self.binds={n:rig.data.bones[n].matrix_local.copy() for n in self.bones}

    def local(self,name,angle=(0,0,0),location=(0,0,0),scale=(1,1,1)):
        p=self.arm.pose.bones[name];p.rotation_mode='XYZ';p.rotation_euler=angle;p.location=location;p.scale=scale

    def aim_bone(self,name,a,b):
        a=V(a);b=V(b);rest=self.binds[name];direction=(b-a).normalized()
        # Absolute pose matrix retains rest roll, with its Y axis directed to endpoint.
        old=(self.bones[name]['b']-self.bones[name]['a']).normalized()
        q=old.rotation_difference(direction)@rest.to_quaternion()
        self.arm.pose.bones[name].matrix=Matrix.LocRotScale(a,q,V((1,1,1)))

    def solve_leg(self,leg,foot):
        name=leg['name'];parent=leg['parent'];p=self.arm.pose.bones[parent].matrix@self.binds[parent].inverted()
        hip=p@V(leg['hip']);restknee=p@V(leg['knee']);goal=V(foot);d=goal-hip
        length=min(max(d.length,abs(leg['upper']-leg['lower'])+.002),leg['upper']+leg['lower']-.002);direction=d.normalized()
        along=(leg['upper']**2-leg['lower']**2+length**2)/(2*length)
        pole=restknee-hip;pole-=direction*pole.dot(direction)
        if pole.length<.001:pole=direction.cross(V((1,0,0)))
        knee=hip+direction*along+pole.normalized()*math.sqrt(max(0,leg['upper']**2-along**2));goal=hip+direction*length
        self.aim_bone(name+'_upper',hip,knee);bpy.context.view_layer.update();self.aim_bone(name+'_lower',knee,goal);bpy.context.view_layer.update();self.aim_bone(name+'_foot',goal,goal+V((0,-.25,0)))

def sailhorn(s):
    s.torso([(0,.80,1.36),(0,.12,1.48),(0,-.55,1.72),(0,-1.05,2.27),(0,-1.61,2.30)],[.36,.47,.36,.23,.15])
    for p,scale in [((0,.65,1.40),(.46,.50,.40)),((0,-.13,1.45),(.52,.70,.58)),((0,-.50,1.35),(.35,.34,.54)),((0,-1.30,2.30),(.28,.43,.25))]:s.oval('Fused thorax pelvis and skull',p,scale,soft=True)
    for side in [-1,1]:
        s.leg('fore'+str(side),(side*.39,-.43,1.48),(side*.48,-.24,.76),(side*.48,-.54,.11),.15,'chest',0 if side<0 else .5,'hoof')
        s.leg('hind'+str(side),(side*.37,.76,1.36),(side*.51,1.00,.77),(side*.45,.69,.11),.19,'pelvis',.75 if side<0 else .25,'hoof')
        s.eye('Lateral'+str(side),(side*.255,-1.39,2.38),side,.092)
        s.tube('Raised bony filtering crest',[(side*.17,-1.10,2.43),(side*.36,-.95,2.72),(side*.68,-1.05,2.94),(side*.82,-1.30,2.88)],[.11,.09,.055,.013],'keratin','head')
        s.membrane('Crescent filter sail',[(side*.24,-1.09,2.52),(side*.51,-.92,2.85),(side*.81,-1.3,2.90),(side*.50,-1.20,2.48)],'ventral','head')
        for k in range(3):s.tube('Protective neck gill fold',[(side*.20,-.80-k*.07,1.92+k*.09),(side*.29,-.85-k*.10,2.00+k*.10),(side*.18,-.95-k*.11,2.06+k*.10)],[.045,.065,.02],'ventral','neck')
        s.oval('Respiratory slit',(side*.095,-1.72,2.28),(.045,.023,.025),'dark','head')
    s.bone('jaw',(0,-1.33,2.17),(0,-1.70,2.17),'head');s.jaws=['jaw']
    s.tube('Flexible lower lip',[(0,-1.27,2.14),(0,-1.58,2.12),(0,-1.79,2.20)],[.15,.14,.06],'ventral','jaw',flat=.6)
    s.tail([(0,.93,1.36),(0,1.33,1.22),(0,1.71,1.34),(0,2.02,1.58)],[.17,.14,.08,.012])
    for i in range(3):
        y=.55-i*.36;s.membrane('Backward heat shedding lamina',[(0,y-.28,1.76),(0,y,2.04),(0,y+.37,1.88),(.08,y+.13,1.68)],'shell','pelvis' if i==0 else 'chest')
    s.muzzle=V((0,-1.80,2.24))

def shearprowler(s):
    s.torso([(0,.78,.84),(0,.15,.99),(0,-.57,1.00),(0,-1.02,.93),(0,-1.53,.77)],[.27,.42,.36,.26,.14])
    s.oval('Continuous low muscular trunk',(0,.0,.86),(.51,.94,.34),soft=True)
    s.oval('Keel shaped skull',(0,-1.15,.86),(.36,.49,.24),soft=True)
    for side in [-1,1]:
        for i,y in enumerate([-.63,.13,.75]):
            s.leg('leg'+str(i)+'_'+str(side),(side*.40,y,.88),(side*.81,y-.19+ i*.12,.53),(side*.96,y-.23+i*.11,.09),.13 if i else .17,'chest' if i<2 else 'pelvis',(.0 if side<0 else .5)+(i%2)*.5,'hook')
        for i in range(2):s.eye('Recessed'+str(side)+'_'+str(i),(side*(.27+i*.025),-1.26+i*.14,1.01-i*.035),side,.082-i*.013,slit=False)
        name='jaw'+str(side);s.bone(name,(side*.25,-1.19,.79),(side*.40,-1.74,.74),'head');s.jaws.append(name)
        s.tube('Opposing hooked mouthpart',[(side*.25,-1.19,.79),(side*.44,-1.55,.67),(side*.30,-1.89,.78),(side*.09,-1.79,.83)],[.12,.12,.07,.012],'keratin',name)
        for k in range(3):s.tube('Mandible inner tooth',[(side*(.39-k*.05),-1.47-k*.12,.76),(side*(.22-k*.025),-1.51-k*.12,.83)],[.044,.003],'ventral',name)
        s.tube('Forward tactile whisker',[(side*.30,-1.02,1.02),(side*.50,-1.49,1.10),(side*.73,-1.70,.97)],[.045,.027,.006],'ventral','head')
        for i in range(4):
            y=.8-i*.35;s.membrane('Lapped lateral carapace',[(side*.12,y-.25,1.19),(side*.43,y-.21,1.09),(side*.64,y+.16,.76),(side*.32,y+.24,1.09)],'shell','pelvis' if i==0 else 'chest')
    s.tail([(0,.85,.84),(0,1.26,.74),(0,1.67,.87),(0,2.06,1.05),(0,2.35,.95)],[.22,.17,.11,.07,.01])
    s.membrane('Balance tail vane',[(-.05,1.68,.87),(-.33,2.19,.99),(0,2.40,.96),(.33,2.19,.99),(.05,1.68,.87)],'shell','tail2')
    s.muzzle=V((0,-1.77,.83))

def pressureurn(s):
    s.torso([(0,0,.70),(0,0,1.10),(0,0,1.70),(0,0,2.12),(0,0,2.56)],[.29,.42,.38,.25,.19])
    s.oval('Contractile pressure organ',(0,0,1.50),(.57,.51,.71),soft=True)
    for i in range(3):
        angle=TAU*i/3+math.pi/2;axis=V((math.cos(angle),math.sin(angle),0))
        h=axis*.31+V((0,0,.92));k=axis*.78+V((0,0,.63));f=axis*.96+V((0,0,.1))
        s.leg('tripod'+str(i),h,k,f,.19,'pelvis',i/3,'pad')
    for i in range(6):
        a=TAU*i/6;axis=V((math.cos(a),math.sin(a),0));side=V((-math.sin(a),math.cos(a),0))
        points=[axis*.25+V((0,0,.83)),axis*.55+V((0,0,1.15)),axis*.64+V((0,0,1.72)),axis*.36+V((0,0,2.21))]
        s.tube('Curved protective urn rib',points,[.16,.17,.14,.075],'shell','chest',flat=.58)
        s.membrane('Overlapping bone panel',[points[0],points[1]+side*.21,points[2]+side*.21,points[3],points[2]-side*.21,points[1]-side*.21],'ventral','chest')
    for z,rad in [(2.20,.42),(2.43,.50)]:
        points=[(rad*math.cos(i*TAU/36),rad*math.sin(i*TAU/36),z+.025*math.sin(i*TAU/12)) for i in range(37)]
        s.tube('Living trumpet rim',points,[.064]*37,'keratin','head',steps=2)
    s.oval('Dark pressure opening',(0,0,2.39),(.38,.38,.08),'mouth','head')
    for i in range(3):
        a=TAU*i/3;axis=V((math.cos(a),math.sin(a),0));side=V((-math.sin(a),math.cos(a),0));p=axis*.38+V((0,0,2.41));name='petal'+str(i)
        s.bone(name,p,p-axis*.3+V((0,0,.08)),'head');s.jaws.append(name)
        s.membrane('Muscular muzzle valve',[p-side*.22,p+axis*.15+V((0,0,.20)),p+side*.22,V((0,0,2.53))],'skin',name)
        s.oval('Protected vibration slit',axis*.49+V((0,0,1.99)),(.06,.085,.018),'dark','head')
    s.muzzle=V((0,0,2.53))

def vaulthopper(s):
    s.torso([(0,.55,.70),(0,.04,.95),(0,-.45,.89),(0,-.76,.78),(0,-1.10,.72)],[.35,.42,.30,.26,.16])
    s.oval('Spring loaded pelvis',(0,.38,.65),(.57,.61,.41),soft=True)
    s.oval('Low wedge skull',(0,-.74,.73),(.43,.42,.23),soft=True)
    for side in [-1,1]:
        s.leg('hind'+str(side),(side*.43,.42,.75),(side*.74,-.03,.47),(side*.58,.54,.09),.24,'pelvis',0,'pad')
        name='antenna'+str(side);s.bone(name,(side*.27,-.45,.87),(side*.52,-.98,.53),'neck')
        s.tube('Balancing tactile arm',[(side*.27,-.45,.87),(side*.53,-.71,.56),(side*.57,-1.10,.49)],[.09,.062,.018],'ventral',name)
        for i in range(3):s.eye('Shield ocellus'+str(side)+str(i),(side*(.17+i*.10),-1.01+i*.11,.85),side,.063-i*.007,slit=False)
        for i in range(3):
            y=.62-i*.31;s.membrane('Spring shell lamella',[(side*.1,y-.2,1.18),(side*.40,y-.20,1.49-i*.035),(side*.70,y+.18,1.07),(side*.51,y+.24,.88)],'shell','pelvis' if i==0 else 'chest')
        s.tube('Shell tendinous arch',[(side*.40,.78,.77),(side*.59,.58,1.19),(side*.44,.10,1.52),(side*.18,-.16,1.23)],[.10,.11,.085,.035],'keratin','chest')
    s.bone('jaw',(0,-.65,.62),(0,-1.10,.63),'head');s.jaws=['jaw'];s.oval('Wide flexible lower lip',(0,-.84,.59),(.34,.24,.064),'ventral','jaw')
    s.tail([(0,.76,.73),(0,1.14,.43),(0,1.43,.21)],[.20,.13,.018])
    s.muzzle=V((0,-1.11,.70))

def reedserpent(s):
    s.torso([(0,.15,.34),(0,-.35,.46),(0,-.79,.50),(0,-1.13,.46),(0,-1.55,.40)],[.27,.32,.25,.25,.14])
    pts=[(math.sin(i*.63)*.17,.10+i*.37,.32-i*.016) for i in range(9)]
    s.tail(pts,[.27,.28,.27,.24,.21,.17,.13,.085,.012],prefix='tail')
    s.oval('Shielded broad sensory head',(0,-1.22,.46),(.43,.42,.18),soft=True)
    for side in [-1,1]:
        s.oval('Paired venom storage sac',(side*.23,-.58,.40),(.23,.28,.19),soft=True)
        for i in range(3):s.oval('Inlaid thermosensory pore',(side*(.32+i*.02),-1.29+i*.10,.54),(.022,.04,.018),'dark','head')
        for i in range(7):
            y=.26+i*.38;x=math.sin((i+.5)*.63)*.17
            s.membrane('Continuous dorsal ribbon lobe',[(x,y-.20,.50-i*.016),(x+side*.34,y+.04,.92-i*.05),(x+side*.22,y+.37,.68-i*.03),(x,y+.35,.49-i*.016)],'ventral','tail'+str(min(i,7)))
    for i in range(3):
        a=TAU*i/3;axis=V((math.cos(a),0,math.sin(a)));base=V((0,-1.40,.43))+axis*.17;name='jaw'+str(i)
        s.bone(name,base,base+V((0,-.34,0)),'head');s.jaws.append(name)
        s.tube('Three way prehensile jaw',[base,base+V((0,-.24,0))+axis*.06,V((0,-1.93,.43))],[.12,.105,.015],'shell',name)
        for k in range(2):s.tube('Inward grasping tooth',[base+V((0,-.12-k*.12,0)),base+V((0,-.12-k*.12,0))-axis*.075],[.035,.004],'keratin',name)
    s.oval('Wet threefold oral cavity',(0,-1.57,.43),(.18,.035,.16),'mouth','head')
    s.muzzle=V((0,-1.90,.43))

def veilglider(s):
    s.torso([(0,.55,1.20),(0,.06,1.39),(0,-.39,1.47),(0,-.68,1.61),(0,-1.06,1.58)],[.20,.33,.26,.18,.10])
    s.oval('Flight muscle keel',(0,-.03,1.26),(.33,.48,.39),soft=True)
    s.oval('Streamlined cranial hood',(0,-.73,1.61),(.24,.33,.21),soft=True)
    for side in [-1,1]:
        s.leg('hind'+str(side),(side*.19,.46,1.16),(side*.29,.64,.63),(side*.31,.42,.11),.085,'pelvis',0 if side<0 else .5,'hook')
        root=V((side*.27,-.03,1.48));elbow=V((side*1.08,.13,1.48));wrist=V((side*1.88,-.27,1.41));tip=V((side*2.55,-.18,1.29))
        names=['wing'+str(side)+'_'+str(i) for i in range(3)]
        for i,(a,b) in enumerate(zip([root,elbow,wrist],[elbow,wrist,tip])):s.bone(names[i],a,b,'chest' if i==0 else names[i-1]);s.wings.append(names[i])
        s.tube('Continuous wing leading tissue',[root,elbow,wrist,tip],[.15,.10,.060,.012],soft=True)
        trailing=[V((side*.39,.65,1.17)),V((side*1.0,.83,1.17)),V((side*1.72,.50,1.16))]
        s.membrane('Inner lifting membrane',[root,elbow,wrist,trailing[2],trailing[1],trailing[0]],'ventral')
        s.membrane('Outer split lifting membrane',[wrist,tip,V((side*2.32,.29,1.16)),trailing[2]],'skin')
        for k,point in enumerate(trailing):s.tube('Load bearing wing finger',[elbow,(elbow+point)*.5+V((0,0,.04)),point],[.043,.029,.01],'keratin',names[1])
        s.membrane('Rear stabilising membrane',[(side*.22,.52,1.22),(side*1.12,1.05,1.0),(side*.82,1.42,.96),(side*.20,.98,1.11)],'shell','pelvis')
        for i in range(2):s.eye('Paired flight eye'+str(side)+str(i),(side*.21,-.84+i*.12,1.70),side,.083-i*.018,slit=False)
        s.tube('Swept cheek sensory vane',[(side*.13,-.54,1.76),(side*.37,-.20,1.91),(side*.54,.14,1.78)],[.062,.04,.008],'keratin','head')
    s.bone('jaw',(0,-.76,1.48),(0,-1.15,1.47),'head');s.jaws=['jaw'];s.tube('Elastic dart nozzle',[(0,-.77,1.48),(0,-1.02,1.45),(0,-1.20,1.51)],[.11,.075,.035],'shell','jaw')
    s.tail([(0,.69,1.20),(0,1.20,1.18),(0,1.76,1.13),(0,2.14,1.09)],[.15,.095,.056,.01])
    for side in [-1,1]:s.membrane('Steering tail membrane',[(0,1.18,1.18),(side*.45,1.78,1.18),(side*.50,2.16,1.07),(0,1.99,1.08)],'ventral','tail1')
    s.muzzle=V((0,-1.21,1.53))

BUILDERS=dict(sailhorn=sailhorn,shearprowler=shearprowler,pressureurn=pressureurn,vaulthopper=vaulthopper,reedserpent=reedserpent,veilglider=veilglider)

def smooth(a,b,t):
    x=max(0,min(1,(t-a)/(b-a)));return x*x*(3-2*x)

def animate(s):
    rig=s.arm;scene=bpy.context.scene;scene.render.fps=30
    s.actions={}
    for state,duration in [('idle_loop',2),('move_loop',2),('feed',2.4),('attack',2.4)]:
        rig.animation_data_create();action=bpy.data.actions.new(state);action.use_fake_user=True;rig.animation_data.action=action
        frames=round(duration*30);scene.frame_start=1;scene.frame_end=frames+1
        for frame in range(frames+1):
            t=frame/30;scene.frame_set(frame+1)
            for pb in rig.pose.bones:pb.rotation_mode='XYZ';pb.matrix_basis=Matrix.Identity(4)
            kind=s.spec['kind'];moving=state=='move_loop';attacking=state=='attack';feeding=state=='feed';phase=t*TAU
            prep=smooth(.05,.75,t)*(1-smooth(.79,1.03,t)) if attacking else 0
            release=smooth(.73,.96,t)*(1-smooth(1.05,1.60,t)) if attacking else 0
            hit=math.sin(max(0,min(1,(t-.78)/.35))*math.pi) if attacking else 0
            drive=smooth(.76,1.18,t)*1.10 if attacking and kind in ['quadruped','hexapod','hopper'] else 0
            rootloc=V((0,-drive,0));bodybob=.025*math.sin(phase*2) if moving else .009*math.sin(phase)
            if kind=='hopper' and moving:rootloc.z=.28*max(0,math.sin(phase))
            if kind=='hopper' and attacking:rootloc.z=.72*math.sin(max(0,min(1,(t-.70)/.64))*math.pi)
            if kind=='glider':rootloc.z=.15+.065*math.sin(phase*1.5)
            s.local('root',location=s.binds['root'].to_3x3().inverted()@rootloc)
            s.local('pelvis',(.02*math.sin(phase),.025*math.sin(phase) if moving else 0,0),location=(0,bodybob,0))
            s.local('chest',(.025*math.sin(phase+.45)-prep*.10,0,.035*math.sin(phase) if moving else 0),scale=(1+.012*math.sin(phase),1,1+.014*math.sin(phase)))
            s.local('neck',(.04*math.sin(phase+.6),0,.025*math.sin(phase*.5)))
            s.local('head',(-.025*math.sin(phase+.9),.025*math.sin(phase*.5),0))
            if feeding:
                gain=smooth(.0,.7,t)*(1-smooth(1.8,2.4,t))
                s.local('neck',(.78*gain if kind=='quadruped' else .28*gain,0,0))
                s.local('head',(.20*gain,0,.04*math.sin(t*5)))
            if attacking:
                if kind=='quadruped':
                    s.local('neck',(.50*prep+.38*release,0,0));s.local('head',(.28*prep-.22*hit,0,0));s.local('chest',(-.10*prep+.13*hit,0,0),location=(0,-.10*prep,0))
                elif kind=='hexapod':
                    s.local('chest',(-.19*prep+.19*release,0,.24*math.sin((t-.8)*16)*release));s.local('head',(-.20*prep+.18*release,0,.10*release))
                elif kind=='tripod':
                    s.local('chest',(.0,0,0),scale=(1+.12*prep-.07*release,1+.08*prep-.09*release,1+.12*prep-.09*release));s.local('neck',(-.17*prep+.19*release,0,0));s.local('head',(-.15*prep+.24*release,0,0))
                elif kind=='hopper':s.local('chest',(.20*prep-.30*hit,0,0),location=(0,-.16*prep,0))
                elif kind=='serpent':s.local('chest',(-.20*prep,0,0),scale=(1+.12*prep,1,1+.15*prep));s.local('neck',(-.52*prep+.28*release,0,0));s.local('head',(.20*prep-.17*release,0,0))
                elif kind=='glider':s.local('chest',(-.15*prep+.15*release,0,0));s.local('neck',(-.18*prep+.13*release,0,0))
            for i,name in enumerate(s.flex):
                if kind=='serpent':s.local(name,(0,.08*math.sin(phase-i*.6),.18*math.sin(phase-i*.65)*(1 if moving else .24)))
                else:s.local(name,(.03*math.sin(phase-i*.6),0,.10*math.sin(phase-i*.6)*(1 if moving else .4)))
            for i,name in enumerate(s.lids):
                blink=max(0,1-abs((t%2)-1.2)/.10);s.local(name,(blink*.55,0,0))
            for i,name in enumerate(s.jaws):
                amount=(.15+.12*math.sin(t*10)) if feeding else (.60*prep+.18*release if attacking else .02*math.sin(t*3))
                if kind=='tripod':s.local(name,(amount*.9,0,0))
                elif kind in ['hexapod','serpent']:s.local(name,(0,0,(-1 if i%2 else 1)*amount))
                else:s.local(name,(-amount,0,0))
            if kind=='glider':
                for name in s.wings:
                    side=-1 if '-1' in name else 1;segment=int(name.rsplit('_',1)[1]);beat=math.sin(t*TAU*1.5-segment*.42)
                    s.local(name,(0,0,side*((.14 if segment==0 else -.12)+beat*(.32 if moving else .12))*(1-.52*prep)))
            bpy.context.view_layer.update()
            for leg in s.legs:
                foot=V(leg['foot'])+rootloc;f=(t+leg['phase'])%1
                if moving and kind!='glider':
                    stance=.66 if kind!='hopper' else .40;stride=.72 if kind=='quadruped' else (.52 if kind=='hexapod' else .36)
                    if f<stance:foot.y+=(-.5+f/stance)*stride
                    else:
                        x=(f-stance)/(1-stance);foot.y+=(.5-smooth(0,1,x))*stride;foot.z+=math.sin(x*math.pi)*(.17 if kind!='hopper' else .30)
                    if kind=='hopper':foot.z+=rootloc.z*.5
                if attacking:
                    foot.y-=release*.10
                    if kind=='hexapod' and leg['name'].startswith('leg0'):
                        swing=max(0,math.sin((t-.70-(.13 if '-1' in leg['name'] else 0))*10))*release
                        foot.z+=prep*.28+swing*.50;foot.y-=swing*.65;foot.x*=1-.32*swing
                    if kind=='hopper':foot.z+=rootloc.z*.6
                if kind=='glider':foot.z+=.25;foot.y+=.23
                s.solve_leg(leg,foot)
            for pb in rig.pose.bones:
                for prop in ['location','rotation_euler','scale']:pb.keyframe_insert(data_path=prop,frame=frame+1,group=pb.name)
        s.actions[state]=action;rig.animation_data.action=None
        print('STUDY_ANIMATED',s.spec['id'],state,frames+1,flush=True)
    rig.animation_data.action=s.actions['idle_loop'];scene.frame_set(1)

def source_render(s):
    scene=bpy.context.scene;s.arm.animation_data.action=s.actions['idle_loop'];scene.frame_set(1);bpy.context.view_layer.update()
    points=[o.matrix_world@V(p) for o in bpy.context.scene.objects if o.type=='MESH' for p in o.bound_box]
    lo=V(tuple(min(p[i] for p in points) for i in range(3)));hi=V(tuple(max(p[i] for p in points) for i in range(3)));center=(lo+hi)/2;size=max(hi-lo)
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.04));ground=bpy.context.object;ground.data.materials.append(ink.material('structural_dark'))
    bpy.ops.object.camera_add(location=center+V((1.20,-1.70,1.10)).normalized()*size*3);camera=bpy.context.object;camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='ORTHO';camera.data.ortho_scale=size*1.70;scene.camera=camera
    scene.world=bpy.data.worlds.new('Studio');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.20,.23,.28,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.50
    for offset,energy in [((1,-1.5,2),130),((-1,-.2,.8),60),((.5,1.3,1.4),100)]:
        bpy.ops.object.light_add(type='AREA',location=center+V(offset)*size);lamp=bpy.context.object;lamp.data.energy=energy*size*size;lamp.data.size=size*1.1;lamp.rotation_euler=(center-lamp.location).to_track_quat('-Z','Y').to_euler()
    scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True;scene.render.resolution_x=1100;scene.render.resolution_y=900;scene.render.resolution_percentage=100
    scene.render.filepath=str(MEDIA/'blender'/(s.spec['id']+'.png'));bpy.ops.render.render(write_still=True)

def build(spec):
    s=Study(spec);BUILDERS[spec['id']](s);s.fuse_skin();s.rig();animate(s)
    bpy.context.view_layer.update();source=SRC/(spec['id']+'.blend');bpy.ops.wm.save_as_mainfile(filepath=str(source))
    row=dict(spec,source=str(source.relative_to(ROOT)),status='type-study-not-native-catalog',bone_count=len(s.bones),locomotion_chains=len(s.legs),clips=list(s.actions),muzzle=[s.muzzle.x,s.muzzle.z,-s.muzzle.y],lods={})
    # Existing skinned consolidation keeps authored bones, weights and materials.
    biota_rig.consolidate()
    for lod in ['near','far']:
        if lod=='far':
            s.arm.data.pose_position='REST'
            for ob in list(bpy.context.scene.objects):
                if ob.type!='MESH' or len(ob.data.polygons)<160:continue
                bpy.context.view_layer.objects.active=ob;mod=ob.modifiers.new('Preserve study silhouette at distance','DECIMATE');mod.ratio=.43;bpy.ops.object.modifier_apply(modifier=mod.name)
            s.arm.data.pose_position='POSE'
        path=OUT/(spec['id']+'_'+lod+'.glb')
        bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',export_yup=True,export_animations=True,export_animation_mode='ACTIONS',export_merge_animation='ACTION',export_force_sampling=True,export_frame_range=False,export_cameras=False,export_lights=False)
        triangles=0;points=[]
        for ob in bpy.context.scene.objects:
            if ob.type!='MESH':continue
            ob.data.calc_loop_triangles();triangles+=len(ob.data.loop_triangles);points.extend(ob.matrix_world@v.co for v in ob.data.vertices)
        converted=[(p.x,p.z,-p.y) for p in points]
        row['lods'][lod]=dict(path=str(path.relative_to(ROOT)),triangles=triangles,sha256=hashlib.sha256(path.read_bytes()).hexdigest(),min=[min(p[i] for p in converted) for i in range(3)],max=[max(p[i] for p in converted) for i in range(3)])
    (SRC/(spec['id']+'.json')).write_text(json.dumps(row,ensure_ascii=False,indent=2)+'\n')
    bpy.ops.wm.open_mainfile(filepath=str(source));s.arm=bpy.data.objects['StudySkeleton'];s.actions={k:bpy.data.actions.get(k) for k in row['clips']};source_render(s)
    print('STUDY_COMPLETE',spec['id'],row['lods']['near']['triangles'],flush=True)

if __name__=='__main__':
    wanted=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    for spec in SPECS:
        if not wanted or spec['id'] in wanted:build(spec)
    rows=[json.loads((SRC/(s['id']+'.json')).read_text()) for s in SPECS if (SRC/(s['id']+'.json')).exists()]
    (ROOT/'우주-비즈니스/data/creature_studies.json').write_text(json.dumps({'version':1,'scope':'six representative anatomy/motion studies; not native species replacements','forms':rows},ensure_ascii=False,indent=2)+'\n')
