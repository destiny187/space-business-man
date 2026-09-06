"""Generate 500 authored visual forms / 20 structural families using Blender.
Bodies preserve named motion anchors; 10,000 appearances reuse these exported meshes.
"""
from pathlib import Path
import bpy, math, json, random, hashlib, sys, colorsys
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/bestiary'))
from roster import FAMILIES, ENVIRONMENTS
from eye_designs import EYE_DESIGNS
EYE_STYLE="original"
SRC=ROOT/'art/blender/bestiary'; OUT=ROOT/'우주-비즈니스/assets/models/bestiary'
DATA=ROOT/'우주-비즈니스/data/bestiary'
for p in [SRC,OUT,DATA]:p.mkdir(parents=True,exist_ok=True)
LIMIT=set()
if '--' in sys.argv:LIMIT=set(sys.argv[sys.argv.index('--')+1:])
def rgb(s):return tuple(int(s[i:i+2],16)/255 for i in (0,2,4))
def material(name,c,rough=.65,metal=0,emit=0):
 m=bpy.data.materials.new('Bio_'+name);m.diffuse_color=(*c,1);m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*c,1);p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
 if emit:p.inputs['Emission Color'].default_value=(*c,1);p.inputs['Emission Strength'].default_value=emit
 return m
def pivot(name,loc=(0,0,0),parent=None):
 o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.parent=parent;o.location=loc;return o
def finish(o,name,slot,parent,bevel=0,smooth=True):
 o.name=name;o.parent=parent;o.data.materials.append(M[slot])
 for f in o.data.polygons:f.use_smooth=smooth
 if bevel:
  b=o.modifiers.new('Soft worn edge','BEVEL');b.width=bevel;b.segments=3;o.modifiers.new('Face normals','WEIGHTED_NORMAL')
 return o
def oval(name,p,s,slot='main',parent=None,seg=24):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=seg,ring_count=12,radius=1,location=p);o=bpy.context.object;o.scale=s
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return finish(o,name,slot,parent or BODY)
def link(name,a,b,r,slot='main',parent=None):
 o=oval(name,(Vector(a)+Vector(b))/2,(r,r,(Vector(a)-Vector(b)).length/2+r*.5),slot,parent)
 o.rotation_euler=(Vector(b)-Vector(a)).to_track_quat('Z','Y').to_euler();return o
def horn(name,a,b,r,slot='bone',parent=None):
 bpy.ops.mesh.primitive_cone_add(vertices=16,radius1=r,radius2=.015,depth=(Vector(b)-Vector(a)).length,location=(Vector(a)+Vector(b))/2)
 o=bpy.context.object;o.rotation_euler=(Vector(b)-Vector(a)).to_track_quat('Z','Y').to_euler()
 return finish(o,name,slot,parent or BODY,.015,True)
def shield(name,p,s,slot='secondary',parent=None,tilt=0):
 verts=[];outline=[(-.8,-.65),(.1,-1),(.85,-.48),(.86,.45),(.14,.91),(-.80,.57)]
 for z,w in [(0,.87),(.18,1),(.58,.68)]:
  verts.extend([(x*s[0]*w,y*s[1]*w,z*s[2]) for x,y in outline])
 faces=[tuple(reversed(range(6))),tuple(range(12,18))]
 for row in range(2):
  for i in range(6):faces.append((row*6+i,row*6+(i+1)%6,(row+1)*6+(i+1)%6,(row+1)*6+i))
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update();o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);o.location=p;o.rotation_euler.y=tilt
 return finish(o,name,slot,parent or BODY,.035,False)
def blade(name,pts,width,slot='secondary',parent=None):
 # Curved, ridged leaf/fin/wing feather, thickness maintained at a readable scale.
 verts=[];faces=[]
 for i,p in enumerate(pts):
  t=i/(len(pts)-1);w=max(.004,math.sin(math.pi*t)**.7*width)
  verts.extend([(p[0]-w,p[1],p[2]),(p[0],p[1]-.05*math.sin(math.pi*t),p[2]+.035),(p[0]+w,p[1],p[2])])
 for i in range(len(pts)-1):
  for k in range(2):n=i*3+k;faces.append((n,n+1,n+4,n+3))
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update();o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o)
 finish(o,name,slot,parent or BODY)
 sol=o.modifiers.new('Real leaf thickness','SOLIDIFY');sol.thickness=.025
 return o
