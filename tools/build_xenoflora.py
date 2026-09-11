"""Blender authoring: 60 alien rooted plants + 40 visible microbial colonies.
Reuse INK source/LOD export and real renders; never rewrite the 900 earlier forms.
"""
from pathlib import Path
import sys,math,json,colorsys
import bpy
ROOT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(ROOT/'tools'),str(ROOT/'tools/bestiary')]
import build_xenofauna as X
from xenoflora_roster import recipes,COLLECTION
from mathutils import Vector
B=X.B;TAU=math.tau
X.SRC=ROOT/'art/blender/xenoflora';X.OUT=ROOT/'우주-비즈니스/assets/models/xenoflora'
X.REVIEW=ROOT/'docs/production/media/xenoflora';X.REV='xenoflora-ink-1'
for p in [X.SRC,X.OUT,X.REVIEW/'blender']:p.mkdir(parents=True,exist_ok=True)
def rooted(v,w=.8):
    X.oval('Rhizome',(0,0,.15),(w*.45,w*.40,.15),'secondary')
    for k in range(3+v):
        a=k*TAU/(3+v)
        X.tube('Anchored branching root',[(0,0,.21),(.38*w*math.cos(a),.38*w*math.sin(a),.12),(.72*w*math.cos(a),.72*w*math.sin(a),.035)],.055,'secondary')
def mat_base(v,w=1):
    X.oval('Visible colony basal matrix',(0,0,.08),(.82*w,.62*w,.10),'secondary')
    for k in range(3+v):
        a=k*TAU/(3+v)
        X.oval('Colony growing margin',(.6*w*math.cos(a),.48*w*math.sin(a),.065),(.29,.24,.085),'main')
def leaf(name,pts,width=.22,slot='main',parent=None):
    obj=X.membrane(name,pts,width,slot,parent)
    for face in obj.data.polygons:face.use_smooth=True
    return obj
def band(name,p,rx,rz,width,parent,twist=1):
    verts=[];faces=[]
    for k in range(65):
        a=k*TAU/64;center=Vector((math.cos(a)*rx,0,math.sin(a)*rz))
        radial=Vector((math.cos(a),0,math.sin(a)));side=Vector((0,1,0))*math.cos(a*twist)+radial*math.sin(a*twist)
        for u in [-1,-.5,0,.5,1]:verts.append(tuple(Vector(p)+center+side*u*width))
    for k in range(64):
        for j in range(4):i=k*5+j;faces.append((i,i+1,i+6,i+5))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj);B.finish(obj,name,'main',parent)
    for face in mesh.polygons:face.use_smooth=True
    solid=obj.modifiers.new('Fleshy leaf thickness','SOLIDIFY');solid.thickness=.045
    bevel=obj.modifiers.new('Living leaf rim','BEVEL');bevel.width=.025;bevel.segments=3
    return obj
