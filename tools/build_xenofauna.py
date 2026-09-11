"""Blender INK authoring for 300 anatomy recipes. Resumable; never touches old models.
--background --python tools/build_xenofauna.py -- [family or ID] [--force]
"""
from pathlib import Path
import sys,math,json,hashlib,colorsys
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
sys.path.insert(0,str(ROOT/'tools/bestiary'))
import build_bestiary as B
import ink_blender as ink
from xenofauna_roster import recipes,COLLECTION
from roster import ENVIRONMENTS
SRC=ROOT/'art/blender/xenofauna';OUT=ROOT/'우주-비즈니스/assets/models/xenofauna'
REVIEW=ROOT/'docs/production/media/xenofauna';DATA=ROOT/'우주-비즈니스/data/bestiary'
REV='xenofauna-ink-2'
for p in [SRC,OUT,REVIEW/'blender',REVIEW/'records']:p.mkdir(parents=True,exist_ok=True)
ARGS=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
LIMIT={a for a in ARGS if not a.startswith('--')}
TAU=math.tau

def oval(name,p,s,slot='main',parent=None):
    return B.oval(name,p,s,slot,parent,32)

def tube(name,pts,r=.08,slot='secondary',parent=None):
    curve=bpy.data.curves.new(name,'CURVE');curve.dimensions='3D';curve.resolution_u=2 if len(pts)>20 else 6;curve.bevel_depth=r;curve.bevel_resolution=3
    spline=curve.splines.new('BEZIER');spline.bezier_points.add(len(pts)-1)
    for point,co in zip(spline.bezier_points,pts):point.co=co;point.handle_left_type='AUTO';point.handle_right_type='AUTO'
    obj=bpy.data.objects.new(name,curve);bpy.context.collection.objects.link(obj);obj.parent=parent or B.BODY;obj.data.materials.append(B.M[slot])
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj;bpy.ops.object.convert(target='MESH')
    for polygon in obj.data.polygons:polygon.use_smooth=True
    return obj

def ring(name,p,rx,ry,r=.09,slot='main',parent=None,plane='xy',opening=0,twist=0):
    pts=[]
    for k in range(41):
        a=opening+(TAU-2*opening)*k/40
        x,y=math.cos(a)*rx,math.sin(a)*ry
        d=(x,y,math.sin(a*2)*twist) if plane=='xy' else ((x,math.sin(a*2)*twist,y) if plane=='xz' else (math.sin(a*2)*twist,x,y))
        pts.append(tuple(Vector(p)+Vector(d)))
    if opening:return tube(name,pts,r,slot,parent)
    curve=bpy.data.curves.new(name,'CURVE');curve.dimensions='3D';curve.resolution_u=2;curve.bevel_depth=r;curve.bevel_resolution=3
    spline=curve.splines.new('BEZIER');spline.bezier_points.add(len(pts)-2);spline.use_cyclic_u=True
    for k,(point,co) in enumerate(zip(spline.bezier_points,pts[:-1])):
        point.co=co;point.handle_left_type='AUTO';point.handle_right_type='AUTO';point.radius=1+.07*math.cos(k/40*TAU*3)
    obj=bpy.data.objects.new(name,curve);bpy.context.collection.objects.link(obj);obj.parent=parent or B.BODY;obj.data.materials.append(B.M[slot])
    bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj;bpy.ops.object.convert(target='MESH')
    for polygon in obj.data.polygons:polygon.use_smooth=True
    return obj

def membrane(name,pts,width,slot='main',parent=None):
    # A curved two-sided lamina with actual thickness and a broad quiet colour face.
    ps=[Vector(p) for p in pts];verts=[];faces=[]
    for i in range(17):
        t=i/16;f=t*(len(ps)-1);j=min(int(f),len(ps)-2);p=ps[j].lerp(ps[j+1],f-j)
        tangent=(ps[j+1]-ps[j]).normalized();side=tangent.cross(Vector((0,0,1)))
        if side.length<.2:side=Vector((1,0,0))
        side.normalize();normal=side.cross(tangent).normalized()
        span=max(.014,math.sin(t*math.pi)**.65*width)
        for u in [-1,-.5,0,.5,1]:verts.append(tuple(p+side*(u*span)+normal*(1-u*u)*span*.25))
    for i in range(16):
        for k in range(4):a=i*5+k;faces.append((a,a+1,a+6,a+5))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o)
    B.finish(o,name,slot,parent or B.BODY)
    mod=o.modifiers.new('Living membrane thickness','SOLIDIFY');mod.thickness=.045
    mod=o.modifiers.new('Rounded living rim','BEVEL');mod.width=.016;mod.segments=3
    return o