def tube(name,points,r,slot='main',parent=None):
 c=bpy.data.curves.new(name,'CURVE');c.dimensions='3D';c.resolution_u=8;c.bevel_depth=r;c.bevel_resolution=3
 spline=c.splines.new('BEZIER');spline.bezier_points.add(len(points)-1)
 for b,p in zip(spline.bezier_points,points):b.co=p;b.handle_left_type='AUTO';b.handle_right_type='AUTO'
 o=bpy.data.objects.new(name,c);bpy.context.collection.objects.link(o);o.parent=parent or BODY;o.data.materials.append(M[slot])
 bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.convert(target='MESH');return o
def eyes(head,width=.36,front=-.40,z=.04):
 style=EYE_STYLE
 if style=='stalk':return
 if style=='blind':
  for side in [-1,1]:
   for k in range(3):
    tube('Vibration receptor fold',[(side*width*.65,front-.03,z-.08+k*.075),(side*width,front-.095,z-.04+k*.075),(side*width*1.2,front-.03,z-.02+k*.075)],.026,'secondary',head)
  return
 if style=='diamond':
  y=front/.72-.025
  oval('Central dark orbit',(0,y,z+.035),(.25,.10,.25),'dark',head)
  # Four-sided lens tilted in its own plane, with a diamond aperture.
  for name,size,depth,slot in [('Diamond iris',.20,y-.085,'accent'),('Diamond pupil',.095,y-.14,'dark')]:
   verts=[(0,0,size),(size,0,0),(0,0,-size),(-size,0,0),(0,-.045,0),(0,.025,0)]
   faces=[(k,(k+1)%4,4) for k in range(4)]+[((k+1)%4,k,5) for k in range(4)]
   mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
   o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);o.location=(0,depth,z+.035)
   finish(o,name,slot,head,.008,False)
  return
 if style=='cluster':
  for k,(x,zz) in enumerate([(-.18,.04),(.18,.04),(-.12,.20),(.12,.20),(-.06,.33),(.06,.33)]):
   y=front/.72+.025+abs(x)*.15
   oval('Cluster orbit',(x,y,zz),(.068,.045,.068),'dark',head,16)
   oval('Small cluster lens',(x,y-.037,zz),(.041,.026,.041),'accent',head,16)
  return
 for side in [-1,1]:
  x=side*width
  if style=='compound':
   oval('Compound ocular shield',(x,front-.015,z),(.18,.11,.17),'dark',head)
   for k in range(7):
    a=k*math.tau/6;dx=0 if k==6 else .105*math.cos(a);dz=0 if k==6 else .10*math.sin(a)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=.067,location=(x+dx,front-.12,z+dz))
    o=bpy.context.object;o.scale.y=.60;finish(o,'Compound lens cell','accent' if k%2 else 'eye',head,0,False)
  elif style in ['horizontal','vertical']:
   horizontal=style=='horizontal';w,h=(.20,.09) if horizontal else (.115,.19)
   oval('Elongated orbit',(x,front-.025,z),(w,.10,h),'dark',head)
   oval('Shaped iris',(x,front-.105,z),(w*.81,.035,h*.80),'accent',head)
   oval('Aperture pupil',(x,front-.140,z),(w*.69 if horizontal else .023,.015,.020 if horizontal else h*.66),'dark',head)
   tube('Protective brow',[(x-w,front-.06,z+h*.48),(x,front-.09,z+h*1.05),(x+w,front-.06,z+h*.66)],.027,'secondary',head)
  elif style=='four':
   for level in [-1,1]:
    zz=z+level*.095
    oval('Stacked orbit',(x,front-.035,zz),(.11,.075,.075),'dark',head,20)
    oval('Stacked lens',(x,front-.10,zz),(.066,.034,.042),'accent',head,20)
    oval('Stacked pupil',(x,front-.133,zz),(.031,.012,.027),'dark',head,16)
  else:
   oval('Protected orbit',(x,front,z),(.15,.095,.13),'dark',head,20)
   oval('Sensory lens',(x,front-.072,z),(.080,.035,.076),'eye',head,20)
   oval('Lens pupil',(x,front-.100,z),(.027,.012,.052),'dark',head,16)
def head_at(p,size=(.43,.52,.35),jaw=True):
 h=pivot('Anim_Head',p,BODY);oval('Cranium',(0,0,0),size,'main',h);eyes(h,size[0]*.72,-size[1]*.72,.07)
 if jaw:
  j=pivot('Anim_Jaw',(0,-size[1]*.5,-size[2]*.55),h);oval('Lower mandible',(0,-.10,-.03),(size[0]*.73,size[1]*.70,.11),'secondary',j)
 pivot('FX_Mouth',(0,-size[1]*1.05,-.1),h)
 return h
