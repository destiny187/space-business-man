"""Blender source authoring for 7,000 additional biological structures.
-- [family/id] [--force] [--representatives] [--start=N] [--end=N] [--claim-work]
All output is separate from the existing 1,000 authored base forms.
"""
from pathlib import Path
import sys,math,json,hashlib,colorsys,tempfile,fcntl,time
from contextlib import contextmanager
import bpy
from mathutils import Vector
from mathutils.kdtree import KDTree
ROOT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(ROOT/'tools'),str(ROOT/'tools/bestiary')]
import build_xenofauna as X
import biota_rig
import biota_midpoint_art
import biota_eyes
from types import SimpleNamespace
from biota_roster import recipes,COLLECTION
B=X.B;TAU=math.tau
X.SRC=ROOT/'art/blender/biota';X.OUT=ROOT/'우주-비즈니스/assets/models/biota'
X.REVIEW=ROOT/'docs/production/media/biota';X.REV='biota-ink-4'
X.ENVIRONMENTS=dict(X.ENVIRONMENTS,gas_cloud={'label':'가상 대기층 생태','palette':['62868b','b3b490','ba825f']})
AERIAL=False
for p in [X.SRC,X.OUT,X.REVIEW/'blender']:p.mkdir(parents=True,exist_ok=True)

def mesh(name,verts,faces,slot='main',parent=None):
    data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.update()
    ob=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(ob);B.finish(ob,name,slot,parent or B.BODY)
    for face in data.polygons:face.use_smooth=True
    return ob

def sweep(name,points,r=.08,slot='main',parent=None,radii=None,sides=16):
    """Closed curved tissue with smoothly sampled centerline and capped ends."""
    ps=[Vector(p) for p in points];verts=[];faces=[]
    for i,p in enumerate(ps):
        t=(ps[min(i+1,len(ps)-1)]-ps[max(0,i-1)]).normalized()
        ref=Vector((0,0,1)) if abs(t.z)<.9 else Vector((0,1,0))
        x=t.cross(ref).normalized();y=t.cross(x).normalized();radius=r*(radii[i] if radii else 1)
        for k in range(sides):
            a=k*TAU/sides;verts.append(tuple(p+radius*(x*math.cos(a)+y*math.sin(a))))
    for i in range(len(ps)-1):
        for k in range(sides):a=i*sides+k;b=i*sides+(k+1)%sides;faces.append((a,b,b+sides,a+sides))
    faces+=[tuple(reversed(range(sides))),tuple((len(ps)-1)*sides+k for k in range(sides))]
    return mesh(name,verts,faces,slot,parent)

def curve(name,points,r=.08,slot='main',parent=None):
    ps=[Vector(p) for p in points];smooth=[]
    for i in range(len(ps)-1):
        p0=ps[max(0,i-1)];p1=ps[i];p2=ps[i+1];p3=ps[min(len(ps)-1,i+2)]
        for j in range(5):
            t=j/5;smooth.append(.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t*t*t))
    smooth.append(ps[-1]);return sweep(name,smooth,r,slot,parent,sides=24)
def oval(name,p,s,slot='main',parent=None,sectors=32,rings=12):
    verts=[];faces=[]
    for j in range(rings+1):
        a=math.pi*j/rings
        for k in range(sectors):
            b=k*TAU/sectors;verts.append((p[0]+s[0]*math.sin(a)*math.cos(b),p[1]+s[1]*math.sin(a)*math.sin(b),p[2]+s[2]*math.cos(a)))
    for j in range(rings):
        for k in range(sectors):i=j*sectors+k;next_k=j*sectors+(k+1)%sectors;faces.append((i,i+sectors,next_k+sectors,next_k))
    return mesh(name,verts,faces,slot,parent)
def leaf(name,points,width,slot='main',parent=None):return X.membrane(name,points,width,slot,parent)

def fan(name,p,direction,span=.55,height=.65,lobes=4,parent=None):
    """Broad connected fleshy fan, not a wire-only ornament."""
    q=B.pivot(name,p,parent or B.BODY);q.rotation_euler.z=direction
    for j in range(lobes):
        a=-.8+1.6*j/max(1,lobes-1);end=(span*math.sin(a),span*.12*math.cos(a),height*math.cos(a))
        leaf('Fused fan lobe',[(0,0,0),(end[0]*.45,-.05,end[2]*.7),end],span*.22,parent=q)
    return q

def contact(name,at,side,extent=.5,parent=None):
    if AERIAL:return
    p=Vector(at);q=B.pivot(name,at,parent or B.BODY)
    end=Vector((side*extent,.10,.09-p.z));mid=(side*extent*.62,-.06,.13)
    curve('Tapered weight bearing limb',[(0,0,0),mid,tuple(end)],.085,'secondary',q)
    oval('Organic contact heel',tuple(end),(.15,.21,.09),'main',q)
    for digit in [-1,1]:curve('Paired soft toe',[tuple(end),(end.x+digit*.09,end.y-.16,end.z-.015),(end.x+digit*.13,end.y-.24,end.z-.02)],.043,'main',q)

def foot_radial(at,angle,reach=.55,name='Anim_Leg'):
    if AERIAL:return
    p=Vector(at);q=B.pivot(name,at,B.BODY);q.rotation_euler.z=angle
    curve('Radial bent support',[(0,0,0),(reach*.65,0,.08),(reach,0,.07-p.z)],.085,'secondary',q)
    oval('Radial muscular sole',(reach,0,.06-p.z),(.19,.13,.07),'main',q)