def cup(name,p,r,h,n=24,slot='main',parent=None,flare=.35):
    # Thick open cup, both surfaces explicitly modelled. The empty interior reads in INK.
    verts=[];faces=[];steps=10
    for inside in [False,True]:
        for j in range(steps):
            t=j/(steps-1);rad=r*(.25+(.75+flare)*t**.65)-(.065 if inside else 0)
            for k in range(n):
                a=TAU*k/n;verts.append((p[0]+rad*math.cos(a),p[1]+rad*math.sin(a),p[2]+h*t+(.055 if inside else 0)))
    for side in range(2):
        for j in range(steps-1):
            for k in range(n):
                a=side*steps*n+j*n+k;b=side*steps*n+j*n+(k+1)%n
                q=(a,b,b+n,a+n);faces.append(tuple(reversed(q)) if side else q)
    for k in range(n):
        a=(steps-1)*n+k;b=(steps-1)*n+(k+1)%n
        faces.append((a,b,b+steps*n,a+steps*n));faces.append((k+steps*n,(k+1)%n+steps*n,(k+1)%n,k))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o)
    B.finish(o,name,slot,parent or B.BODY)
    ring(name+' rounded lip',(p[0],p[1],p[2]+h),r*(1+flare)-.03,r*(1+flare)-.03,.045,'secondary',parent)
    return o

def legs(n,z=.65,r=.34,reach=.76,phase=0):
    for k in range(n):
        a=k*TAU/n+phase;ca,sa=math.cos(a),math.sin(a)
        q=B.pivot('Anim_Leg_%02d_%s'%(k,'L' if k%2 else 'R'),(r*ca,r*sa,z),B.BODY)
        oval('Proximal articulation',(0,0,0),(.14,.14,.15),'secondary',q)
        tube('Load bearing bent limb',[(0,0,0),(.32*ca,.32*sa,.10),((reach-r)*ca,(reach-r)*sa,-z+.13)],.085,'main',q)
        oval('Broad contact pad',((reach-r)*ca,(reach-r)*sa,-z+.08),(.16,.18,.07),'secondary',q)

def receptor(p,v,k=0,parent=None):
    # Embedded receptors instead of repeating mammalian eyeballs on all new bodies.
    if v%3==0:
        for j in range(2):ring('Blind vibration opening',(p[0]+j*.09,p[1]-.04,p[2]),.055,.08,.022,'bone',parent,plane='xz')
    elif v%3==1:
        oval('Recessed sensory shield',p,(.14,.075,.105),'dark',parent)
        oval('Flat photoreceptor',(p[0],p[1]-.069,p[2]),(.095,.024,.053),'eye',parent)
    else:
        tube('Chemosensory folded seam',[(p[0]-.1,p[1],p[2]-.05),p,(p[0]+.12,p[1]-.03,p[2]+.06)],.042,'accent',parent)