def legs(rows,height,width=.5,length=.5,claws=True,insect=False):
 for row,y in enumerate(rows):
  for side in [-1,1]:
   leg=pivot('Anim_Leg_%d_%s'%(row,'L' if side<0 else 'R'),(side*width,y,height),BODY)
   knee=(side*length,.04,-height*.4);foot=(side*(length*.9 if not insect else length*1.4),-.14,-height+.13)
   link('Upper leg',(0,0,0),knee,.12 if insect else .19,'main',leg)
   link('Lower leg',knee,foot,.075 if insect else .14,'secondary',leg)
   if not insect:oval('Grounded foot',(foot[0],-.20,foot[2]),(.20,.27,.13),'main',leg)
   if claws and insect:
    horn('Connected tarsal claw',foot,(foot[0],foot[1]-.23,foot[2]-.06),.075,'bone',leg)
   elif claws:
    for t in range(3 if not insect else 1):horn('Digging claw',(foot[0]+(t-1)*.10,-.32,foot[2]-.02),(foot[0]+(t-1)*.10,-.55,foot[2]-.06),.065,'bone',leg)
def tail_at(p,length=1.0,fan=False):
 tail=pivot('Anim_Tail',p,BODY)
 tube('Curved tail',[(0,0,0),(0,length*.4,.08),(.16,length*.75,.12),(.25,length,.23)],.13,'main',tail)
 if fan:shield('Tail vane',(.25,length,.23),(.35,.37,.2),'accent',tail)
 return tail