def construct(row):
    f=row['family'];v=row['anatomy'];p=row['body_plan'];n=p['radial_count'];w=p['width'];h=p['height'];body=B.BODY
    if row['category']=='plant':rooted(v,w)
    else:mat_base(v,w)
    if f=='loop_frond':
        X.tube('Central rolled stem',[(0,0,.12),(0,.08,.75*h),(0,0,1.2*h)],.10,'secondary')
        for j in range(1+v):
            a=j*TAU/(1+v);q=B.pivot('Anim_Frond_%d'%j,(0,0,.55*h),body);q.rotation_euler.z=a
            band('Closed twisted ribbon leaf',(.32*w,0,.42*h),.48*w,.60*h,.13,q,1+(v==4))
            X.tube('Ribbon petiole',[(0,0,-.2),(-.1,0,.1),(-.12,0,.38*h)],.055,'accent',q)
    elif f=='lantern_root':
        for k in range(n):
            a=k*TAU/n;X.tube('Arch root trunk',[(.78*w*math.cos(a),.78*w*math.sin(a),.03),(.55*w*math.cos(a),.55*w*math.sin(a),.9*h),(0,0,1.55*h)],.095,'secondary')
        for j in range(1+v):
            a=j*TAU/(1+v);q=B.pivot('Anim_Appendage_%d'%j,(.22*math.cos(a),.22*math.sin(a),1.5*h),body)
            X.tube('Suspended seed stalk',[(0,0,0),(0,0,-.45*h)],.045,'secondary',q)
            X.oval('Veined living lantern',(0,0,-.67*h),(.22,.22,.34),'accent',q)
            for k in range(4):
                b=k*TAU/4;X.tube('Lantern outer rib',[(0,0,-.38*h),(.22*math.cos(b),.22*math.sin(b),-.65*h),(0,0,-.96*h)],.025,'main',q)
        for k in range(n):
            a=k*TAU/n;q=B.pivot('Anim_Frond_%d'%k,(0,0,1.5*h),body);q.rotation_euler.z=a
            leaf('Top catchment leaf',[(0,0,0),(.35,0,.3*h),(.70*w,0,.05)],.25,parent=q)
    elif f=='spiral_cup_tree':
        pts=[(.25*w*math.cos(k*TAU/36),.25*w*math.sin(k*TAU/36),.16+k/36*1.6*h) for k in range(37)]
        X.tube('Winding living trunk',pts,.11,'secondary')
        for k in range(n):
            z=.48+k/(n-1)*1.2*h;a=(z-.16)/(1.6*h)*TAU;at=(.25*w*math.cos(a),.25*w*math.sin(a),z)
            q=B.pivot('Anim_Petal_%d'%k,at,body);q.rotation_euler.z=a
            X.tube('Cup petiole',[(0,0,0),(.30,0,.12)],.055,'secondary',q)
            X.cup('Thick cupped leaf',(.35,0,.06),.20+.012*v,.30,32,'main',q,flare=.25)
    elif f=='mirror_reed':
        for j in range(2+(v//2)):
            x=(j-(1+v//2)*.5)*.38*w
            X.tube('Split reed trunk',[(0,0,.1),(x,0,.55),(x,.05,1.6*h)],.065,'secondary')
            for s in [-1,1]:
                q=B.pivot('Anim_Frond_%d_%d'%(j,s),(x,0,.55),body)
                leaf('Opposing concave sail',[(0,0,0),(s*.48*w,.07,.55*h),(s*.12,0,1.05*h)],.28+.02*v,parent=q)
                X.tube('Sail main rib',[(0,0,0),(s*.22,0,.60*h),(s*.12,0,1.05*h)],.026,'accent',q)
    elif f=='lattice_orchid':
        X.tube('Orchid trunk',[(0,0,.12),(0,.07,.70*h)],.12,'secondary')
        levels=2+(v>=3)
        for level in range(levels):
            z=.65+level*.53*h;r=(.44+level*.08)*w
            for k in range(n):
                a=k*TAU/n;b=(k+1)*TAU/n;at=(r*math.cos(a),r*math.sin(a),z)
                if level==0:X.tube('Calyx rooted radial support',[(0,.07,.70*h),at],.055,'secondary')
                X.tube('Hollow calyx edge',[at,(r*math.cos(b),r*math.sin(b),z)],.05,'secondary')
                if level<levels-1:X.tube('Flower skeletal strut',[at,((r+.08)*math.cos(a),(r+.08)*math.sin(a),z+.53*h)],.055,'accent')
                else:
                    q=B.pivot('Anim_Petal_%d'%k,at,body);q.rotation_euler.z=a
                    leaf('Corner petal',[(0,0,0),(.34,0,.30),(.49*w,0,.05)],.24,parent=q)
        X.oval('Recessed central pistil',(0,0,.8*h),(.2,.2,.19),'accent')
    elif f=='bell_vine':
        for side in [-1,1]:X.tube('Bent anchored vine',[(side*.70*w,0,.04),(side*.58*w,0,.92*h),(0,0,1.48*h)],.09,'secondary')
        X.tube('Connected flowering arch',[(x,0,1.48*h-abs(x)*.5) for x in [(k/24-.5)*1.25*w for k in range(25)]],.065,'secondary')
        for k in range(n):
            x=(k/(n-1)-.5)*1.25*w;z=1.48*h-abs(x)*.5
            q=B.pivot('Anim_Petal_%d'%k,(x,0,z),body)
            X.tube('Bell stalk',[(0,0,0),(0,0,-.22)],.04,'secondary',q)
            sub=B.pivot('Bell downward orientation',(0,0,-.15),q);sub.rotation_euler.x=math.pi
            X.cup('Open suspended flower',(0,0,0),.15,.30+.035*v,32,'main',sub,flare=.45)
        leaf('Basal vine leaf',[(-.35,0,.15),(-.65,.1,.50),(-.94*w,0,.34)],.22)
    elif f=='folded_crown':
        X.tube('Folded crown stem',[(0,0,.1),(0,0,.80*h)],.12,'secondary')
        for k in range(n):
            a=k*TAU/n;q=B.pivot('Anim_Frond_%d'%k,(0,0,.66*h),body);q.rotation_euler.z=a
            for j in range(2+(v//2)):
                y=(j-(1+v//2)*.5)*.19
                leaf('Concertina leaf lobe',[(0,0,0),(.40*w,y,.28*h),(.90*w,y,.64*h),(.99*w,y,.35*h)],.18,parent=q)
            X.tube('Crown leaf midrib',[(0,0,0),(.42,0,.3*h),(.90*w,0,.55*h)],.03,'accent',q)
    elif f=='bladder_cactus':
        centers=[]
        for k in range(n):
            a=k*2.399;r=.40 if k else 0;at=(r*w*math.cos(a),r*w*math.sin(a),.46+(k%3)*.36*h);centers.append(at)
            q=B.pivot('Anim_Appendage_%d'%k,at,body)
            X.tube('Saccate rooted stem',[(0,0,-at[2]+.12),(0,0,0)],.055,'secondary',q)
            X.oval('Water storage bladder',(0,0,0),(.23,.23,.32*h),'main',q)
            X.ring('Bladder growth seam',(0,0,.04),.225,.225,.025,'accent',q)
            X.cup('Apical photosynthetic cup',(0,0,.25*h),.09,.16,24,'secondary',q)
        X.tube('Connected living isthmus',centers,.065,'secondary')
    elif f=='comb_tendril':
        def comb_height(x):return (.55+.25*math.cos(x/w*1.3)+.18*x/w)*h
        X.tube('Rooted comb trunk',[(0,0,.12),(-.1,0,.43*h),(0,0,comb_height(0))],.09,'secondary')
        X.tube('Curved horizontal stem',[(x,0,comb_height(x)) for x in [(k/16-.5)*1.8*w for k in range(17)]],.075,'secondary')
        for k in range(n):
            x=(k/(n-1)-.5)*1.7*w;z=comb_height(x)
            for s in [-1,1]:
                q=B.pivot('Anim_Frond_%d_%d'%(k,s),(x,0,z),body)
                leaf('Curled comb paddle',[(0,0,0),(.12,s*.35,.24),(.12,s*.63*w,.65*h),(.02,s*.50*w,.74*h)],.18,parent=q)
    elif f=='eclipse_bloom':
        X.tube('Eclipse stalk',[(0,0,.12),(0,0,.95*h)],.11,'secondary')
        for j in range(1+(v//2)):
            X.tube('Annular flower basal branch',[(0,0,.4*h),(0,j*.25,1.15*h+j*.22-.55*h)],.07,'secondary')
            q=B.pivot('Anim_Petal_%d'%j,(0,j*.25,1.15*h+j*.22),body)
            X.ring('Open annular flower',(0,0,0),.52*w,.55*h,.12,'accent',q,'xz')
            for k in range(n):
                a=k*TAU/n;at=(.5*w*math.cos(a),0,.53*h*math.sin(a))
                leaf('Light collecting petal',[at,(at[0]*1.4,-.08,at[2]*1.4),(at[0]*1.7,.1,at[2]*1.7)],.17,'main',q)
    elif f=='coral_scroll':
        X.tube('Branched scroll trunk',[(0,0,.1),(0,0,.6*h)],.13,'secondary')
        for k in range(n):
            a=k*TAU/n;q=B.pivot('Anim_Frond_%d'%k,(0,0,.52*h),body);q.rotation_euler.z=a
            X.tube('Forking leafy branch',[(0,0,0),(.40*w,0,.36*h),(.65*w,0,.82*h)],.065,'secondary',q)
            for s in [-1,1]:
                X.tube('Scroll leaf petiole',[(.40*w,0,.36*h),(.55*w,s*.16,.72*h-.30)],.055,'secondary',q)
                band('Rolled terminal leaf',(.55*w,s*.16,.72*h),.23,.30,.075,q,1)
    elif f=='nested_pod':
        X.tube('Nested pod stem',[(0,0,.1),(0,0,.35+(1+v)*.19*h+.13)],.13,'secondary')
        for k in range(2+v):
            r=(.66-k*.07)*w;z=.35+k*.19*h;q=B.pivot('Anim_Petal_%d'%k,(0,0,z),body)
            for s in [-1,1]:
                leaf('Open seed pod valve',[(0,-r,0),(s*r,0,.17),(0,r,.20*h)],.24 if k==0 else .18,'main' if k%2 else 'secondary',q)
                X.tube('Pod valve living support',[(0,0,0),(s*r*.5,0,.12),(s*r,0,.17)],.04,'accent',q)
            X.oval('Visible inner seed',(0,0,.13),(.16,.22,.16),'accent',q)
    elif f=='siphon_mosaic':
        for k in range(n+2):
            a=k*2.399;r=.48*math.sqrt(k/(n+1));q=B.pivot('Anim_Appendage_%d'%k,(r*w*math.cos(a),r*w*math.sin(a),.1),body)
            X.cup('Open metabolic siphon',(0,0,0),.12+(k%2)*.035,.32+(k%3)*.1*h,32,'main',q,flare=.15)
    elif f=='vesicle_raft':
        centers=[]
        for k in range(n+1):
            a=k*2.399;r=.53*math.sqrt(k/n);at=(r*w*math.cos(a),r*w*math.sin(a),.16+(k%2)*.07);centers.append(at)
            q=B.pivot('Anim_Appendage_%d'%k,at,body);X.oval('Gas storage vesicle',(0,0,.08),(.18,.18,.23*h),'main',q)
            X.ring('Vesicle growth collar',(0,0,.0),.15,.15,.023,'accent',q)
        X.tube('Shared biofilm cord',centers,.042,'accent')
    elif f=='quorum_spires':
        for k in range(2+v):
            a=k*TAU/(2+v);q=B.pivot('Anim_Appendage_%d'%k,(.4*w*math.cos(a),.4*w*math.sin(a),.1),body)
            height=.55+(k%3)*.20*h
            for j in range(3):
                b=j*TAU/3;X.tube('Perforated tower rib',[(.17*math.cos(b),.17*math.sin(b),0),(.22*math.cos(b),.22*math.sin(b),height*.5),(.09*math.cos(b),.09*math.sin(b),height)],.065,'main',q)
            for j in range(3):X.ring('Open tower collar',(0,0,j*height/2),.19-j*.04,.19-j*.04,.042,'secondary',q)
    elif f=='channel_rosette':
        X.cup('Central metabolite basin',(0,0,.09),.18,.13,32,'accent')
        for k in range(n):
            a=k*TAU/n;q=B.pivot('Anim_Appendage_%d'%k,(0,0,.12),body);q.rotation_euler.z=a
            pts=[(.14,0,0),(.36*w,.08,.10),(.68*w,.15,.17),(.73*w,-.09,.12),(.53*w,-.14,.08)]
            for s in [-1,1]:X.tube('Open channel wall',[(x,y+s*.055,z) for x,y,z in pts],.04,'main',q)
            leaf('Channel living floor',pts,.075,'secondary',q)
    elif f=='braided_film':
        for k in range(2+v):
            q=B.pivot('Anim_Frond_%d'%k,(0,0,.22),body);q.rotation_euler.z=k*TAU/(2+v)
            band('Thick twisted microbial curtain',(0,0,.18*h),.62*w,.26*h,.12,q,1)
        X.oval('Coalesced colony core',(0,0,.19),(.25,.25,.18),'accent')
    elif f=='prismatic_pustule':
        for k in range(n+1):
            a=k*2.399;r=.55*math.sqrt(k/n);q=B.pivot('Anim_Appendage_%d'%k,(r*w*math.cos(a),r*w*math.sin(a),.12),body)
            X.oval('Fleshy metabolic nodule',(0,0,.11),(.19,.16,.20*h),'main',q)
            for j in range(3):
                b=j*TAU/3;X.tube('Contrasting division septum',[(.17*math.cos(b),.14*math.sin(b),.04),(0,0,.3*h),(-.14*math.cos(b),-.12*math.sin(b),.03)],.023,'accent',q)
    elif f=='lace_colony':
        for k in range(n):
            a=k*TAU/n;q=B.pivot('Anim_Appendage_%d'%k,(0,0,.11),body);q.rotation_euler.z=a
            X.tube('Porous dome arch',[(.64*w,0,0),(.49*w,0,.42*h),(0,0,.65*h),(-.49*w,0,.42*h),(-.64*w,0,0)],.08,'main',q)
        for j in range(1+(v//2)):X.ring('Dome connected biofilm',(0,0,.20+j*.16*h),(.59-j*.10)*w,(.59-j*.10)*w,.055,'secondary')
        X.oval('Recessed colony substrate',(0,0,.13),(.35,.35,.15),'accent')
    elif f=='tidal_stromat':
        for j in range(3+v):
            q=B.pivot('Anim_Segment_%d'%j,(0,0,.08+j*.085*h),body);r=(.70-j*.065)*w
            pts=[(r*(1+.12*math.cos(k*TAU/32*n))*math.cos(k*TAU/32),r*.77*(1+.12*math.cos(k*TAU/32*n))*math.sin(k*TAU/32),.025*math.sin(k*TAU/32*3)) for k in range(33)]
            X.tube('Wavy stromatolite growth terrace',pts,.075,'main' if j%2 else 'secondary',q)
        X.cup('Central humid basin',(0,0,.1),.23,.18,32,'accent')
    else:raise ValueError(f)
X.construct=construct
def catalog():
    forms=[];looks=[]
    for spec in recipes():
        file=X.SRC/(spec['id']+'.json')
        if not file.exists():continue
        row=json.loads(file.read_text())
        if row.get('art_revision')!=X.REV:continue
        for key in ['name','anatomy_note','habitat_note']:row[key]=spec[key]
        file.write_text(json.dumps(row,ensure_ascii=False,indent=2)+'\n')
        forms.append(row)
        for p in range(5):
            palette=[]
            for c in row['palette']:
                h,s,val=colorsys.rgb_to_hsv(*B.rgb(c));rgb=colorsys.hsv_to_rgb((h+(p-2)*.016)%1,min(.9,s*(.90+p*.05)),min(.88,val*(.90+p*.04)))
                palette.append(''.join('%02x'%round(x*255) for x in rgb))
            for sz in range(4):looks.append({'id':row['id']+f'_p{p:02d}_s{sz:02d}','form_id':row['id'],'environment':row['environment'],'palette_index':p,'size_index':sz,'palette':palette,'scale':round(.88+sz*.08,3),'type':'appearance-variant','spawn_enabled':False})
    if len(forms)==100:
        data=ROOT/'우주-비즈니스/data/bestiary'
        (data/'xenoflora_forms.json').write_text(json.dumps({'version':1,'collection':COLLECTION,'form_count':100,'plants':60,'microbes':40,'families':20,'forms':forms},ensure_ascii=False,indent=2)+'\n')
        (data/'xenoflora_appearances.json').write_text(json.dumps({'version':1,'count':2000,'appearances':looks},ensure_ascii=False,separators=(',',':'))+'\n')
    print('XENOFLORA_PROGRESS',len(forms),'/100',flush=True)
if __name__=='__main__':
    for spec in recipes():
        if X.LIMIT and spec['id'] not in X.LIMIT and spec['family'] not in X.LIMIT:continue
        file=X.SRC/(spec['id']+'.json')
        if file.exists() and '--force' not in X.ARGS and json.loads(file.read_text()).get('art_revision')==X.REV:continue
        result=X.build(spec)
        result['generator']='tools/build_xenoflora.py';file.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
        if spec['anatomy']==4:
            bpy.ops.wm.open_mainfile(filepath=str(X.SRC/(spec['id']+'.blend')));bpy.context.view_layer.update()
            X.source_render(spec,[o.matrix_world@Vector(p) for o in bpy.context.scene.objects if o.type=='MESH' for p in o.bound_box])
    catalog()