def organ_system(kind,anchors,n,v):
    for k,(at,a) in enumerate(anchors):
        q=B.pivot('Anim_Appendage_%02d'%k,at,B.BODY);q.rotation_euler.z=a
        factor=.7+.35*(k%3)/2
        if kind=='armor':
            oval('Overlapping rounded dorsal scute',(0,0,.07),(.29*factor,.24,.20),'secondary',q)
            leaf('Raised armor keel',[(0,-.2,.05),(0,0,.38),(0,.23,.08)],.13,'bone',q)
        elif kind=='gills':
            curve('Living gill rachis',[(0,0,0),(.10,0,.30),(.20,0,.61*factor)],.055,'secondary',q)
            for s in [-1,1]:
                for j in range(3):leaf('Broad paired gill blade',[(.05,0,.15+j*.12),(.08+s*.23,0,.28+j*.12),(s*.36,0,.31+j*.12)],.11,'accent',q)
        elif kind=='mandibles':
            for s in [-1,1]:
                jaw=B.pivot('Anim_Petal_Jaw_%02d_%s'%(k,s),(0,s*.12,0),q)
                curve('Articulated predatory jaw',[(0,0,0),(.30,s*.15,.12),(.57,s*.09,.31),(.49,0,.38)],.095,'secondary',jaw)
                for j in range(2):curve('Blunt opposing tooth',[(.28+j*.12,s*.09,.17+j*.08),(.29+j*.12,-s*.02,.22+j*.08)],.042,'bone',jaw)
        elif kind=='antennal_fans':
            curve('Branching sensory stalk',[(0,0,0),(.18,0,.30),(.2,0,.54)],.07,'secondary',q)
            fan('Anim_Frond_Sensory_%d'%k,(.2,0,.48),.0,.34,.45,3+(v%2),q)
            oval('Flat sensory pit',(.2,-.05,.42),(.10,.045,.07),'eye',q)
        elif kind=='siphons':
            curve('Siphon supporting neck',[(0,0,0),(.1,0,.20),(.15,0,.36)],.10,'secondary',q)
            X.cup('Open thick metabolic funnel',(.15,0,.30),.12,.38*factor,24,'main',q,flare=.35)
        elif kind=='sails':
            leaf('Thick webbed lateral sail',[(0,0,0),(.34,0,.34),(.67,-.1,.63*factor),(.88,0,.18)],.29,'main',q)
            curve('Sail load bearing edge',[(0,0,0),(.34,0,.34),(.67,-.1,.63*factor)],.04,'accent',q)
        elif kind=='tendrils':
            curve('Common sensory tendril',[(0,0,0),(.26,0,.16),(.48,0,.38)],.075,'secondary',q)
            for s in [-1,1]:curve('Terminal bifurcation',[(.45,0,.35),(.63,s*.16,.50),(.75,s*.24,.35)],.05,'main',q)