def make_animal(f,v):
 u=v/4.; bulk=.9+u*.24
 if f=='lithic':
  oval('Mineral core',(0,0,.82),(1.02,1.40,.65),'main')
  for row,y in enumerate([-.85,-.12,.64,1.15]):
   z=[1.08,1.37,1.29,1.03][row]
   shield('Ridge shield',(0,y,z),(.5,.54,.46),'secondary')
   for side in [-1,1]:shield('Flank shield',(side*.68,y,z-.20),(.48,.48,.36),'secondary',tilt=side*.35)
  legs([-.8,.06,.83],.78,.70,.46)
  h=head_at((0,-1.35,.87),(.57,.57,.35));shield('Head crown',(0,-.05,.24),(.60,.54,.22),'secondary',h)
  for i in range(2+v):horn('Mineral crest',(0,-.3+i*.3,1.50),(0,-.2+i*.3,1.75+.06*v),.13,'accent')
  tail_at((0,1.19,.66),.7)
 elif f in ['grazer','stalker','burrower']:
  is_burrow=f=='burrower';height=.70 if is_burrow else 1.15+u*.18
  oval('Muscular torso',(0,.07,height),(.60*bulk,1.0,.48*bulk),'main')
  oval('Chest',(0,-.6,height+.04),(.55,.55,.54),'secondary')
  legs([-.66,.66],height-.18,.43,.31 if not is_burrow else .46)
  h=head_at((0,-1.04,height+.15),(.39,.56,.35))
  oval('Muzzle',(0,-.45,-.08),(.29,.33,.21),'secondary',h)
  for side in [-1,1]:
   if f=='grazer':
    horn('Antler stem',(side*.26,.06,.27),(side*.45,.30,.93+u*.25),.09,'bone',h)
    for j in range(2+v%3):horn('Antler tine',(side*(.32+j*.03),.12,.45+j*.16),(side*(.58+j*.05),-.08,.60+j*.16),.055,'bone',h)
    oval('Broad ear',(side*.53,.11,.3),(.23,.10,.10),'secondary',h)
   elif f=='stalker':
    horn('Alert ear',(side*.29,.04,.24),(side*.40,.16,.68+u*.13),.16,'main',h)
    for k in range(2):horn('Canine',(side*.22,-.60,-.07),(side*.22,-.62,-.28),.052,'bone',h)
   else:shield('Digging cheek',(side*.31,-.24,.15),(.27,.40,.25),'secondary',h)
  if f=='burrower':
   for y in [-.45,.0,.45,.85]:shield('Dorsal digging plate',(0,y,height+.36),(.5,.36,.38),'secondary')
  else:
   for i in range(3+v):shield('Shoulder coat tuft',((-.22 if i%2 else .22),-.56+i*.14,height+.47),(.23,.23,.20),'accent')
  tail_at((0,1.0,height-.13),.70+u*.5, f=='stalker')
 elif f=='runner':
  oval('Streamlined body',(0,.12,1.22),(.47,.72,.48),'main');legs([.21],1.02,.30,.18)
  tube('Raised neck',[(0,-.33,1.30),(0,-.61,1.56),(0,-.83,1.88)],.22,'secondary')
  h=head_at((0,-.84,1.88),(.29,.40,.26),False)
  horn('Beak',(0,-.26,-.01),(0,-.83,-.08),.20,'bone',h)
  for side in [-1,1]:
   wing=pivot('Anim_Wing_'+('L' if side<0 else 'R'),(side*.41,-.1,1.4),BODY)
   for k in range(4+v%2):blade('Layered wing quill',[(side*.02,0,0),(side*.14,.25,-.1),(side*.20,.57+k*.1,-.24)],.12,'accent' if k%2 else 'secondary',wing)
  for k in range(3+v%2):horn('Crown feather',((k-1)*.08,.05,.2),((k-1)*.1,.20,.55+u*.13),.07,'accent',h)
  tail_at((0,.74,1.23),.85+u*.3,True)
 elif f in ['carapace','mantid']:
  mantid=f=='mantid'
  oval('Articulated abdomen',(0,.3,1.05 if mantid else .73),(.40 if mantid else .85+v*.045,.96,.34),'main')
  legs([-.15,.54,1.0] if mantid else [-.58,.15,.75],.86 if mantid else .54,.33 if mantid else .68,.61 if mantid else .72,True,True)
  h=head_at((0,-.66,1.30 if mantid else .70),(.37,.30,.23),False)
  if mantid:
   for side in [-1,1]:tube('Antenna',[(side*.13,-.01,.18),(side*.23,-.10,.51),(side*.38,-.33,.68+u*.2)],.026,'accent',h)
  else:
   for row,y in enumerate([-.35,.23,.75]):shield('Carapace shield',(0,y,.98),(.86+v*.045,.43,.32),'secondary')
  for side in [-1,1]:
   arm=pivot('Anim_Arm_'+('L' if side<0 else 'R'),(side*.43,-.56,1.10 if mantid else .64),BODY)
   link('Raptorial arm',(0,0,0),(side*.48,-.38,.11),.11 if mantid else .18,'main',arm)
   if mantid:
    tube('Swept scythe',[(side*.48,-.38,.11),(side*.56,-.85,.42),(side*.38,-1.27,.36)],.08,'bone',arm)
    for k in range(4):horn('Scythe tooth',(side*.54,-.61-k*.13,.24),(side*.39,-.70-k*.13,.19),.042,'bone',arm)
   else:
    oval('Crushing pincer',(side*.61,-.66,.08),(.31,.44,.23),'secondary',arm)
    horn('Pincer tip',(side*.46,-.91,.12),(side*.39,-1.22,.10),.13,'bone',arm)
    horn('Pincer thumb',(side*.77,-.86,.06),(side*.59,-1.19,.07),.11,'bone',arm)
 elif f=='winged':
  oval('Flight thorax',(0,0,1.10),(.33,.70,.37),'main')
  h=head_at((0,-.62,1.22),(.31,.30,.24))
  for side in [-1,1]:
   w=pivot('Anim_Wing_'+('L' if side<0 else 'R'),(side*.27,0,1.24),BODY)
   span=1.4+u*.35
   for k in range(5):
    blade('Thick folded flight vane',[(side*.02,0,0),(side*(.63+k*.12),-.12+k*.20,.18),(side*(span-.10*k),-.17+k*.30,.04)],.22,'secondary' if k%2 else 'main',w)
    link('Wing finger',(0,0,0),(side*(span-.10*k),-.17+k*.30,.04),.035,'accent',w)
  legs([.3],.65,.2,.12)
  tail_at((0,.55,1.12),.7,True)
 elif f in ['swimmer','ray']:
  oval('Hydrodynamic mantle',(0,0,.72),(.52 if f=='swimmer' else .86,1.05,.47 if f=='swimmer' else .25),'main')
  h=head_at((0,-.83,.74),(.39,.39,.30 if f=='swimmer' else .17))
  for side in [-1,1]:
   w=pivot('Anim_Wing_'+('L' if side<0 else 'R'),(side*.4,0,.74),BODY)
   reach=.70 if f=='swimmer' else 1.44+u*.25
   for k in range(3):blade('Flexible fin lobe',[(0,0,0),(side*reach*.7,k*.20,.12),(side*reach,.50+k*.2,-.08)],.22,'secondary',w)
  tail=pivot('Anim_Tail',(0,.90,.74),BODY);tube('Tail stalk',[(0,0,0),(0,.4,0),(0,.8,-.02)],.12,'main',tail)
  for side in [-1,1]:blade('Caudal fin',[(0,.6,0),(side*.37,.95,.20),(side*.58,1.10,.36)],.17,'accent',tail)
  if f=='swimmer':
   for k in range(3+v):horn('Dorsal fin ray',(0,-.10+k*.18,1.11),(0,.02+k*.18,1.45+u*.12),.065,'secondary')
 elif f=='coil':
  for i in range(9):
   seg=pivot('Anim_Segment_%d'%i,(math.sin(i*.6)*.34,.94-i*.27,.31+.03*i),BODY)
   oval('Overlapping muscular ring',(0,0,0),(.31-i*.009,.27,.27),'main',seg)
   shield('Dorsal scale',(0,0,.20),(.27,.23,.13),'secondary',seg)
  h=head_at((math.sin(8*.6)*.34,-1.37,.60),(.34,.48,.28))
  for side in [-1,1]:horn('Sensory crest',(side*.2,.06,.19),(side*.35,.17,.47+u*.18),.085,'accent',h)
 elif f=='slug':
  oval('Mucosal foot',(0,0,.25),(.65,1.16,.22),'secondary')
  oval('Soft mantle',(0,.06,.59),(.55,.94,.38),'main')
  h=head_at((0,-.90,.55),(.38,.30,.24),False)
  for side in [-1,1]:
   tube('Sensory tentacle',[(side*.2,-.12,.10),(side*.35,-.40,.38),(side*.4,-.53,.46)],.045,'accent',h)
   oval('Tentacle eye',(side*.4,-.53,.46),(.08,.08,.08),'eye',h)
  for k in range(5+v):
   a=k*2.4;horn('Respiratory ceras',(math.cos(a)*.34,math.sin(a)*.61,.82),(math.cos(a)*.50,math.sin(a)*.71,1.13+u*.17),.13,'accent')