def construct(row):
    f=row['family'];v=row['anatomy'];plan=row['body_plan'];n=plan['radial_count'];w=plan['width'];h=plan['height']
    body=B.BODY
    # Every branch is a separately authored body plan; v controls its primary anatomy.
    if f=='torus_loom':
        for j in range(1+(v in [1,2,6,8,9])+(v==2)):
            q=B.pivot('Anim_Appendage_%d'%j,((j-.5*(1+(v==2)))*.35 if v in [1,2,6,8,9] else 0,j*.13,1.1*h),body)
            ring('Hollow muscular torso',(0,0,0),.69*w,.78*h,.18,'main',q,'xz',.35 if v==6 else 0,.15 if v==5 else 0)
            for k in range(n):
                # Keep receptors on the remaining tissue of the open-ring anatomy.
                a=.50+(TAU-1.0)*k/(n-1) if v==6 else k*TAU/n
                receptor((.64*w*math.cos(a),-.16,.72*h*math.sin(a)),v,k,q)
        legs(plan['limb_count'],.45,.34,.88*w)
        cup('Suspended filter',(0,0,.45),.22,.38,n*4,'accent')
    elif f=='double_vault':
        for s in [-1,1]:
            q=B.pivot('Anim_Appendage_%d'%(0 if s<0 else 1),(s*.36*w,0,.15),body)
            tube('Paired arch spine',[(0,-.9,0),(-s*.18,-.7,1.2*h),(0,0,1.55*h),(s*.12,.7,1.1*h),(0,.9,0)],.17,'main',q)
            for k in range(n):
                y=(k/(n-1)-.5)*1.3
                tube('Transverse neural bridge',[(0,y,1.3*h),(s*.2,y,.85*h),(-s*.7*w,y,1.3*h)],.075,'bone',q)
                oval('Hanging ganglion',(-s*.2,y,.75*h),(.14,.18,.23),'accent',q)
        legs(plan['limb_count'],.35,.32,.85)
    elif f=='pentapalm':
        oval('Headless central palm',(0,0,.62),(.49*w,.45,.24),'main')
        for k in range(n):
            a=k*TAU/n;q=B.pivot('Anim_Leg_%d_R'%k,(.23*math.cos(a),.23*math.sin(a),.58),body)
            r=1.1*w;dx,dy=r*math.cos(a),r*math.sin(a)
            tube('Radial hand trunk',[(0,0,0),(dx*.5,dy*.5,.25*h),(dx,dy,-.43)],.14,'main',q)
            for j in range(2+v//4):
                b=a+(j-(1+v//4)*.5)*.36
                tube('Split feeding digit',[(dx*.8,dy*.8,-.25),(dx+math.cos(b)*.28,dy+math.sin(b)*.28,-.44)],.065,'secondary',q)
            receptor((dx,dy-.06,-.3),v,k,q)
    elif f=='walking_calyx':
        cup('Deep digestive calyx',(0,0,.45),.46,.56*h,32)
        for k in range(n):
            a=k*TAU/n;q=B.pivot('Anim_Petal_%d'%k,(.3*math.cos(a),.3*math.sin(a),.76*h),body);q.rotation_euler.z=a
            membrane('Thick opening oral valve',[(0,0,0),(.45,0,.4*h),(.85*w,.03,.30*h),(.94*w,0,-.08)],.25+.035*v,'main',q)
            receptor((.65*w,-.08,.34*h),v,k,q)
        legs(plan['limb_count'],.42,.25,.72*w)
    elif f=='saddle_bridge':
        for s in [-1,1]:oval('Separated load bearing abdomen',(0,s*.68,.67*h),(.46*w,.39,.57*h),'main')
        for k in range(2+v%4):
            x=(k-(1+v%4)*.5)*.2
            tube('Suspension spine',[(x,-.7,.9*h),(x,-.3,1.55*h),(x,.3,1.55*h),(x,.7,.9*h)],.10,'secondary')
        for k in range(n):
            y=(k/(n-1)-.5)*1.1;q=B.pivot('Anim_Appendage_%d'%k,(0,y,1.3*h),body)
            tube('Suspended visceral cord',[(0,0,0),(.10,0,-.28),(0,0,-.55)],.065,'accent',q)
            oval('Pendant stomach',(0,0,-.59),(.14,.17,.18),'main',q)
        legs(plan['limb_count'],.5,.4,.85*w)
    elif f=='gyre_tower':
        turns=1.05+(v%5)*.30
        for j in range(2 if v in [6,8,9] else 1):
            q=B.pivot('Anim_Appendage_%d'%j,(0,0,.42),body)
            pts=[(.53*w*math.cos(TAU*turns*k/64+j*math.pi),.53*w*math.sin(TAU*turns*k/64+j*math.pi),k/64*1.5*h) for k in range(65)]
            tube('Open ascending muscular helix',pts,.14,'main' if j==0 else 'secondary',q)
        for k in range(n):
            a=k*TAU/n;oval('Metabolic wall sac',(.42*w*math.cos(a),.42*w*math.sin(a),.7+k*.12),(.18,.18,.22),'accent')
        legs(plan['limb_count'],.48,.34,.87*w)
    elif f=='twin_moons':
        centers=[(-.52*w,0,.8*h),(.52*w,.05,1.10*h if v%2 else .8*h)]
        if v in [5,6,9]:centers.append((0,.6,1.48*h))
        tube('Shared nervous isthmus',centers,.17,'bone')
        for k,p in enumerate(centers):
            q=B.pivot('Anim_Appendage_%d'%k,p,body);oval('Independent visceral lobe',(0,0,0),(.42 if k%2 else .50,.38,.55*h),'main',q)
            for j in range(n):
                a=j*TAU/n;ring('Raised organ seam',(0,0,(j/(n-1)-.5)*.7*h),.40,.35,.032,'secondary',q)
            receptor((0,-.39,.1),v,k,q)
        legs(plan['limb_count'],.53,.45,.96*w)
    elif f=='accordion_shell':
        tube('Ventral elastic axis',[(0,-1,.28),(0,0,.38),(0,1,.28)],.17,'accent')
        for k in range(n):
            y=(k/(n-1)-.5)*1.8;q=B.pivot('Anim_Segment_%d'%k,(0,y,.42),body)
            ring('Hollow armoured pleat',(0,0,.32*h),.58*w,.52*h,.15,'main' if k%2 else 'secondary',q,'xz',.7 if v in [5,8] else .1)
            for s in [-1,1]:tube('Pleat foot',[(s*.42,0,.05),(s*.70*w,0,-.25),(s*.74*w,-.08,-.33)],.08,'bone',q)
        receptor((0,-1.01,.7*h),v)
    elif f=='veil_antler':
        oval('Low tactile body',(0,0,.4),(.4,.65,.28),'main');legs(plan['limb_count'],.38,.3,.83*w)
        for k in range(n):
            a=TAU*k/n;q=B.pivot('Anim_Frond_%d'%k,(0,0,.55),body);q.rotation_euler.z=a
            tube('Living horn frame',[(0,0,0),(.25,0,.7*h),(.85*w,0,1.2*h),(1.0*w,.12,.92*h)],.07,'bone',q)
            membrane('Sensory horn sail',[(0,0,.15),(.3,0,.6*h),(.8*w,0,1.06*h)],.23 if v%2 else .36,'main',q)
    elif f=='rib_sled':
        for s in [-1,1]:tube('Muscular floor runner',[(s*.65*w,-1.15,.13),(s*.74*w,0,.20),(s*.65*w,1.15,.13)],.16,'main')
        for k in range(n):
            y=(k/(n-1)-.5)*1.9;q=B.pivot('Anim_Appendage_%d'%k,(0,y,.18),body)
            tube('Empty rib vault',[(-.65*w,0,0),(-.57*w,0,.68*h),(0,.10,1.12*h),(.57*w,0,.68*h),(.65*w,0,0)],.11,'secondary',q)
            oval('Spinal metabolism node',(0,.1,1.08*h),(.14,.16,.14),'accent',q)
        receptor((0,-.97,.9*h),v)
    elif f=='crown_anchor':
        oval('Flat ventral disc',(0,0,.45),(.70*w,.70*w,.19),'main');legs(plan['limb_count'],.4,.45,.97*w)
        for k in range(n):
            a=k*TAU/n;q=B.pivot('Anim_Appendage_%d'%k,(0,0,.54),body);q.rotation_euler.z=a
            tube('Returning anchor antler',[(.5*w,0,0),(.83*w,0,.4*h),(.69*w,0,.93*h),(.29*w,0,1.05*h),(.22*w,0,.81*h)],.105,'bone',q)
            receptor((.65*w,-.09,.54*h),v,k,q)
        cup('Dorsal intake',(0,0,.52),.2,.28,n*4,'accent')
    elif f=='inverted_fan':
        oval('Asymmetric fan base',(-.2,0,.51),(.31,.44,.39),'main');legs(plan['limb_count'],.35,.28,.8*w)
        q=B.pivot('Anim_Head',(-.18,0,.6),body)
        for k in range(n):
            a=-.65+1.7*k/(n-1);x=math.sin(a)*1.1*w;z=math.cos(a)*1.3*h
            membrane('Radial broad fan organ',[(0,0,0),(x*.55,0,z*.6),(x,.08,z)],.22+.018*v,'main' if k%2 else 'secondary',q)
            tube('Fan rib',[(0,0,0),(x*.65,-.015,z*.64),(x,-.015,z)],.045,'bone',q)
            receptor((x,-.055,z*.85),v,k,q)
    elif f=='spiral_hinge':
        oval('Central hinge body',(0,0,.53),(.3,.55,.33),'main');legs(plan['limb_count'],.4,.32,.9*w)
        for s in [-1,1]:
            q=B.pivot('Anim_Appendage_%d'%(0 if s<0 else 1),(s*.25,0,.75*h),body);q.rotation_euler.z=s*(.15+v*.045)
            pts=[]
            for k in range(65):
                t=k/64;a=t*TAU*(1.1+v%5*.25);r=(.15+.60*t)*w
                pts.append((s*(.18+r*math.cos(a)),.06*math.sin(a),r*math.sin(a)*h))
            tube('Spiral skeletal disc',pts,.115,'main',q)
            for k in range(n):oval('Hinge sensory nodule',(s*(.2+k*.07),-.10,.2),(.055,.055,.1),'accent',q)
    elif f=='lattice_beast':
        levels=3 if v in [5,6,9] else 2
        for j in range(levels):
            z=.45+j*.56*h;r=(.62-j*.1)*w
            for k in range(n):
                a=k*TAU/n;b=(k+1)*TAU/n
                p=(r*math.cos(a),r*math.sin(a),z);p2=(r*math.cos(b),r*math.sin(b),z)
                q=B.pivot('Anim_Appendage_%d'%(j*n+k),p,body);oval('Joint organ',(0,0,0),(.13,.13,.16),'accent',q)
                tube('Open lattice edge',[p,p2],.08,'bone')
                if j<levels-1:tube('Slant skeletal strut',[p,((r-.1)*math.cos(a+.3),(r-.1)*math.sin(a+.3),z+.56*h)],.09,'main')
        legs(plan['limb_count'],.42,.40,.82*w)
    elif f=='funnel_stilt':
        cup('Open funnel torso',(0,0,.85*h),.48*w,.58*h,32,flare=.45 if v%2 else .2)
        for k in range(n):
            a=k*TAU/n;q=B.pivot('Anim_Leg_%d_R'%k,(.42*w*math.cos(a),.42*w*math.sin(a),1.0*h),body)
            tube('Outside wall leg',[(0,0,0),(.4*math.cos(a),.4*math.sin(a),.12),(.65*math.cos(a),.65*math.sin(a),-1.0*h+.1)],.10,'secondary',q)
            oval('Funnel foot',(.65*math.cos(a),.65*math.sin(a),-1.0*h+.08),(.14,.14,.07),'main',q)
            receptor((0,-.12,.24),v,k,q)
    elif f=='crescent_maw':
        for j in range(2 if v in [2,3,8] else 1):
            q=B.pivot('Anim_Jaw' if j==0 else 'Anim_Appendage_1',(0,j*.30,1.0*h),body)
            ring('Crescent muscular body',(0,0,0),.84*w,.83*h,.21,'main',q,'xz',.6+v%3*.15)
            for k in range(n):
                a=.7+k*(TAU-1.4)/(n-1);receptor((.81*w*math.cos(a),-.20,.79*h*math.sin(a)),v,k,q)
        legs(plan['limb_count'],.43,.35,.9*w)
    elif f=='radial_mill':
        oval('Central mill abdomen',(0,0,.51),(.42,.42,.27),'main')
        for k in range(n):
            a=k*TAU/n;q=B.pivot('Anim_Leg_%d_R'%k,(0,0,.53),body);q.rotation_euler.z=a
            membrane('Thick paddle limb',[(.23,0,0),(.62,0,.27*h),(1.0*w,.08,.11),(1.14*w,.16,-.35)],.24,'main',q)
            tube('Paddle flexor',[(.22,0,.04),(.6,0,.3*h),(1.13*w,.16,-.30)],.07,'bone',q)
            oval('Adhesive contact organ',(1.13*w,.16,-.4),(.20,.15,.08),'accent',q)
        ring('Circular sensory canal',(0,0,.77),.3,.3,.075,'secondary')
    elif f=='knuckle_chain':
        centers=[]
        for k in range(n):
            t=k/(n-1);p=(math.sin(t*TAU)*.16 if v%2 else 0,(t-.5)*2.2,.35+math.sin(t*math.pi)*.9*h);centers.append(p)
            q=B.pivot('Anim_Segment_%d'%k,p,body);oval('Independent armoured organ',(0,0,0),(.31*w,.30,.32),'main' if k%2 else 'secondary',q)
            for s in [-1,1]:tube('Segment support',[(s*.17,0,0),(s*.45*w,0,.1),(s*.61*w,0,-p[2]+.09)],.075,'bone',q)
            receptor((0,-.25,.12),v,k,q)
        tube('Continuous chain nerve',centers,.14,'accent')
    elif f=='pendulum_grazer':
        for s in [-1,1]:tube('Visceral suspension arch',[(s*.7*w,-.9,.09),(s*.5*w,-.65,1.45*h),(s*.5*w,.65,1.45*h),(s*.7*w,.9,.09)],.16,'main')
        for k in range(n):
            y=(k/(n-1)-.5)*1.2;tube('Overhead transverse bone',[(-.5*w,y,1.45*h),(.5*w,y,1.45*h)],.085,'bone')
            q=B.pivot('Anim_Appendage_%d'%k,(0,y,1.43*h),body)
            tube('Pendulous feeding throat',[(0,0,0),(.1,0,-.42*h),(0,0,-.85*h)],.085,'secondary',q)
            cup('Hanging feeding cup',(0,0,-1.02*h),.17,.23,24,'main',q)
        legs(plan['limb_count'],.34,.4,.78*w)
    elif f=='split_keel':
        for s in [-1,1]:
            tube('Long separate abdomen',[(s*.45*w,-1.05,.43),(s*.58*w,0,.66*h),(s*.46*w,1.05,.37)],.23,'main')
            receptor((s*.45*w,-1.17,.48),v)
        for k in range(n):
            y=(k/(n-1)-.5)*1.7;q=B.pivot('Anim_Appendage_%d'%k,(0,y,.64*h),body)
            tube('Transverse muscular bridge',[(-.52*w,0,0),(0,0,.25*h),(.52*w,0,0)],.09,'bone',q)
            if v in [6,8,9]:oval('Central chain organ',(0,0,.12),(.18,.17,.20),'accent',q)
        legs(plan['limb_count'],.42,.40,.93*w)
    elif f=='petal_mantis':
        tube('Jointed plate axis',[(0,-.95,.65),(0,0,.73),(0,.95,.45)],.13,'accent')
        for k in range(n):
            y=(k/(n-1)-.5)*1.8;q=B.pivot('Anim_Segment_%d'%k,(0,y,.54),body)
            for s in [-1,1]:
                membrane('Opening armoured body plate',[(s*.05,0,0),(s*.4*w,0,.38*h),(s*.73*w,.06,.20*h)],.26,'main' if k%2 else 'secondary',q)
                tube('Folded plate leg',[(s*.2,0,.08),(s*.60*w,0,-.03),(s*.78*w,.12,-.46)],.055,'bone',q)
        receptor((0,-.97,.8),v)
    elif f=='cup_colony':
        oval('Shared colony abdomen',(0,0,.36),(.63*w,.63*w,.23),'main');legs(plan['limb_count'],.32,.4,.86*w)
        for k in range(n):
            a=k*2.399;r=.42 if k else .1;z=.45+(k%3)*.17*h
            q=B.pivot('Anim_Petal_%d'%k,(math.cos(a)*r*w,math.sin(a)*r*w,z),body)
            tube('Independent oral neck',[(0,0,-z+.38),(0,0,.18*h)],.105,'secondary',q)
            cup('Open colonial mouth',(0,0,.04),.21,.35*h,24,'main',q)
            receptor((0,-.24,.26),v,k,q)
    elif f=='corkscrew_spine':
        turns=1.1+(v%5)*.32
        pts=[(.42*w*math.cos(k/80*TAU*turns),(k/80-.5)*2.3,.7*h+.43*h*math.sin(k/80*TAU*turns)) for k in range(81)]
        tube('Horizontal hollow helix',pts,.18,'main')
        for k in range(n):
            y=(k/(n-1)-.5)*2.0;q=B.pivot('Anim_Segment_%d'%k,(0,y,.45),body)
            for s in [-1,1]:tube('Helix floor support',[(s*.22,0,.18),(s*.54*w,.1,-.15),(s*.67*w,.05,-.35)],.09,'bone',q)
            oval('Inner neural chamber',(0,0,.28),(.18,.20,.20),'accent',q)
    elif f=='umbrella_clutch':
        for j in range(1+v%3):
            q=B.pivot('Anim_Frond_%d'%j,(0,0,.90*h+j*.34),body);rad=(.85-j*.18)*w
            for k in range(n):
                a=k*TAU/n
                membrane('Thick umbrella lobe',[(0,0,.22),(math.cos(a)*rad*.55,math.sin(a)*rad*.55,.13),(math.cos(a)*rad,math.sin(a)*rad,-.15)],rad*.33,'main' if j%2 else 'secondary',q)
            ring('Umbrella edge',(0,0,-.15),rad,rad,.055,'bone',q)
        legs(plan['limb_count'],.65,.23,.77*w)
        for k in range(3+v%3):receptor(((k-1)*.17,-.26,.64),v,k)
    elif f=='mirror_fork':
        trunk=[(0,.85,.30),(0,.38,.65),(0,0,.86*h)];tube('Primary branching trunk',trunk,.23,'main')
        count=2+(v in [1,2,7,9])+(v==2)
        for j in range(count):
            x=(j-(count-1)*.5)*.67*w;q=B.pivot('Anim_Appendage_%d'%j,(0,0,.82*h),body)
            tube('Forked headless abdomen',[(0,0,0),(x,-.35,.18),(x,-.90,.25*h)],.16,'main',q)
            cup('Fork terminal mouth',(x,-.9,.15*h),.22,.26,24,'secondary',q)
            for k in range(n//2):receptor((x+(k-.5)*.12,-1.08,.40*h),v,k,q)
        legs(plan['limb_count'],.42,.35,.85*w)
    elif f=='quill_amphora':
        # Alternating curved staves leave large genuine windows into the central organ.
        oval('Protected internal organ',(0,0,.85*h),(.30,.30,.55*h),'accent')
        for k in range(n):
            a=k*TAU/n;q=B.pivot('Anim_Appendage_%d'%k,(0,0,.30),body);q.rotation_euler.z=a
            membrane('Perforated amphora stave',[(.25,0,0),(.61*w,0,.43*h),(.49*w,0,.97*h),(.27,0,1.30*h)],.16 if v%2 else .23,'main',q)
            tube('Protective curved quill',[(.57*w,0,.55*h),(.88*w,0,.91*h),(.55*w,.03,1.36*h)],.06,'bone',q)
        ring('Open neck lip',(0,0,.30+1.30*h),.28,.28,.10,'secondary');legs(plan['limb_count'],.36,.28,.78*w)
    elif f=='braid_crawler':
        strands=2+v%5
        for j in range(strands):
            q=B.pivot('Anim_Appendage_%d'%j,(0,0,.6*h),body)
            pts=[(.31*w*math.cos(k/64*TAU*(1+v%3*.35)+j*TAU/strands),(k/64-.5)*2.2,.34*h*math.sin(k/64*TAU*(1+v%3*.35)+j*TAU/strands)) for k in range(65)]
            tube('Braided muscular trunk',pts,.10 if strands>4 else .145,'main' if j%2 else 'secondary',q)
        for k in range(n):
            y=(k/(n-1)-.5)*1.8
            oval('Exposed internodal organ',(0,y,.62*h),(.13,.15,.17),'accent')
        legs(plan['limb_count'],.38,.3,.78*w)
    elif f=='hinge_book':
        tube('Central opening hinge',[(0,-.65,.62),(0,0,.66),(0,.65,.62)],.17,'accent');legs(plan['limb_count'],.43,.35,.8*w)
        for s in [-1,1]:
            q=B.pivot('Anim_Petal_%d'%(0 if s<0 else 1),(0,0,.65),body);q.rotation_euler.y=s*(.20+v%4*.15)
            for k in range(n):
                y=(k/(n-1)-.5)*1.4
                membrane('Hinged organic page',[(0,y,0),(s*.45*w,y,.55*h),(s*.80*w,y,1.10*h)],.20,'main' if k%2 else 'secondary',q)
                tube('Structural page rib',[(0,y,0),(s*.5*w,y-.025,.58*h),(s*.8*w,y,1.08*h)],.043,'bone',q)
                receptor((s*.48*w,y-.08,.65*h),v,k,q)
    elif f=='offset_halo':
        count=2+v%3
        for k in range(count):
            p=((k-(count-1)*.5)*.45*w,0,.72*h+k*.25*h);q=B.pivot('Anim_Appendage_%d'%k,p,body)
            q.rotation_euler.z=(k%2*2-1)*(.45+v*.035)
            ring('Offset organ halo',(0,0,0),.52*w,.57*h,.13,'main' if k%2 else 'secondary',q,'xz',.4 if v in [6,8] else 0,.12 if v==5 else 0)
            if k: tube('Eccentric hinge',[(p[0]-.30,0,p[2]-.18),p],.11,'bone')
            receptor(((-.46 if v in [6,8] else .46)*w,-.13,.1),v,k,q)
        legs(plan['limb_count'],.38,.32,.90*w)
    elif f=='root_octant':
        for k in range(n):
            a=k*TAU/n;q=B.pivot('Anim_Leg_%d_R'%k,(0,0,.65*h),body);q.rotation_euler.z=a
            tube('Headless radial body branch',[(0,0,0),(.36*w,0,.18),(.72*w,0,-.18),(.95*w,0,-.55*h)],.16,'main',q)
            for s in [-1,1]:
                tube('Terminal feeding bifurcation',[(.62*w,0,-.12),(.82*w,s*.24,-.28),(1.02*w,s*.30,-.56*h)],.075,'secondary',q)
                oval('Terminal contact mouth',(1.02*w,s*.30,-.56*h),(.13,.13,.07),'accent',q)
            if v in [5,6,8,9]:tube('Ascending branch',[(.35,0,.12),(.45,.18,.57*h),(.63,.2,.72*h)],.075,'bone',q)
        cup('Central dorsal vent',(0,0,.68*h),.16,.25,24,'secondary')
    else:raise ValueError(f)

def source_render(row,points):
    scene=bpy.context.scene
    low=Vector(tuple(min(p[i] for p in points) for i in range(3)));high=Vector(tuple(max(p[i] for p in points) for i in range(3)))
    center=(low+high)/2;size=max(high-low)
    scene.world=bpy.data.worlds.new('Natural material inspection');scene.world.use_nodes=True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.18,.21,.25,1)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value=.45
    bpy.ops.mesh.primitive_plane_add(size=size*20,location=(0,0,-.025));ground=bpy.context.object
    mat=B.material('review_ground',(.28,.29,.27),rough=.88);ground.data.materials.append(mat)
    bpy.ops.object.camera_add(location=center+Vector((1.25,1.65 if row.get('review_front')=='+Y' else -1.65,1.0)).normalized()*size*3)
    cam=bpy.context.object;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=size*1.65;scene.camera=cam
    for offset,energy in [((1,-1.5,2),80),((-1,-.2,1),30)]:
        bpy.ops.object.light_add(type='AREA',location=center+Vector(offset)*size)
        lamp=bpy.context.object;lamp.data.energy=energy*size*size;lamp.data.size=size*1.3;lamp.rotation_euler=(center-lamp.location).to_track_quat('-Z','Y').to_euler()
    scene.render.engine='CYCLES';scene.cycles.samples=8;scene.cycles.use_denoising=True
    scene.render.resolution_x=600;scene.render.resolution_y=500;scene.render.resolution_percentage=100
    scene.render.filepath=str(REVIEW/'blender'/(row['id']+'.png'));bpy.ops.render.render(write_still=True)

def build(row):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    env=ENVIRONMENTS[row['environment']];palette=env['palette']
    row=dict(row,art_revision=REV,form_schema=1,palette=palette,
             environment_label=env['label'],render_status='exported-awaiting-game-review',
             generator='tools/build_xenofauna.py')
    B.M={k:B.material(k,B.rgb(c),rough=.78 if k!='eye' else .30,emit=.06 if k=='eye' else 0) for k,c in {
        'main':palette[0],'secondary':palette[1],'accent':palette[2],'bone':'b4ad92','dark':'16272e','eye':'75b7a8'}.items()}
    B.BODY=B.pivot('Anim_Body');construct(row)
    row['eye_count']=sum(o.name.startswith('Flat photoreceptor') for o in bpy.context.scene.objects)
    bpy.context.view_layer.update()
    points=[o.matrix_world@Vector(p) for o in bpy.context.scene.objects if o.type=='MESH' for p in o.bound_box]
    B.BODY.location.z-=min(p.z for p in points);bpy.context.view_layer.update()
    source=SRC/(row['id']+'.blend');bpy.ops.wm.save_as_mainfile(filepath=str(source))
    row['source']=str(source.relative_to(ROOT));row['editable_meshes']=sum(o.type=='MESH' for o in bpy.context.scene.objects)
    row['pivots']=[o.name for o in bpy.context.scene.objects if o.type=='EMPTY']
    ink.consolidate_static_surfaces()
    row['lods']={};row['geometry']={}
    for lod in ['near','far']:
        if lod=='far':
            for o in list(bpy.context.scene.objects):
                if o.type!='MESH' or len(o.data.polygons)<100:continue
                bpy.context.view_layer.objects.active=o;d=o.modifiers.new('Retain distant anatomical silhouette','DECIMATE');d.ratio=.28;bpy.ops.object.modifier_apply(modifier=d.name)
        path=OUT/(row['id']+'_'+lod+'.glb')
        bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',export_yup=True,export_animations=False,export_cameras=False,export_lights=False)
        triangles=0;pts=[]
        for o in bpy.context.scene.objects:
            if o.type!='MESH':continue
            o.data.calc_loop_triangles();triangles+=len(o.data.loop_triangles)
            pts.extend(o.matrix_world@v.co for v in o.data.vertices)
        gp=[(p.x,p.z,-p.y) for p in pts]
        lo=[min(p[i] for p in gp) for i in range(3)];hi=[max(p[i] for p in gp) for i in range(3)]
        row['lods'][lod]={'path':str(path.relative_to(ROOT)),'triangles':triangles,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
        row['geometry'][lod]={'min':lo,'max':hi,'floor_y':lo[1],'ceiling_y':hi[1],'vertices':len(gp)}
    row['mesh_nodes']=sum(o.type=='MESH' for o in bpy.context.scene.objects)
    if row['anatomy'] in [0,5] or row['id'] in LIMIT:
        bpy.ops.wm.open_mainfile(filepath=str(source));bpy.context.view_layer.update()
        source_render(row,[o.matrix_world@Vector(p) for o in bpy.context.scene.objects if o.type=='MESH' for p in o.bound_box])
    (SRC/(row['id']+'.json')).write_text(json.dumps(row,ensure_ascii=False,indent=2)+'\n')
    print('XENO_EXPORTED',row['id'],row['lods']['near']['triangles'],flush=True)
    return row

def catalog():
    forms=[];looks=[]
    for spec in recipes():
        path=SRC/(spec['id']+'.json')
        if not path.exists():continue
        row=json.loads(path.read_text())
        if row.get('art_revision')!=REV:continue
        forms.append(row)
        for p in range(5):
            palette=[]
            for c in row['palette']:
                h,s,val=colorsys.rgb_to_hsv(*B.rgb(c));cs=colorsys.hsv_to_rgb((h+(p-2)*.013)%1,min(.9,s*(.85+p*.075)),min(.88,val*(.90+p*.045)))
                palette.append(''.join('%02x'%round(x*255) for x in cs))
            for sz in range(4):looks.append({'id':row['id']+f'_p{p:02d}_s{sz:02d}','form_id':row['id'],'environment':row['environment'],'palette_index':p,'size_index':sz,'palette':palette,'scale':round(.88+sz*.08,3),'type':'appearance-variant','spawn_enabled':False})
    # Commit the separate extension catalogue only after every authored model exists.
    if len(forms)==300:
        (DATA/'xenofauna_forms.json').write_text(json.dumps({'version':1,'collection':COLLECTION,'form_count':300,'families':30,'forms':forms},ensure_ascii=False,indent=2)+'\n')
        (DATA/'xenofauna_appearances.json').write_text(json.dumps({'version':1,'count':len(looks),'appearances':looks},ensure_ascii=False,separators=(',',':'))+'\n')
    print('XENO_BUILD_PROGRESS',len(forms),'/300',flush=True)

if __name__=='__main__':
    for spec in recipes():
        if LIMIT and spec['id'] not in LIMIT and spec['family'] not in LIMIT:continue
        path=SRC/(spec['id']+'.json')
        if path.exists() and '--force' not in ARGS:
            old=json.loads(path.read_text())
            if old.get('art_revision')==REV and all((ROOT/l['path']).exists() for l in old.get('lods',{}).values()):continue
        build(spec)
    catalog()