def animal(row):
    f=row['construction'];v=row['anatomy'];p=row['body_plan'];n=p['radial_count'];t=p['topology'];w=p['width'];h=p['height'];anchors=[]
    # Axial bending changes anatomical organization, not merely overall scale.
    def axis(i,z=.67):
        u=i/max(1,n-1);y=(u-.5)*1.75
        x=[0,.25*math.sin(u*math.pi),(.25 if i%2 else -.25)*u,.25*(-1 if i%2 else 1),.25*math.sin(u*TAU)][t]
        return (x*w,y,z*h+(.18*math.sin(u*math.pi) if t==1 else 0))
    if f in ['spindle','lobopod']:
        pts=[axis(i,.45 if f in ['lobopod','ribbon'] else .72) for i in range(n)]
        curve('Continuous flexible spine',pts,.18 if f!='ribbon' else .12,'secondary')
        for k,at in enumerate(pts):
            size=(.32*w,.22,.28*h) if f!='ribbon' else (.50*w,.22,.11*h)
            if f=='spindle':size=(.43*w*math.sin((k+1)*math.pi/(n+1))+.10,.30,.33*h)
            if f=='chain':size=(.24,.22,.23)
            oval('Living body metamere',at,size);anchors.append(((at[0],at[1],at[2]+size[2]*.72),k%2*math.pi))
            if k%2==0 or f=='lobopod':
                for s in [-1,1]:contact('Anim_Leg_%02d_%s'%(k,s),(at[0]+s*size[0]*.65,at[1],at[2]-.07),s,.26 if f=='lobopod' else .43)
        head=Vector(pts[0])+Vector((0,-.25,.09));q=B.pivot('Anim_Head',head,B.BODY)
        oval('Distinct cephalic lobe',(0,0,0),(.30,.25,.22),'secondary',q)
        for s in [-1,1]:oval('Recessed lateral eye',(s*.22,-.14,.08),(.065,.05,.07),'eye',q)
        tail=Vector(pts[-1]);q=B.pivot('Anim_Tail',tail,B.BODY)
        curve('Tapering muscular tail',[(0,0,0),(.1,.42,.08),(-.05,.74,.19)],.09,'main',q)
    elif f=='chain':
        # Colony zooids share a duct but retain their own feeding/locomotor lobes.
        pts=[axis(k,.35+.10*(k%2)) for k in range(n)]
        curve('Shared colony digestive cord',pts,.065,'accent')
        for k,at in enumerate(pts):
            q=B.pivot('Anim_Segment_%02d'%k,at,B.BODY)
            oval('Distinct contractile zooid',(0,0,0),(.26*w,.15,.22*h),'main',q)
            X.ring('Zooid constriction boundary',(0,0,0),.24*w,.20*h,.04,'secondary',q,plane='xz')
            for side in [-1,1]:
                curve('Soft colony crawling lobe',[(side*.17,0,-.07),(side*.31,.02,-.14),(side*.37,-.10,.065-at[2])],.07,'secondary',q)
                oval('Colony adhesive disc',(side*.37,-.10,.06-at[2]),(.10,.13,.055),'accent',q)
            anchors.append(((at[0],at[1],at[2]+.15*h),k%2*math.pi))
        X.cup('Terminal common feeding aperture',pts[0],.13,.22,24,'accent')
    elif f=='ribbon':
        pts=[axis(k,.20+.045*math.sin(k*1.3)) for k in range(n)]
        leaf('Continuous undulating thick ventral ribbon',pts,.48*w,'main')
        curve('Longitudinal visceral duct',pts,.105,'secondary')
        for k,at in enumerate(pts):
            for side in [-1,1]:
                leaf('Muscular crawling skirt', [at,(at[0]+side*.42*w,at[1],at[2]+.07),(at[0]+side*.58*w,at[1]+.06,.06)],.16,'secondary')
            anchors.append(((at[0],at[1],at[2]+.06),k%2*math.pi))
        for side in [-1,1]:
            curve('Flattened cephalic feeler',[pts[0],(pts[0][0]+side*.20,pts[0][1]-.22,.2),(pts[0][0]+side*.32,pts[0][1]-.4,.25)],.07,'accent')
    elif f in ['radial','flat','crown']:
        z=.45 if f=='flat' else .62
        if f=='crown':X.ring('Living open crown',(0,0,z),.55*w,.55*w,.15,'main',plane='xy')
        else:oval('Central radial digestive body',(0,0,z),(.53*w,.53*w,.12 if f=='flat' else .28))
        for k in range(n):
            a=k*TAU/n;r=.48*w;at=(r*math.cos(a),r*math.sin(a),z)
            q=B.pivot('Anim_Leg_%d'%k,at,B.BODY);q.rotation_euler.z=a
            reach=.45+.12*(k%2)+t*.025
            curve('Radial muscular lobe',[(0,0,0),(reach*.5,.08,.08),(reach,0,.0 if AERIAL else -z+.12)],.13 if f!='flat' else .085,'main',q)
            if not AERIAL:oval('Lobe contact surface',(reach,0,-z+.1),(.21,.15,.08),'secondary',q)
            anchors.append(((at[0],at[1],z+.08),a))
        X.cup('Central open intake',(0,0,z-.07),.16,.25,24,'accent')
    elif f=='tower':
        curve('Tall load bearing body',[(0,0,.45),(.2*w,0,.9*h),(-.1,0,1.65*h)],.22)
        oval('Raised visceral body',(-.1,0,1.5*h),(.38,.32,.4),'secondary')
        for k in range(3+t%3):a=k*TAU/(3+t%3);foot_radial((.13*math.cos(a),.13*math.sin(a),.64),a,.72,'Anim_Leg_%d'%k)
        for k in range(n):a=k*2.399;z=.65+k/max(1,n-1)*.88*h;anchors.append(((.16*math.cos(a),.16*math.sin(a),z),a))
    elif f=='saddle':
        for s in [-1,1]:
            curve('Paired vaulted spinal arch',[(s*.3,-.8,.35),(s*.36,-.48,1.12*h),(s*.3,.48,1.12*h),(s*.3,.8,.35)],.15)
            for y in [-.8,.8]:contact('Anim_Leg_%s_%s'%(s,y),(s*.3,y,.4),s,.35)
        for k in range(n):
            y=(k/max(1,n-1)-.5)*1.2;z=(1.02+.10*math.cos(y*2))*h
            curve('Suspended visceral rib',[(-.3,y,z),(0,y,z-.42),(.3,y,z)],.065,'secondary')
            anchors.append(((0,y,z-.35),k%2*math.pi))
    elif f=='mantle':
        oval('Continuous thick mantle',(0,0,.52),(.65*w,.82,.34*h))
        for k in range(n):
            a=k*TAU/n;at=(.53*w*math.cos(a),.7*math.sin(a),.53)
            foot_radial(at,a,.34,'Anim_Leg_%d'%k);anchors.append((at,a))
        q=B.pivot('Anim_Head',(0,-.76,.42),B.BODY);X.cup('Protrusible oral tube',(0,0,0),.18,.25,24,'accent',q)
    elif f=='spiral':
        turns=1.05+t*.22;pts=[]
        for k in range(65):a=k/64*TAU*turns;r=.12+.42*k/64;pts.append((math.cos(a)*r*w,math.sin(a)*r*w,.32+k/64*.90*h))
        curve('Ascending muscular coil',pts,.17)
        oval('Broad crawling foot',(0,0,.13),(.62,.76,.14),'secondary')
        for k in range(n):at=pts[round(k/max(1,n-1)*64)];anchors.append((at,k/max(1,n-1)*TAU*turns))
    elif f=='bilateral':
        for s in [-1,1]:oval('Paired visceral mantle',(s*.40,0,.65),(.29,.75,.38*h))
        for k in range(n):
            y=(k/max(1,n-1)-.5)*1.24;curve('Visceral isthmus',[(-.40,y,.65),(0,y,.48),(.40,y,.65)],.09,'secondary')
            s=-1 if k%2 else 1;anchors.append(((s*.4,y,.87),0 if s>0 else math.pi))
        for y in [-.5,.5]:
            for s in [-1,1]:contact('Anim_Leg_%s_%s'%(y,s),(s*.48,y,.54),s,.4)
    elif f=='amphora':
        X.cup('Open amphora body',(0,0,.35),.35,1.1*h,32,'main',flare=-.05)
        for k in range(3+t%3):a=k*TAU/(3+t%3);foot_radial((.18*math.cos(a),.18*math.sin(a),.47),a,.5,'Anim_Leg_%d'%k)
        for k in range(n):a=k*TAU/n;anchors.append(((.29*math.cos(a),.29*math.sin(a),.65+(k%3)*.22),a))
    elif f=='branch':
        oval('Basal visceral hub',(0,0,.45),(.36,.4,.28),'secondary')
        for k in range(n):
            a=k*TAU/n;q=B.pivot('Anim_Segment_%d'%k,(0,0,.45),B.BODY);q.rotation_euler.z=a
            curve('Living branching trunk',[(0,0,0),(.36,0,.35*h),(.68,0,.48*h)],.10,'main',q)
            at=(.68*math.cos(a),.68*math.sin(a),.45+.48*h);oval('Branch terminal organ',at,(.15,.15,.18),'secondary');anchors.append((at,a))
        for k in range(4):foot_radial((0,0,.37),k*TAU/4,.6,'Anim_Leg_%d'%k)
    else:raise ValueError(f)
    bpy.context.view_layer.update()
    tissue=[o.matrix_world@vertex.co for o in bpy.context.scene.objects if o.type=='MESH' for vertex in o.data.vertices]
    tree=KDTree(len(tissue))
    for index,point in enumerate(tissue):tree.insert(point,index)
    tree.balance()
    for at,_ in anchors:
        origin=Vector(at);closest,_,_=tree.find(origin)
        if (closest-origin).length>.07:curve('Integrated organ vascular stalk',[tuple(closest),at],.07,'secondary')
    organ_system(row['organ_system'],anchors,n,v)