def make_plant(f,v):
 u=v/4.
 if f=='mist_leaf':
  for k in range(8+v):
   a=k*2.399;leaf=pivot('Anim_Frond_%d'%k,(math.cos(a)*.12,math.sin(a)*.12,0),BODY)
   h=1.25+(k%3)*.28+u*.25;r=.73+(k%2)*.18
   pts=[(math.cos(a)*r*t*t,math.sin(a)*r*t*t,h*(t-.34*t*t)) for t in [i/10 for i in range(11)]]
   blade('Cupped condensate leaf',pts,.20+u*.035,'secondary' if k%3 else 'main',leaf)
   tube('Central leaf rib',[(p[0],p[1]-.006,p[2]+.041) for p in pts[1:-1]],.010,'accent',leaf)
  oval('Root rosette',(0,0,.13),(.30,.30,.13),'main')
 elif f=='crystal_fan':
  for k in range(9+v):
   a=k*2.4;r=.30+(k%3)*.22;h=.80+(k%4)*.29+u*.24
   root=pivot('Anim_Frond_%d'%k,(math.cos(a)*r,math.sin(a)*r,.04),BODY)
   bpy.ops.mesh.primitive_cone_add(vertices=6,radius1=.20,radius2=.045,depth=h,location=(0,0,h/2))
   o=finish(bpy.context.object,'Reflecting mineral prism','secondary' if k%2 else 'main',root,.025,False);o.rotation_euler.y=math.cos(a)*.21
  for k in range(5):oval('Mineral substrate',(math.cos(k*1.26)*.35,math.sin(k*1.26)*.35,.08),(.35,.29,.10),'main',seg=16)
 elif f=='canopy_tree':
  tube('Buttressed trunk',[(0,0,0),(.03,.03,.9),(-.10,.04,1.8),(.10,0,2.60+u*.35)],.18+u*.04,'main')
  for k in range(6+v):
   a=k*2.4;z=1.30+(k%4)*.34;r=.70+(k%3)*.12
   start=(0,0,z);end=(math.cos(a)*r,math.sin(a)*r,z+.43)
   tube('Canopy branch',[start,(end[0]*.5,end[1]*.5,z+.16),end],.065,'main')
   fr=pivot('Anim_Frond_%d'%k,end,BODY)
   for j in range(5):
    b=j*1.256;blade('Broad canopy leaf',[(0,0,0),(math.cos(b)*.36,math.sin(b)*.36,.12),(math.cos(b)*.75,math.sin(b)*.75,.07)],.23,'secondary' if j%2 else 'accent',fr)
  for k in range(5):tube('Surface root',[(0,0,.26),(math.cos(k*1.26)*.40,math.sin(k*1.26)*.40,.08),(math.cos(k*1.26)*.72,math.sin(k*1.26)*.72,.03)],.095,'main')
 elif f=='spore_fungus':
  for k in range(6+v):
   a=k*2.4;r=.12+(k%3)*.3;h=.60+(k%4)*.35+u*.2
   fr=pivot('Anim_Frond_%d'%k,(math.cos(a)*r,math.sin(a)*r,0),BODY)
   tube('Curved stipe',[(0,0,.04),(.05,0,h*.5),(.12,0,h)],.085,'main',fr)
   oval('Thick umbrella cap',(.12,0,h),(.38+u*.08,.38+u*.08,.15),'secondary',fr)
   oval('Recessed gill disc',(.12,0,h-.08),(.30,.30,.045),'accent',fr)
   for j in range(4):
    b=j*1.57;oval('Cap nodule',(.12+math.cos(b)*.20,math.sin(b)*.20,h+.10),(.06,.06,.04),'bone',fr,16)
 elif f=='aquatic_frond':
  oval('Holdfast',(0,0,.10),(.36,.30,.13),'main')
  for k in range(7+v):
   a=k*2.4;fr=pivot('Anim_Frond_%d'%k,(math.cos(a)*.18,math.sin(a)*.18,0),BODY);h=1.25+(k%3)*.30
   pts=[(.20*math.sin(i*.50+k),math.sin(a)*i*.045,i*h/12) for i in range(13)]
   tube('Flexible stipe',pts,.028,'main',fr)
   for j in range(2,11,2):
    side=-1 if j%4 else 1;point=pts[j]
    blade('Ruffled aquatic blade',[point,(point[0]+side*.29,point[1]+.1,point[2]+.12),(point[0]+side*.53,point[1]+.20,point[2]+.22)],.13+u*.025,'secondary',fr)
def make_microbe(f,v):
 for k in range(10+v):
  a=k*2.4;r=.10+.07*k;fr=pivot('Anim_Frond_%d'%k,(math.cos(a)*r,math.sin(a)*r,0),BODY)
  if f=='acid_mat':
   oval('Microbial cushion',(0,0,.09),(.24,.22,.11),'main',fr)
   for j in range(3):oval('Reaction vesicle',((j-1)*.1,0,.20),(.09,.10,.14+(v%2)*.04),'secondary',fr,20)
  elif f=='thermal_colony':
   h=.34+(k%4)*.18+v*.04
   tube('Chimney biofilm',[(0,0,.04),(.02,0,h*.4),(.08,0,h)],.10,'main',fr)
   bpy.ops.mesh.primitive_torus_add(major_radius=.105,minor_radius=.035,major_segments=20,minor_segments=8,location=(.08,0,h))
   finish(bpy.context.object,'Open vent rim','secondary',fr)
   oval('Vent opening',(.08,0,h-.035),(.078,.078,.035),'dark',fr,16)
  else:
   oval('Photosynthetic cushion',(0,0,.12),(.26,.24,.15),'main',fr)
   for j in range(4):oval('Lobed gas sac',(math.cos(j*1.57)*.11,math.sin(j*1.57)*.11,.25),(.11,.12,.17),'secondary',fr,20)
  tube('Connecting substrate filament',[(0,0,.03),(.12,.18,.06),(.29,.2,.04)],.026,'accent',fr)