def avian(row):
    """Flight body, nested shoulder/elbow/wrist chains, primaries and landing feet."""
    v=row['anatomy'];t=v//10;n=row['flight']['primary_feathers'];style=row['flight']['wing_style']
    form=row.get('anatomical_type','');wader=form=='wader';owl=form=='owl'
    torso_z=1.43 if wader else .85
    head_at=(0,.80,2.09) if wader else ((0,.42,1.34) if owl else (0,.69,1.18))
    oval('Flight muscle thorax',(0,0,torso_z),(.25,.59,.26) if wader else ((.41,.43,.40) if owl else (.30,.53,.30)),'main')
    oval('Paired air-sac abdomen',(0,-.30,torso_z-.09),(.25,.39,.22),'secondary')
    leaf('Deep living sternal keel',[(0,.40,torso_z-.13),(0,0,torso_z-.41),(0,-.34,torso_z-.15)],.12,'bone')
    cervical=[(0,.30,torso_z+.06),(0,.58,torso_z+.23),head_at]
    if wader:cervical=[(0,.35,1.48),(0,.55,1.68),(0,.39,1.94),head_at]
    curve('Flexible cervical column',cervical,.088 if wader else .13,'main')
    head=B.pivot('Anim_Head',head_at,B.BODY)
    oval('Streamlined avian cranium',(0,.03,.01),(.19,.23,.17) if wader else ((.38,.21,.34) if owl else (.22,.26,.20)),'secondary',head)
    beak=.62 if wader else (.12 if owl else .32+.015*n)
    for side in [-1,1]:
        if owl:
            oval('Broad facial sound collecting disc',(side*.17,.17,.01),(.185,.065,.24),'main',head)
            leaf('Curved facial crown',[(side*.20,.04,.21),(side*.29,.04,.40),(side*.32,.02,.42)],.09,'accent',head)
        elif not wader:oval('Recessed lateral eye',(side*.185,.12,.07),(.055,.065,.058),'eye',head)
    if form:biota_eyes.avian(SimpleNamespace(B=B,mesh=mesh,oval=oval,sweep=sweep),row,head,form)
    if owl:
        sweep('Continuous hooked upper beak',[(0,.17,.04),(0,.29,.025),(0,.32,-.035),(0,.30,-.105)],.078,'bone',head,[1,.85,.46,.06],24)
    elif wader:
        sweep('Continuous tapered probing beak',[(0,.19,.04),(0,.33,.045),(0,.23+beak,.02)],.055,'bone',head,[1,.66,.035],24)
    else:curve('Tapered upper beak',[(0,.19,.04),(0,.33,.045),(0,.23+beak,-.05 if t==1 else .02)],.075,'bone',head)
    jaw=B.pivot('Anim_Petal_Beak',(0,.18,-.06),head)
    if form:sweep('Tapered articulated lower beak',[(0,0,0),(0,.08 if owl else .14,-.012),(0,.10 if owl else .04+beak,.004 if owl else .04)],.035,'secondary',jaw,[1,.70,.04],24)
    else:curve('Articulated lower beak',[(0,0,0),(0,.14,-.015),(0,.04+beak,.04)],.035,'secondary',jaw)
    tail=B.pivot('Anim_Tail',(0,-.48,torso_z-.10),B.BODY)
    count=3+n//2 if style=='fan' else (2 if t in [1,2] else 4)
    for j in range(count):
        u=(j-(count-1)*.5)/max(1,(count-1)*.5)
        end=(u*(.63 if style=='fan' else .25),(-.40 if owl else -.76)-(.30*abs(u) if t in [1,2] and not owl else 0),.12+.05*(j%2))
        leaf('Splayed steering tail feather',[(0,0,0),(end[0]*.65,end[1]*.55,.16),end],.16 if style=='fan' else .10,'main',tail)
    # Bony wing segments overlap at spherical joints. No wing section is a detached prop.
    for pair in range(row['flight']['wing_pairs']):
        for side in [-1,1]:
            label=('L' if side<0 else 'R')+str(pair)
            scale=.78 if pair else (1.13 if wader else 1.0)
            shoulder=B.pivot('Anim_WingShoulder_'+label,(side*(.32 if owl else .22),.20-pair*.48,torso_z+.09-pair*.07),B.BODY)
            elbow_at=(side*.43*scale,-.14*scale,.04)
            wrist_at=(side*.43*scale,.21*scale,-.005)
            tip=(side*(.80 if style=='scythe' else .55)*scale,-.13*scale,0)
            oval('Covered shoulder joint',(0,0,0),(.13,.16,.13),'secondary',shoulder)
            curve('Humerus wing spar',[(0,0,0),elbow_at],.09,'secondary',shoulder)
            leaf('Inner flight coverts',[(0,.045,0),(elbow_at[0]*.55,-.10,.015),elbow_at],(.29 if owl else .20)*scale,'main',shoulder)
            elbow=B.pivot('Anim_WingElbow_'+label,elbow_at,shoulder)
            oval('Articulated elbow',(0,0,0),(.10,.11,.10),'secondary',elbow)
            for dy in [-.025,.025]:curve('Radius ulna paired spars',[(0,dy,0),(wrist_at[0],wrist_at[1]+dy,wrist_at[2])],.036,'bone',elbow)
            for j in range(4+t):
                u=(j+.2)/(4+t);at=(wrist_at[0]*u,wrist_at[1]*u,0)
                leaf('Overlapping secondary flight feather',[at,(at[0]+side*.05,at[1]-.22*scale,.025),(at[0]+side*.12,at[1]-.44*scale,.035)],.09*scale,'main',elbow)
            wrist=B.pivot('Anim_WingWrist_'+label,wrist_at,elbow)
            oval('Wing wrist joint',(0,0,0),(.075,.09,.075),'secondary',wrist)
            curve('Hand-wing fused metacarpus',[(0,0,0),tip],.052,'bone',wrist)
            for j in range(n):
                u=j/max(1,n-1)
                root=(tip[0]*u*.8,tip[1]*u*.8,0)
                length=(.64 if style=='scythe' else .47)*scale*(.8+.2*u)
                end=(root[0]+side*length*(.48+.45*u),root[1]-length*(1-.40*u),.035+.035*math.sin(u*math.pi))
                if style=='membrane':
                    curve('Elongated wing finger',[root,((root[0]+end[0])*.5,(root[1]+end[1])*.5,.075),end],.025,'accent',wrist)
                    if j:
                        web=mesh('Scalloped load bearing web',[(0,0,0),previous,end],[(0,1,2)],'main',wrist)
                        thickness=web.modifiers.new('Flight membrane thickness','SOLIDIFY');thickness.thickness=.025
                    previous=end
                else:
                    leaf('Asymmetric primary remex',[root,((root[0]+end[0])*.5,(root[1]+end[1])*.5,.06),end],(.105 if style!='scythe' else .065)*scale,'main',wrist)
                    curve('Primary feather load bearing rachis',[root,end],.012,'accent',wrist)
    for side in [-1,1]:
        upper=.37 if wader else .22;lower=.72 if wader else .31
        hip=B.pivot('Anim_AvianHip_'+('L' if side<0 else 'R'),(side*.17,-.18,torso_z-.23),B.BODY)
        curve('Upper landing limb',[(0,0,0),(0,-.13,-upper)],.046 if wader else .065,'secondary',hip)
        knee=B.pivot('Anim_AvianKnee_'+('L' if side<0 else 'R'),(0,-.13,-upper),hip)
        curve('Long avian tarsus',[(0,0,0),(0,.08,-lower)],.032 if wader else .04,'bone',knee)
        for j in [-1,0,1]:curve('Curved grasping landing toe',[(0,.08,-lower),(j*.09,.22,-lower-.03),(j*.12,.30,-lower-.05)],.025,'bone',knee)
        curve('Opposing hind toe',[(0,.08,-lower),(0,-.06,-lower-.03),(0,-.12,-lower-.05)],.025,'bone',knee)
    # Compact dorsal organs preserve the bird silhouette while distinguishing lineages.
    count=min(3 if form else 5,n)
    anchors=[((0,.32-k/max(1,count-1)*.60,torso_z+.20),0) for k in range(count)]
    before=set(bpy.context.scene.objects);organ_system(row['organ_system'],anchors,n,v)
    for ob in set(bpy.context.scene.objects)-before:
        if ob.type=='EMPTY' and ob.parent==B.BODY:ob.scale*=.42
    env=row['adaptation_id']
    if env=='tundra':
        for k in range(3):X.ring('Insulating feather collar',(0,.17-k*.13,.82),.28,.25,.04,'secondary',plane='xz')
    elif env in ['salt','ochre']:
        for side in [-1,1]:X.cup('Protected salt heat exchange nostril',(side*.15,.24,1.02),.04,.09,24,'accent')
    else:
        for side in [-1,1]:leaf('Water shedding thoracic contour',[(side*.20,.32,torso_z+.07),(side*.33,0,torso_z+.03),(side*.20,-.36,torso_z-.07)],.13,'secondary')
    if form:
        row['anatomical_scaffold']=[(0,-.28,torso_z-.15),(0,0,torso_z),(0,.35,torso_z+.04),head_at]