def anatomy_variation(family,category,anatomy):
 # Five authored anatomical packages per environmental form; never colour-only meshes.
 if anatomy==0:return
 if category=='animal':
  h=bpy.data.objects.get('Anim_Head')
  if h:
   if anatomy==1:
    for side in [-1,1]:
     shield('Broad lateral head armor',(side*.29,.05,.20),(.26,.34,.21),'secondary',h,side*.28)
     horn('Swept head horn',(side*.20,.11,.23),(side*.34,.39,.61),.09,'bone',h)
   elif anatomy==2:
    for side in [-1,1]:
     for k in range(3):
      blade('Layered sensory frill',[(side*.18,.1,.1),(side*(.48+k*.05),.16+k*.13,.26),(side*(.72+k*.05),.22+k*.16,.36)],.13,'accent' if k%2 else 'secondary',h)
   elif anatomy==3:
    for k in range(3):
     horn('Forked crown',((k-1)*.14,.06,.23),((k-1)*.22,.23,.69-abs(k-1)*.13),.08,'bone',h)
    oval('Expanded nasal bridge',(0,-.24,.16),(.24,.30,.15),'secondary',h)
   else:
    oval('Extended rostrum',(0,-.34,-.04),(.25,.42,.18),'main',h)
    for side in [-1,1]:
     horn('Forward cheek tine',(side*.25,-.12,.05),(side*.41,-.63,.10),.085,'bone',h)
  # Body profile changes are local to the torso, leaving foot dimensions stable.
  for o in list(bpy.context.scene.objects):
   if o.type=='MESH' and o.parent==BODY and any(n in o.name for n in ['torso','abdomen','mantle','body','core']):
    o.scale.x*= [1,1.13,.94,1.05,.90][anatomy]
    o.scale.y*= [1,.96,1.08,1.02,1.18][anatomy]
 else:
  points=[(math.cos(k*2.4)*.55,math.sin(k*2.4)*.55,.15) for k in range(5)]
  for k,point in enumerate(points):
   fr=pivot('Anim_Appendage_%d'%k,point,BODY)
   h=.55 if category=='microbe' else .95
   if anatomy==1:
    tube('Branching support',[(0,0,0),(.1,0,h*.5),(0,0,h)],.045,'main',fr)
    for side in [-1,1]:
     blade('Secondary fan lobe',[(0,0,h*.5),(side*.24,0,h*.8),(side*.37,.1,h)],.13,'accent',fr)
   elif anatomy==2:
    tube('Arched fruit stem',[(0,0,0),(.10,0,h),(.3,.1,h*.8)],.035,'main',fr)
    oval('Pendant spore capsule',(.3,.1,h*.67),(.14,.13,.22),'accent',fr)
    for j in range(3):shield('Capsule scale',(.3+(j-1)*.07,.00,h*.69),(.07,.1,.09),'secondary',fr)
   elif anatomy==3:
    for j in range(3):
     a=j*2.09;tube('Spiral filament',[(0,0,0),(math.cos(a)*.2,math.sin(a)*.2,h*.5),(math.cos(a+.9)*.27,math.sin(a+.9)*.27,h)],.035,'secondary',fr)
   else:
    for j in range(4):
     a=j*1.57;blade('Low buttress leaf',[(0,0,.02),(math.cos(a)*.27,math.sin(a)*.27,.15),(math.cos(a)*.55,math.sin(a)*.55,.08)],.18,'secondary' if j%2 else 'main',fr)

def export_form(row):
 bpy.context.view_layer.update()
 vertices=[o.matrix_world@Vector(c) for o in bpy.context.scene.objects if o.type=='MESH' for c in o.bound_box]
 floor=min(p.z for p in vertices);BODY.location.z-=floor
 bpy.context.view_layer.update()
 bpy.ops.wm.save_as_mainfile(filepath=str(SRC/(row['id']+'.blend')))
 for o in list(bpy.context.scene.objects):
  if o.type!='MESH':continue
  bpy.context.view_layer.objects.active=o
  for mod in list(o.modifiers):bpy.ops.object.modifier_apply(modifier=mod.name)
 groups={}
 for o in list(bpy.context.scene.objects):
  if o.type=='MESH':groups.setdefault((o.parent.name,o.data.materials[0].name),[]).append(o)
 for group in groups.values():
  bpy.ops.object.select_all(action='DESELECT')
  for o in group:o.select_set(True)
  bpy.context.view_layer.objects.active=group[0]
  if len(group)>1:bpy.ops.object.join()
 outputs={}
 for lod in ['near','far']:
  if lod=='far':
   for o in list(bpy.context.scene.objects):
    if o.type!='MESH' or len(o.data.polygons)<80:continue
    bpy.context.view_layer.objects.active=o;d=o.modifiers.new('Distant silhouette','DECIMATE');d.ratio=.32;bpy.ops.object.modifier_apply(modifier=d.name)
  p=OUT/(row['id']+'_'+lod+'.glb')
  bpy.ops.export_scene.gltf(filepath=str(p),export_format='GLB',export_yup=True,export_animations=False)
  tris=0
  for o in bpy.context.scene.objects:
   if o.type=='MESH':o.data.calc_loop_triangles();tris+=len(o.data.loop_triangles)
  outputs[lod]={'path':str(p.relative_to(ROOT)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'triangles':tris}
 row['lods']=outputs;row['source']=str((SRC/(row['id']+'.blend')).relative_to(ROOT))
 row['pivots']=[o.name for o in bpy.context.scene.objects if o.type=='EMPTY']
 row['mesh_nodes']=sum(o.type=='MESH' for o in bpy.context.scene.objects)
 return row
def generate_base():
 global M,BODY,EYE_STYLE
 previous=json.loads((DATA/"forms.json").read_text()) if (DATA/"forms.json").exists() else {"forms":[]}
 previous_by_id={r["id"]:r for r in previous["forms"]}
 catalog=[];variants=[]
 for family_index,(family,label,category,attack,environments,names) in enumerate(FAMILIES):
  for form_number in range(25):
   morph=form_number//5;anatomy=form_number%5
   case_id='bio_'+family+'_%02d'%(form_number+1);env=environments[morph];cfg=ENVIRONMENTS[env]
   row={'form_schema':2,'id':case_id,'name':names[morph]+' '+['기본형','갑주형','부채형','분지형','확장형'][anatomy]+' '+label,'family':family,'family_name':label,'category':category,'environment':env,'environment_label':cfg['label'],'habitat_note':cfg['condition'],'morphology':morph,'anatomy':anatomy,'attack':attack,'render_status':'generated-unverified','spawn_enabled':False,'palette':cfg['palette'],'variant_count':20}
   record=SRC/(case_id+'.json')
   existing=json.loads(record.read_text()) if record.exists() else {}
   row['form_schema']=3 if family in ['carapace','mantid'] else 2
   if case_id in EYE_DESIGNS:
    row['form_schema']=5 if case_id=='bio_lithic_16' else 4
    row['eye_design'],row['eye_count'],row['sensory_type']=EYE_DESIGNS[case_id]
   reusable=existing.get('form_schema')==row['form_schema'] and all((ROOT/x['path']).exists() for x in existing.get('lods',{}).values()) and len(existing.get('lods',{}))==2
   if reusable:
    row=existing
    prior=previous_by_id.get(case_id,{})
    if prior.get("lods")==row.get("lods"):
     for key in ["geometry","render_status"]:
      if key in prior:row[key]=prior[key]
   elif not LIMIT or case_id in LIMIT or family in LIMIT:
    random.seed(7163+family_index*101+form_number)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    M={key:material(key,rgb(c),emit=.16 if key=='eye' else 0) for key,c in {'main':cfg['palette'][0],'secondary':cfg['palette'][1],'accent':cfg['palette'][2],'dark':'17272b','bone':'d5d3a5','eye':'e3ae4c'}.items()}
    BODY=pivot('Anim_Body')
    EYE_STYLE=EYE_DESIGNS.get(case_id,("original",))[0]
    if category=='animal':make_animal(family,morph)
    elif category=='plant':make_plant(family,morph)
    else:make_microbe(family,morph)
    anatomy_variation(family,category,anatomy)
    row=export_form(row);record.write_text(json.dumps(row,ensure_ascii=False,indent=2)+'\n')
    print('BESTIARY_FORM_COMPLETE',case_id,flush=True)
   else:continue
   catalog.append(row)
   for palette_index in range(5):
    adjusted=[]
    for c in cfg['palette']:
     r,g,b=rgb(c);h,s,v=colorsys.rgb_to_hsv(r,g,b)
     rr,gg,bb=colorsys.hsv_to_rgb((h+(palette_index-2)*.013)%1,max(.1,min(.9,s*(.85+palette_index*.075))),max(.15,min(.88,v*(.90+palette_index*.045))))
     adjusted.append(''.join('%02x'%round(x*255) for x in (rr,gg,bb)))
    for size_index in range(4):
     variants.append({'id':case_id+'_p%02d_s%02d'%(palette_index,size_index),'form_id':case_id,'environment':env,'palette_index':palette_index,'size_index':size_index,'palette':adjusted,'scale':round(.88+size_index*.08,3),'type':'appearance-variant','spawn_enabled':False})
 base_families={x[0] for x in FAMILIES}
 old=json.loads((DATA/'forms.json').read_text()) if (DATA/'forms.json').exists() else {'forms':[]}
 extra=[r for r in old['forms'] if r['family'] not in base_families]
 extra_ids={r['id'] for r in extra}
 if extra:
  catalog.extend(extra)
  variants.extend(r for r in json.loads((DATA/'appearances.json').read_text())['appearances'] if r['form_id'] in extra_ids)
 (DATA/'forms.json').write_text(json.dumps({'version':2,'families':len({r['family'] for r in catalog}),'form_count':len(catalog),'forms':catalog,'scope':'visuals only; no ecological or combat stats'},ensure_ascii=False,indent=2)+'\n')
 (DATA/'appearances.json').write_text(json.dumps({'version':2,'count':len(variants),'appearances':variants},ensure_ascii=False,separators=(',',':'))+'\n')
 (DATA/'environments.json').write_text(json.dumps(ENVIRONMENTS,ensure_ascii=False,indent=2)+'\n')
 print('BESTIARY_BUILD_COMPLETE',len(catalog),len(variants),flush=True)

if __name__=="__main__":generate_base()