def rooted(n=4,width=.55):
    if AERIAL:return
    # Tapered spreading roots rather than a manufactured circular pedestal.
    oval('Root collar',(0,0,.12),(.20,.20,.16),'secondary')
    for k in range(n):
        a=k*TAU/n;curve('Tapered branching root',[(0,0,.16),(.3*width*math.cos(a),.3*width*math.sin(a),.10),(width*math.cos(a),width*math.sin(a),.035)],.055,'secondary')

def plant(row):
    f=row['construction'];v=row['anatomy'];p=row['body_plan'];n=p['radial_count'];t=p['topology'];w=p['width'];h=p['height']
    rooted(3+t,.48*w)
    base_height=.25 if f in ['strap','rafflesia','hydnora','bromeliad','lithops'] else .65*h
    # Five growth arrangements: serial, bent, dichotomous, paired and whorled.
    main=[(0,0,.12),(.12*(t==1),0,base_height*.6),(0,0,base_height)]
    curve('Rooted primary stem',main,.12,'secondary')
    if f=='baobab':
        X.cup('Hollow central water cistern',(0,0,.10),.28,.52*h,32,'main',flare=.38)
        for side in [-1,1]:
            curve('Cistern vascular buttress',[(side*.30,0,.08),(side*.31,0,.36*h),(0,0,base_height)],.075,'secondary')
    def attachment(k):
        a=k*TAU/n;z=base_height
        if t==0:z+=k/max(1,n-1)*.60*h;r=.13
        elif t==1:z+=k/max(1,n-1)*.50*h;r=.15+.22*math.sin(k/max(1,n-1)*math.pi)
        elif t==2:r=.25+(k%2)*.17;z+=(k%3)*.20*h
        elif t==3:a=(0 if k%2 else math.pi);r=.28;z+=k/max(1,n-1)*.62*h
        else:r=.32;z+=(k%2)*.18*h
        at=(r*math.cos(a),r*math.sin(a),z)
        curve('Connected growth branch',[(0,0,base_height*.8),(at[0]*.55,at[1]*.55,(z+base_height)*.5),at],.055,'secondary')
        return at,a
    for k in range(n):
        at,a=attachment(k);q=B.pivot('Anim_Frond_%02d'%k,at,B.BODY);q.rotation_euler.z=a
        if f in ['strap','fern','stagfern']:
            pts=[(0,0,0),(.25,0,.20),(.62,0,.23),(.87,0,.03),(.95,0,.28)]
            if f=='strap':leaf('Persistent twisted strap leaf',pts,.21,'main',q)
            else:
                curve('Continuous leaf rachis',pts,.05,'secondary',q)
                for j in range(3):
                    for s in [-1,1]:leaf('Branched broad pinna',[(.16+j*.19,0,.12),(.24+j*.19,s*.25,.27),(.38+j*.19,s*.40,.36 if f=='stagfern' else .20)],.13,'main',q)
        elif f in ['pitcher','bladder','rattlepod']:
            curve('Pendant storage neck',[(0,0,0),(.21,0,.08),(.28,0,-.10)],.055,'secondary',q)
            if f=='pitcher':
                X.cup('Open pitcher leaf',(.28,0,-.30),.16,.40,24,'main',q,flare=.25)
                leaf('Attached pitcher lid',[(.12,0,.05),(.24,0,.23),(.49,0,.17)],.19,'accent',q)
            elif f=='bladder':
                oval('Connected storage bladder',(.28,0,-.17),(.20,.20,.26),'main',q);X.cup('Bladder aperture',(.28,0,.01),.07,.10,24,'accent',q)
            else:
                for s in [-1,1]:leaf('Open pendant seed valve',[(.28,0,-.09),(.28,s*.21,-.35),(.28,0,-.50)],.17,'main',q)
                oval('Suspended seed',(.28,0,-.30),(.11,.11,.15),'accent',q)
        elif f in ['snap','hydnora','lithops']:
            for s in [-1,1]:
                pet=B.pivot('Anim_Petal_Valve_%d_%s'%(k,s),(0,s*.04,0),q)
                leaf('Living opposing valve',[(0,0,0),(.20,s*.22,.15),(.52,s*.22,.45),(.63,s*.06,.40)],.23,'main',pet)
                if f=='snap':
                    for j in range(3):curve('Blunt marginal tooth',[(.2+j*.12,s*.20,.15+j*.10),(.21+j*.12,s*.02,.25+j*.10)],.025,'accent',pet)
            if f=='lithops':oval('Fleshy leaf base',(.25,0,.10),(.30,.26,.16),'secondary',q)
        elif f in ['sundew','shield','bromeliad','succulent']:
            leaf('Broad concave catchment leaf',[(0,0,0),(.24,0,.16),(.53,0,.45),(.75,0,.42)],.34 if f!='succulent' else .22,'main',q)
            if f=='sundew':
                for j in range(4):
                    side=-1 if j%2 else 1;end=(.32+j*.09,side*.17,.42+j*.03)
                    curve('Glandular stalk',[(.31+j*.08,side*.12,.26+j*.02),end],.02,'accent',q);oval('Gland droplet',end,(.045,.045,.04),'eye',q)
            if f=='succulent':oval('Water storage leaf',(.31,0,.22),(.26,.18,.16),'secondary',q)
        elif f in ['rafflesia','orchid']:
            X.cup('Floral throat',(0,0,0),.12,.22,24,'accent',q)
            for j in range(3 if f=='orchid' else 5):
                ang=j*TAU/(3 if f=='orchid' else 5);pet=B.pivot('Anim_Petal_Flower_%d_%d'%(k,j),(0,0,.13),q);pet.rotation_euler.z=ang
                leaf('Thick floral petal',[(0,0,0),(.26,0,.22),(.48,0,.15),(.56,0,-.02)],.21,'main',pet)
        elif f in ['fanpalm','fenestrate','horsetail']:
            if f=='fanpalm':fan('Living fan canopy',(0,0,0),0,.60,.65,5,q)
            elif f=='horsetail':
                curve('Hollow jointed stem',[(0,0,0),(.08,0,.70)],.09,'secondary',q)
                for j in range(3):
                    X.ring('Growth node',(.08*j/3,0,j*.23),.12,.12,.035,'accent',q)
                    for s in [-1,1]:leaf('Whorled broad leaf',[(.08*j/3,0,j*.23),(s*.28,0,j*.23+.15),(s*.41,0,j*.23+.09)],.10,'main',q)
            else:
                for side in [-1,1]:curve('Fenestrated leaf margin',[(0,0,0),(.35,side*.30,.35),(.72,0,.62)],.065,'main',q)
                curve('Leaf main vein',[(0,0,0),(.35,0,.35),(.72,0,.62)],.055,'secondary',q)
                for j in [1,2]:
                    for side in [-1,1]:curve('Open leaf cross vein',[(.23*j,0,.21*j),(.23*j,side*.23,.21*j)],.05,'main',q)
        elif f=='baobab':
            # Hollow storage chambers and offset bifurcations distinguish this
            # lineage from the solid caudex organs, including in silhouette.
            curve('Forked cistern branch',[(0,0,0),(.16,0,.21),(.43,0,.43)],.095,'secondary',q)
            for side in [-1,1]:
                tip=(.41,side*(.19+.035*(k%3)),.58+.09*(k%2))
                curve('Asymmetric bifurcated crown',[(.16,0,.21),(.30,side*.18,.40),tip],.07,'secondary',q)
                fan('Cistern terminal frond',tip,side*.50,.26,.29,3,q)
            sac=B.pivot('Anim_Appendage_Cistern_%02d'%k,(.25,0,.19),q)
            sac.rotation_euler.y=math.pi*.35
            X.cup('Open lateral metabolic chamber',(0,0,0),.14,.34,24,'main',sac,flare=.24)
            lid=B.pivot('Anim_Petal_CisternValve_%02d'%k,(-.12,0,.30),sac)
            leaf('Hinged living chamber lid',[(0,0,0),(.06,0,.22),(.23,0,.24)],.20,'accent',lid)
        elif f in ['stilt','buttress','caudex','candelabra']:
            curve('Branching fleshy trunk',[(0,0,0),(.18,0,.3),(.36,0,.62)],.14 if f=='caudex' else .095,'secondary',q)
            if f=='caudex':oval('Expanded storage trunk',(.12,0,.25),(.23,.20,.32),'main',q)
            if f in ['stilt','buttress']:
                root_end=(at[0]+.3*math.cos(a),at[1]+.3*math.sin(a),.04)
                if f=='stilt':curve('Canopy connected stilt root',[at,(root_end[0],root_end[1],at[2]*.5),root_end],.06,'secondary')
                else:leaf('Broad connected buttress root',[root_end,(at[0],at[1],at[2]*.6),at],.23,'secondary')
            if f=='candelabra':
                for s in [-1,1]:curve('Upright cactus arm',[(.16,0,.26),(.25,s*.25,.28),(.3,s*.25,.65)],.10,'main',q)
            else:fan('Terminal broad canopy',(.36,0,.59),0,.40,.35,3,q)
        elif f in ['spiralcone','umbrella','corkscrew']:
            if f=='spiralcone':
                curve('Continuous supporting bract rachis',[(0,0,-.035),(0,0,.23),(0,0,.43)],.055,'secondary',q)
                for j in range(3):
                    sub=B.pivot('Overlapping spiral bract',(0,0,j*.19),q);sub.rotation_euler.z=j*2.399
                    leaf('Thick protecting bract',[(0,0,0),(.28,0,.15),(.4,0,.31)],.23,'main',sub)
            elif f=='umbrella':
                curve('Canopy supporting stalk',[(0,0,0),(0,0,.50)],.06,'secondary',q)
                for j in range(5):
                    sub=B.pivot('Umbrella lobe',(0,0,.45),q);sub.rotation_euler.z=j*TAU/5
                    leaf('Connected canopy leaf',[(0,0,0),(.28,0,.15),(.49,0,-.05)],.23,'main',sub)
            else:
                pts=[(.22*math.cos(j*TAU/24),.22*math.sin(j*TAU/24),j*.025) for j in range(37)]
                curve('Thick spiral leaf stem',[(0,0,0),pts[0]],.06,'secondary',q);leaf('Continuous helicoid lamina',pts,.12,'main',q)
        elif f in ['floating_roots','basket']:
            leaf('Supported upper catching leaf',[(0,0,0),(.34,0,.30),(.58,0,.03)],.26,'main',q)
            for s in [-1,1]:
                curve('Connected hanging root',[(.24,s*.08,.18),(.40,s*.15,-.10),(.35,s*.10,-min(.45,at[2]-.06))],.045,'secondary',q)
            if f=='basket':curve('Living basket arch',[(0,0,0),(.1,-.2,.45),(.45,-.2,.45),(.58,0,.03)],.065,'accent',q)
        else:raise ValueError(f)

def microbe(row):
    f=row['construction'];p=row['body_plan'];n=p['radial_count'];t=p['topology'];w=p['width'];h=p['height']
    oval('Shared buoyant matrix' if AERIAL else 'Shared living substrate',(0,0,.065),(.73*w,.59,.23 if AERIAL else .075),'secondary')
    for k in range(n):
        a=k*2.399;r=.57*math.sqrt((k+.5)/n)
        if t==1:a=k/max(1,n-1)*math.pi;r=.4
        elif t==2:a=k%3*TAU/3;r=.18+(k//3)*.1
        elif t==3:r=.35;a=(0 if k%2 else math.pi)+k*.1
        elif t==4:a=k*TAU/n;r=.52
        at=(r*w*math.cos(a),r*math.sin(a),.08);q=B.pivot('Anim_Appendage_%02d'%k,at,B.BODY);q.rotation_euler.z=a
        oval('Coalesced colony growth margin',at,(.20,.18,.065),'main')
        if f in ['vesicle','pustule']:
            oval('Connected metabolic nodule',(0,0,.15),(.16,.16,.22*h),'main',q)
            if f=='pustule':
                for s in [-1,1]:curve('Visible division septum',[(s*.14,0,.05),(0,0,.36*h),(-s*.14,0,.06)],.026,'accent',q)
            else:X.ring('Vesicle collar',(0,0,.06),.14,.14,.028,'accent',q)
        elif f in ['siphon','chimney','tubule']:
            height=.34+(k%3)*.09
            if f=='tubule':
                X.ring('Low common transport loop',(0,0,.12),.19,.15,.06,'main',q)
                X.cup('Terminal filter pore',(.12,0,.1),.075,.16,24,'accent',q)
            elif f=='siphon':
                for s in [-1,1]:
                    curve('Shared siphon branch',[(0,0,0),(s*.10,0,.2)],.065,'secondary',q);X.cup('Open bifurcate siphon',(s*.10,0,.16),.075,.20,24,'main',q)
            else:X.cup('Open metabolic chimney',(0,0,0),.12,height,24,'main',q)
        elif f in ['honeycomb','diatom','lace']:
            if f=='honeycomb':
                pts=[(.20*math.cos(j*TAU/6),.20*math.sin(j*TAU/6),.20) for j in range(7)]
                curve('Thick open colony chamber',pts,.065,'main',q)
                for j in range(3):curve('Chamber wall support',[(pts[j*2][0],pts[j*2][1],0),pts[j*2]],.055,'secondary',q)
            else:
                for s in [-1,1]:curve('Perforated living arch',[(s*.23,0,0),(s*.19,0,.23),(0,0,.36),(-s*.19,0,.23),(-s*.23,0,0)],.055,'main',q)
                if f=='diatom':curve('Cross-linked siliceous plate',[(-.2,0,.16),(.2,0,.16)],.035,'accent',q)
        elif f in ['filament','dendrite']:
            curve('Common filament axis',[(-.24,0,.02),(0,0,.18),(.25,0,.11)],.055,'main',q)
            for s in [-1,1]:
                curve('Branching filament',[(0,0,.18),(.12,s*.18,.23),(.29,s*.25,.10)],.04,'accent',q)
                if f=='filament':curve('Interwoven secondary filament',[(-.2,s*.2,.04),(0,s*.08,.3),(.21,-s*.2,.04)],.04,'secondary',q)
        elif f in ['rosette','stromatolite','fold','scroll']:
            if f=='rosette':
                for s in [-1,1]:curve('Open colony channel margin',[(-.24,s*.06,0),(0,s*.14,.13),(.27,s*.08,.17)],.05,'main',q)
                leaf('Wet channel floor',[(-.24,0,0),(0,0,.09),(.27,0,.13)],.09,'accent',q)
            elif f=='stromatolite':
                for j in range(3):X.ring('Layered colony terrace',(0,0,j*.08),.23-j*.035,.18-j*.025,.045,'main' if j%2 else 'secondary',q)
            elif f=='fold':leaf('Continuous broad biofilm fold',[(-.3,0,0),(-.15,0,.30),(0,0,.08),(.15,0,.32),(.30,0,0)],.18,'main',q)
            else:
                pts=[(.17*math.cos(j*TAU/24),j*.008,.19+.17*math.sin(j*TAU/24)) for j in range(33)]
                leaf('Scrolled living membrane',pts,.11,'main',q);curve('Rooted membrane junction',[(0,0,0),pts[0]],.05,'secondary',q)
        else:raise ValueError(f)

def adaptation(row):
    env=row['environment'];key=row['adaptation_id'];v=row['anatomy']
    bpy.context.view_layer.update()
    bodies=[o for o in bpy.context.scene.objects if o.type=='MESH']
    points=[o.matrix_world@Vector(p) for o in bodies for p in o.bound_box]
    low=Vector(tuple(min(p[i] for p in points) for i in range(3)));high=Vector(tuple(max(p[i] for p in points) for i in range(3)))
    center=(low+high)*.5;span=high-low
    tissue=min((o.matrix_world@vertex.co for o in bodies for vertex in o.data.vertices),key=lambda point:(point-center).length_squared)
    curve('Continuous adaptation organ pedicle',[tuple(tissue),tuple(center)],.075,'secondary') if (tissue-center).length>.03 else None
    # Anchors sit on the organism's existing body instead of detached ornaments.
    if AERIAL:
        oval('Connected primary buoyancy envelope',tuple(center),(max(.4,span.x*.38),max(.4,span.y*.38),max(.28,span.z*.35)),'secondary')
        for s in [-1,1]:
            q=B.pivot('Anim_Wing_'+('L' if s<0 else 'R'),center,B.BODY)
            leaf('Atmospheric stabilizer membrane',[(0,0,0),(s*span.x*.48,0,.22),(s*span.x*.70,.05,-.12)],span.y*.22,'main',q)
        q=B.pivot('Anim_Appendage_Filter',center,B.BODY)
        for k in range(3+v%3):
            x=(k-(2+v%3)*.5)*.12;curve('Suspended atmospheric feeding tendril',[(x,0,0),(x,.10,-span.z*.40),(x+.05,-.04,-span.z*.62)],.045,'accent',q)
        return
    # These details have visible geometry; changing a palette alone is insufficient.
    if key in ['volcanic','cratered','crystalline']:
        for k in range(3):
            y=center.y+(k-1)*span.y*.17;z=high.z*.70
            curve('Shield connective stalk',[tuple(center),(center.x,y,z)],.065,'secondary')
            q=B.pivot('Anim_Appendage_Shield_%d'%k,(center.x,y,z),B.BODY)
            for s in [-1,1]:leaf('Protective overlapping mineral mantle',[(0,0,0),(s*span.x*.27,0,.12),(s*span.x*.40,0,-span.z*.18)],span.y*.16,'bone',q)
    elif key in ['oxidized','salt','alkaline']:
        for s in [-1,1]:
            at=(center.x+s*span.x*.14,center.y,center.z)
            oval('Connected protected metabolic reservoir',at,(span.x*.18,span.y*.24,span.z*.19),'secondary')
            X.cup('Narrow protected exchange opening',(at[0],at[1],at[2]+span.z*.13),.065,.12,24,'accent')
    elif key in ['fractured','tundra','frozen']:
        oval('Insulated inner visceral mantle',tuple(center),(span.x*.27,span.y*.28,span.z*.26),'secondary')
        for k in range(3):
            at=(center.x,center.y+(k-1)*span.y*.16,center.z)
            X.ring('Thick overlapping insulation fold',at,max(.13,span.x*.26),max(.12,span.z*.24),.07,'main',plane='xz')
    elif key=='ochre':
        for s in [-1,1]:fan('Anim_Frond_Thermal_%s'%s,tuple(center),s*math.pi*.5,span.x*.38,span.z*.45,4)
    elif key=='sedimentary':
        for s in [-1,1]:oval('Broad substrate contact mantle',(center.x+s*span.x*.15,center.y,low.z+.08),(span.x*.26,span.y*.27,.10),'secondary')
    else:
        fan('Anim_Frond_LightCollector',tuple(center),0,span.x*.26,span.z*.30,3)
    if env=='cave':
        for s in [-1,1]:curve('Extended dark habitat tactile organ',[tuple(center),(center.x+s*.25,center.y-span.y*.4,center.z),(center.x+s*.45,low.y-.25,center.z-.12)],.045,'accent')

def construct(row):
    global AERIAL
    AERIAL=row['locomotion_medium']=='atmosphere'
    if row['construction']=='avian':
        avian(row);biota_rig.build(row,B.BODY);return
    if row.get('replacement'):
        biota_midpoint_art.build(row,SimpleNamespace(B=B,X=X,mesh=mesh,oval=oval,curve=curve,sweep=sweep,leaf=leaf,organ_system=organ_system))
        biota_rig.build(row,B.BODY);return
    {'animal':animal,'plant':plant,'microbe':microbe}[row['category']](row)
    if row['category']=='animal' and row['body_plan']['topology']:
        bpy.context.view_layer.update();points=[o.matrix_world@Vector(p) for o in bpy.context.scene.objects if o.type=='MESH' for p in o.bound_box]
        low=Vector(tuple(min(p[i] for p in points) for i in range(3)));high=Vector(tuple(max(p[i] for p in points) for i in range(3)))
        center=(low+high)*.5;size=high-low;t=row['body_plan']['topology']
        if t==1:
            curve('Arched secondary visceral spine',[(center.x,center.y-size.y*.25,center.z),(center.x,center.y,high.z+.13),(center.x,center.y+size.y*.25,center.z)],.11,'secondary')
        elif t==2:
            for s in [-1,1]:
                tip=center+Vector((s*size.x*.40,0,size.z*.12));curve('Forked secondary visceral branch',[tuple(center),tuple(tip)],.14,'secondary')
                oval('Branched secondary visceral lobe',tuple(tip),(size.x*.15,size.y*.18,size.z*.17),'main')
        elif t==3:
            for s in [-1,1]:
                q=B.pivot('Anim_Frond_PairedMantle_%s'%s,center,B.BODY)
                leaf('Paired longitudinal mantle',[(0,-size.y*.30,0),(s*size.x*.40,0,size.z*.28),(0,size.y*.35,0)],size.x*.22,'secondary',q)
        else:
            X.ring('Annular visceral crest',tuple(center),size.x*.34,size.z*.34,.11,'secondary',plane='xz')
            for s in [-1,1]:curve('Crest vascular junction',[tuple(center),(center.x+s*size.x*.34,center.y,center.z)],.08,'main')
    adaptation(row)
    biota_rig.build(row,B.BODY)
X.construct=construct
X.ink.consolidate_static_surfaces=biota_rig.consolidate

def catalogue(require_complete=True):
    import pack_biota
    pack_biota.pack(not require_complete)

def source_face(row):
    if not row.get('replacement') or row.get('organ_system')!='armor':return
    head=bpy.context.scene.objects.get('Anim_Head')
    if head is None:return
    scene=bpy.context.scene;camera=scene.camera
    size={'proboscid':1.65,'rhinocerid':1.40,'owl':1.15,'crab':1.20,'hermit':1.20}.get(row['anatomical_type'],1.05)
    target=head.matrix_world.translation.copy()
    target.y+=(.07 if row.get('review_front')=='+Y' else -.09)
    camera.location=target+Vector((.95,1.5 if row.get('review_front')=='+Y' else -1.5,.38))*3
    camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.ortho_scale=size
    scene.render.resolution_x=900;scene.render.resolution_y=750;scene.cycles.samples=16
    folder=X.REVIEW/'faces-blender';folder.mkdir(exist_ok=True)
    scene.render.filepath=str(folder/(row['id']+'.png'));bpy.ops.render.render(write_still=True)

def current_checkpoint(path,spec):
    try:
        row=json.loads(path.read_text())
        return row.get('art_revision')==X.REV and row.get('recipe_revision')==spec.get('recipe_revision') and (ROOT/row['source']).exists() and all((ROOT/row['lods'][lod]['path']).exists() for lod in ['near','far'])
    except (FileNotFoundError,json.JSONDecodeError,KeyError):return False

@contextmanager
def claim_species(identity):
    # A shared local work queue keeps slow structures from leaving other workers
    # idle. OS locks are automatically released if Blender stops unexpectedly.
    if '--claim-work' not in X.ARGS:
        yield True;return
    directory=Path(tempfile.gettempdir())/('biota-build-locks-'+hashlib.sha256(str(ROOT).encode()).hexdigest()[:12]);directory.mkdir(exist_ok=True)
    with (directory/(identity+'.lock')).open('a') as handle:
        try:fcntl.flock(handle,fcntl.LOCK_EX|fcntl.LOCK_NB)
        except BlockingIOError:
            yield False;return
        try:yield True
        finally:fcntl.flock(handle,fcntl.LOCK_UN)

if __name__=='__main__':
    first=next((int(a.split('=')[1]) for a in X.ARGS if a.startswith('--start=')),0)
    last=next((int(a.split('=')[1]) for a in X.ARGS if a.startswith('--end=')),7000)
    for index,spec in enumerate(recipes()):
        if index<first or index>=last:continue
        if '--avians' in X.ARGS and spec['construction']!='avian':continue
        if '--midpoints' in X.ARGS and not spec.get('replacement'):continue
        if X.LIMIT and spec['id'] not in X.LIMIT and spec['family'] not in X.LIMIT:continue
        if '--representatives' in X.ARGS and spec['anatomy'] not in [0,8,24,49]:continue
        path=X.SRC/(spec['id']+'.json')
        if '--force' not in X.ARGS and current_checkpoint(path,spec):continue
        with claim_species(spec['id']) as claimed:
            if not claimed or ('--force' not in X.ARGS and current_checkpoint(path,spec)):continue
            started=time.monotonic()
            row=X.build(spec);row['generator']='tools/build_biota.py'
            checkpoint=path.with_suffix('.json.tmp');checkpoint.write_text(json.dumps(row,ensure_ascii=False,separators=(',',':'))+'\n');checkpoint.replace(path)
            if (spec['anatomy'] in [8,24,49] or spec.get('replacement')) and spec['id'] not in X.LIMIT:
                bpy.ops.wm.open_mainfile(filepath=str(X.SRC/(spec['id']+'.blend')));bpy.context.view_layer.update()
                X.source_render(spec,[o.matrix_world@Vector(p) for o in bpy.context.scene.objects if o.type=='MESH' for p in o.bound_box])
            source_face(spec)
            print('BIOTA_BUILD_SECONDS',spec['id'],round(time.monotonic()-started,3),flush=True)
    catalogue('--representatives' not in X.ARGS)
