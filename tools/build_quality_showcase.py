"""Original high detail art study. Blender 5.x -> editable blend + Godot glTF.
Run: /Applications/Blender.app/Contents/MacOS/Blender -b --python tools/build_quality_showcase.py
"""
from pathlib import Path
import bpy, math, random, json
from mathutils import Vector
R=Path(__file__).resolve().parents[1]
SRC=R/'art/blender/showcase'; OUT=R/'우주-비즈니스/assets/models/showcase'
random.seed(9206)
previous_manifest=json.loads((SRC/'manifest.json').read_text()) if (SRC/'manifest.json').exists() else {'assets':{}}
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)

def mat(name,col,metal=0,rough=.4,glow=0):
 m=bpy.data.materials.new(name); m.diffuse_color=(*col,1); m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*col,1)
 p.inputs['Metallic'].default_value=metal; p.inputs['Roughness'].default_value=rough
 p.inputs['Emission Color'].default_value=(*col,1); p.inputs['Emission Strength'].default_value=glow
 return m
P={'ochre':mat('Paint | marigold',(.92,.37,.045),.25,.32),'white':mat('Paint | warm porcelain',(.84,.87,.76),.1,.28),'dark':mat('Chassis | midnight',(.022,.045,.056),.45,.38),'steel':mat('Metal | brushed titanium',(.29,.4,.43),.8,.24),'rubber':mat('Rubber | vulcanized',(.015,.026,.03),0,.88),'teal':mat('Paint | deep lagoon',(.035,.25,.235),.35,.3),'glass':mat('Glass | optical obsidian',(.012,.07,.095),.68,.13),'mint':mat('Emission | glacier',(.18,.88,.76),.2,.24,2.8),'amber':mat('Emission | amber',(1,.25,.025),.1,.3,2),'soil':mat('Terrain | rose sandstone',(.38,.19,.13),0,.92),'rock':mat('Rock | weathered sandstone',(.49,.29,.19),0,.88),'grass':mat('Leaf | jade',(.05,.24,.16),0,.8),'tip':mat('Leaf | sage',(.22,.44,.26),0,.8),'crystal':mat('Crystal | glacial mineral',(.10,.62,.58),.38,.22),'flower':mat('Petal | apricot',(.97,.41,.14),0,.7)}

def finish(o,name,m,b=0):
 o.name=name; o.data.materials.append(P[m] if isinstance(m,str) else m)
 if b:
  mod=o.modifiers.new('Machined radius','BEVEL'); mod.width=b; mod.segments=4
  o.modifiers.new('Face weighted normals','WEIGHTED_NORMAL')
 for p in o.data.polygons: p.use_smooth=True
 return o

def box(n,p,s,m,b=.06):
 bpy.ops.mesh.primitive_cube_add(size=1,location=p); o=bpy.context.object; o.scale=s; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); return finish(o,n,m,b)
def cyl(n,p,r,d,m,rot=(0,0,0),v=64):
 bpy.ops.mesh.primitive_cylinder_add(vertices=v,radius=r,depth=d,location=p,rotation=rot); return finish(bpy.context.object,n,m,min(.028,d*.18))
def uv(n,p,s,m):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=16 if n in ['Thick petal','Flower pollen'] else 48,ring_count=8 if n in ['Thick petal','Flower pollen'] else 24,location=p); o=bpy.context.object; o.scale=s; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); return finish(o,n,m)
def tor(n,p,r,t,m,rot=(0,0,0)):
 bpy.ops.mesh.primitive_torus_add(major_segments=64,minor_segments=12,location=p,major_radius=r,minor_radius=t,rotation=rot); return finish(bpy.context.object,n,m)
def rod(n,a,b,r,m):
 a,b=Vector(a),Vector(b); o=cyl(n,(a+b)*.5,r,(b-a).length,m); o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler(); return o

def cable(n,pts,r,m):
 c=bpy.data.curves.new(n,'CURVE'); c.dimensions='3D'; c.resolution_u=16; c.bevel_depth=r; c.bevel_resolution=4
 sp=c.splines.new('BEZIER'); sp.bezier_points.add(len(pts)-1)
 for b,p in zip(sp.bezier_points,pts): b.co=p; b.handle_left_type='AUTO'; b.handle_right_type='AUTO'
 o=bpy.data.objects.new(n,c); bpy.context.collection.objects.link(o); o.data.materials.append(P[m]); bpy.context.view_layer.objects.active=o; o.select_set(True); bpy.ops.object.convert(target='MESH'); o.select_set(False); return o

def text(body,p,size,m,rot=(math.pi/2,0,0)):
 bpy.ops.object.text_add(location=p,rotation=rot); o=bpy.context.object; o.data.body=body; o.data.size=size; o.data.align_x='CENTER'; o.data.extrude=.0008; o.data.materials.append(P[m]); bpy.ops.object.convert(target='MESH'); o.name='Marking '+body; return o

def export(name):
 if '--environment-only' in __import__('sys').argv and name not in ['oasis_blossom','oasis_tree','mesa_sculpt_0','mesa_sculpt_1','mesa_sculpt_2']:
  old_manifest=previous_manifest
  if name in old_manifest['assets']: manifest[name]=old_manifest['assets'][name]
  bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
  return
 bpy.ops.wm.save_as_mainfile(filepath=str(SRC/(name+'.blend')))
 # Source keeps all components. Export combines static surfaces by material.
 groups={}
 for o in list(bpy.context.scene.objects):
  if o.type!='MESH': continue
  bpy.context.view_layer.objects.active=o
  for mod in list(o.modifiers): bpy.ops.object.modifier_apply(modifier=mod.name)
  groups.setdefault(o.data.materials[0].name,[]).append(o)
 for group in groups.values():
  bpy.ops.object.select_all(action='DESELECT')
  for o in group: o.select_set(True)
  bpy.context.view_layer.objects.active=group[0]; bpy.ops.object.join()
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',export_yup=True)
 tris=sum(len(o.data.loop_triangles) for o in bpy.context.scene.objects if o.type=='MESH')
 manifest[name]={'source':str((SRC/(name+'.blend')).relative_to(R)),'output':str((OUT/(name+'.glb')).relative_to(R)),'triangles':tris,'materials':len(groups)}
 bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
manifest={}
# HERO: autonomous prospecting rover, front is -Y.
box('Belly casting',(0,0,.92),(2.3,2.9,.47),'dark',.18)
box('Split armored hull',(0,-.02,1.46),(2.34,2.6,.96),'ochre',.30)
box('Porcelain upper armor',(0,.02,1.96),(2.22,2.43,.20),'white',.095)
box('Roof inset',(0,.24,2.077),(1.80,1.48,.045),'teal',.08)
for x in [-.91,.91]:
 box('Longitudinal panel joint',(x,0,1.984),(.025,1.65,.06),'dark',.01)
 box('Side protective rail',(x*1.35,0,1.14),(.19,2.55,.17),'steel',.065)
 for y in [-.97,.06,1.03]:
  rod('Suspension swing arm',(x*.82,y+.22,.94),(x*1.56,y,.62),.115,'steel')
  rod('Hydraulic piston',(x*1.07,y+.40,1.19),(x*1.46,y,.64),.065,'dark')
  rod('Piston polished rod',(x*1.22,y+.24,.95),(x*1.48,y,.61),.034,'steel')
  wx=x*1.58
  tor('Continuous rounded tire',(wx,y,.63),.455,.175,'rubber',(0,math.pi/2,0))
  cyl('Wheel barrel',(wx,y,.63),.40,.33,'dark',(0,math.pi/2,0))
  sign=1 if x>0 else -1
  cyl('Wheel enamel rim',(wx+sign*.19,y,.63),.335,.075,'ochre',(0,math.pi/2,0))
  cyl('Hub recess',(wx+sign*.24,y,.63),.24,.024,'dark',(0,math.pi/2,0))
  cyl('Hub cap',(wx+sign*.27,y,.63),.115,.055,'steel',(0,math.pi/2,0))
  for k in range(6):
   a=k*math.tau/6
   cyl('Recessed wheel fastener',(wx+sign*.263,y+math.sin(a)*.176,.63+math.cos(a)*.176),.022,.02,'white',(0,math.pi/2,0),6)
  for k in range(32):
   a=k*math.tau/32
   o=box('Tire traction block',(wx,y+math.sin(a)*.598,.63+math.cos(a)*.598),(.31,.079,.049),'rubber',.017); o.rotation_euler.x=-a
 # wheel fender above each bank
 box('Floating enamel fender',(x*1.48,0,1.25),(.63,2.80,.16),'ochre',.072)
 for y in [-.7,-.45,-.20,.05,.30]: box('Fender tread insert',(x*1.48,y,1.339),(.40,.07,.018),'dark',.015)
 for y in [-.88,.86]:
  cyl('Armor hex bolt',(x*1.279,y,1.57),.045,.025,'steel',(0,math.pi/2,0),6)
 # cooling grille on side
 for i in range(9): box('Recessed cooling louvre',(x*1.286,.40+i*.065,1.63),(.034,.027,.27),'dark',.008)
 text('07',(x*1.293,-.53,1.47),.35,'white',(math.pi/2,0,math.pi/2 if x>0 else -math.pi/2))
# Friendly articulated sensor head.
cyl('Neck gimbal',(0,-.53,2.19),.35,.30,'dark')
box('Head lower seal',(0,-.73,2.44),(1.65,1.02,.63),'dark',.24)
box('Rounded sensor helmet',(0,-.67,2.59),(1.82,1.07,.70),'white',.29)
box('Deep curved visor',(0,-1.206,2.57),(1.52,.135,.445),'glass',.17)
for x in [-.40,.40]:
 tor('Lens bezel',(x,-1.286,2.59),.125,.023,'steel',(math.pi/2,0,0))
 cyl('Optical lens',(x,-1.303,2.59),.098,.023,'mint',(math.pi/2,0,0))
 cyl('Lens iris',(x,-1.319,2.59),.044,.008,'glass',(math.pi/2,0,0))
 box('Lens soft glint',(x-.022,-1.326,2.627),(.031,.008,.028),'white',.01)
for x in [-.96,.96]:
 cyl('Head hinge',(x,-.69,2.55),.18,.12,'ochre',(0,math.pi/2,0))
 cyl('Head hinge inset',(x*1.077,-.69,2.55),.085,.025,'dark',(0,math.pi/2,0))
box('Brow orange accent',(0,-1.071,2.882),(.91,.20,.035),'ochre',.015)
text('LOCUS',(0,-1.342,1.56),.24,'white')
text('AUTONOMOUS / FIELD SYSTEMS',(0,-1.345,1.37),.065,'dark')
box('Front equipment seal',(0,-1.355,1.12),(1.35,.12,.20),'dark',.06)
for x in [-.95,.95]:
 box('Headlight casing',(x,-1.311,1.48),(.29,.18,.25),'dark',.08)
 box('Warm running light',(x,-1.405,1.48),(.19,.022,.08),'amber',.035)
# Back pressure vessels and handle.
for x in [-.7,.7]:
 cyl('Rear pressure vessel',(x,1.11,2.09),.23,.93,'teal')
 uv('Tank top',(x,1.11,2.55),(.23,.23,.16),'teal')
 for z in [1.81,2.31]: tor('Tank strap',(x,1.11,z),.23,.024,'steel')
 cyl('Valve',(x,1.11,2.71),.075,.17,'ochre')
cable('Rear grab rail',[(-1,1.40,1.74),(-1,1.40,2.14),(0,1.40,2.17),(1,1.40,2.14),(1,1.40,1.74)],.041,'steel')
# offset sampling arm in a folded, weight bearing pose
for a,b in [((1.0,-.50,1.90),(1.85,-.83,2.36)),((1.85,-.83,2.36),(2.42,-1.32,1.30))]:
 rod('Manipulator backbone',a,b,.14,'ochre')
 a=Vector(a); b=Vector(b); rod('Manipulator dark inset',a+Vector((0,-.13,0)),b+Vector((0,-.13,0)),.056,'dark')
for p in [(1.02,-.5,1.9),(1.85,-.83,2.36),(2.42,-1.32,1.3)]:
 cyl('Arm articulated joint',p,.205,.28,'dark',(math.pi/2,0,0))
 cyl('Arm joint end cap',(p[0],p[1]-.155,p[2]),.135,.04,'steel',(math.pi/2,0,0))
cable('Flexible hydraulic feed',[(.94,-.36,2.05),(1.40,-.44,2.54),(1.95,-.7,2.62),(2.30,-1.15,1.48)],.046,'rubber')
cyl('Sample drill collar',(2.42,-1.32,1.07),.20,.37,'teal')
for z in [.91,.99,1.07]: tor('Drill cooling fin',(2.42,-1.32,z),.205,.025,'steel')
rod('Sampling tip',(2.42,-1.32,.88),(2.42,-1.32,.44),.083,'steel')
# antennas and graphic labels
rod('Antenna',( .79,.55,2.09),(.85,.58,3.21),.024,'steel'); uv('Beacon',(.85,.58,3.22),(.068,.068,.09),'amber')
text('M / 07',(0,.37,2.104),.28,'white',(0,0,0))
for i in range(4): box('Battery indicator',(-.47+i*.13,-.13,2.105),(.083,.23,.02),'mint',.015)
for x in [-.88,.88]:
 for y in [-.85,.85]: cyl('Top torx bolt',(x,y,2.083),.029,.018,'dark',v=6)
export('locus_m07')
# TERRAFORMER: elegant industrial assembly, much taller than hero.
cyl('Foundation',(0,0,.16),2.08,.32,'dark')
cyl('Porcelain plinth',(0,0,.40),1.84,.26,'white')
cyl('Core bottom',(0,0,.85),1.36,.68,'teal')
cyl('Core vessel',(0,0,2.68),.92,3.4,'glass')
cyl('Luminous biological core',(0,0,2.68),.64,3.3,'mint')
for z in [1.12,1.37,3.94,4.24]:
 tor('Core machined collar',(0,0,z),1.04,.115,'white')
for k in range(6):
 a=k*math.tau/6; x,y=math.cos(a)*1.14,math.sin(a)*1.14
 box('Vertical exoskeleton',(x,y,2.68),(.20,.20,3.2),'white',.085)
 for z in [1.55,3.7]: cyl('Structural pin',(x,y,z),.15,.2,'ochre')
for z in [1.7,2.1,2.5,2.9,3.3,3.7]: tor('Core magnetic winding',(0,0,z),.95,.026,'steel')
cyl('Crown housing',(0,0,4.49),1.40,.52,'white')
cyl('Top shadow gasket',(0,0,4.79),1.36,.11,'dark')
cyl('Crown teal lid',(0,0,4.91),1.38,.13,'teal')
for k in range(36):
 a=k*math.tau/36; o=box('Crown radial vent',(math.cos(a)*1.40,math.sin(a)*1.40,4.47),(.048,.06,.26),'dark',.013); o.rotation_euler.z=a
for k in range(3):
 a=k*math.tau/3
 x,y=math.cos(a)*1.65,math.sin(a)*1.65
 cyl('Satellite pump',(x,y,1.25),.30,1.38,'ochre')
 uv('Pump shoulder',(x,y,1.93),(.3,.3,.2),'white')
 cable('Recirculation pipe',[(x,y,1.95),(x,y,2.28),(x*.65,y*.65,2.37)],.08,'steel')
box('Readout housing',(0,-1.35,.93),(1.00,.30,.55),'dark',.12)
text('A T M O S',(0,-1.512,1.0),.15,'white')
text('BIO / 01',(0,-1.512,.78),.09,'mint')
for x in [-1.35,1.35]:
 box('Foot dock',(x,-1.0,.2),(.60,1.30,.28),'steel',.10)
 for i in range(4): box('Safety yellow marker',(x,-1.40+i*.18,.35),(.38,.07,.015),'ochre',.01)
export('atmos_spire')
# Rounded, eroded sandstone instead of flat-shaded polyhedra.
for j in range(3):
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=4,radius=1)
 o=bpy.context.object
 for v in o.data.vertices:
  p=v.co; f=1+.10*math.sin(p.z*10+p.x*3)+.075*math.sin(p.y*9+p.z*3)+.06*math.sin(p.x*12+p.y*3)
  p*=f; p.x*=1.2; p.y*=.9; p.z*=1.3
 finish(o,'Eroded sandstone '+str(j),'rock')
 export('sandstone_'+str(j))
# Curved leaf rosette: actual tapered organic silhouette.
for k in range(11):
 a=k*2.39996; length=random.uniform(.45,1.05); verts=[]; faces=[]
 for s in range(13):
  t=s/12; rad=length*t*.80; z=length*(math.sin(t*2.5)*.65+.03)
  wid=math.sin(t*math.pi)**.8*length*.105
  for side in [-1,0,1]: verts.append((math.cos(a)*rad-math.sin(a)*wid*side,math.sin(a)*rad+math.cos(a)*wid*side,z+(1-abs(side))*.025))
 for s in range(12):
  for q in range(2): n=s*3+q; faces.append((n,n+1,n+4,n+3))
 mesh=bpy.data.meshes.new('Leaf'); mesh.from_pydata(verts,[],faces); mesh.update(); o=bpy.data.objects.new('Sculpted succulent leaf',mesh); bpy.context.collection.objects.link(o); finish(o,o.name,'grass' if k%3 else 'tip'); mod=o.modifiers.new('Leaf thickness','SOLIDIFY'); mod.thickness=.014
export('jade_rosette')

print('SHOWCASE_ASSETS',json.dumps(manifest))
# Dense ground cover with a curved silhouette; instances are batched by Godot.
for k in range(18):
 a=random.uniform(0,math.tau); length=random.uniform(.18,.50); ox=random.uniform(-.17,.17); oy=random.uniform(-.17,.17)
 verts=[]; faces=[]
 for s in range(7):
  t=s/6; bend=t*t*length*.6; width=(1-t)*.022
  for side in [-1,1]: verts.append((ox+math.cos(a)*bend-math.sin(a)*width*side,oy+math.sin(a)*bend+math.cos(a)*width*side,length*t))
 for s in range(6): n=s*2; faces.append((n,n+1,n+3,n+2))
 mesh=bpy.data.meshes.new('Blade');mesh.from_pydata(verts,[],faces);mesh.update();o=bpy.data.objects.new('Grass blade',mesh);bpy.context.collection.objects.link(o);finish(o,o.name,'grass' if k%3 else 'tip')
export('oasis_grass')
# Flowering native shrub: arching stems and clustered apricot petals.
for k in range(7):
 a=k*2.4; h=random.uniform(.35,.75); tip=(math.cos(a)*.25,math.sin(a)*.25,h)
 cable('Curved flower stem',[(0,0,0),(tip[0]*.7,tip[1]*.7,h*.55),tip],.013,'grass')
 for j in range(5):
  angle=j*math.tau/5
  uv('Thick petal',(tip[0]+math.cos(angle)*.071,tip[1]+math.sin(angle)*.071,h),(.075,.048,.036),'flower')
 uv('Flower pollen',tip,(.039,.039,.044),'ochre')
export('oasis_blossom')
# Sculpted native tree, umbrella foliage groups read as botanical masses.
cable('Twisting trunk',[(0,0,0),(.14,.04,.8),(-.04,.10,1.7),(.12,0,2.6)],.16,'soil')
for k in range(7):
 a=k*2.4; end=(math.cos(a)*1.22,math.sin(a)*1.22,2.5+random.uniform(-.3,.4))
 cable('Branch',[(.03,0,1.40),(.4*end[0],.4*end[1],2.18),end],.064,'soil')
 for j in range(145):
  theta=random.uniform(0,math.tau); r=math.sqrt(random.random())*.88
  pos=Vector((end[0]+math.cos(theta)*r,end[1]+math.sin(theta)*r,end[2]+random.uniform(-.22,.24)))
  length=random.uniform(.19,.36); width=length*.38
  direction=Vector((math.cos(theta),math.sin(theta),random.uniform(-.2,.35))).normalized()
  right=Vector((-math.sin(theta),math.cos(theta),0))
  verts=[tuple(pos-direction*length*.5),tuple(pos-right*width),tuple(pos+Vector((0,0,.038))),tuple(pos+right*width),tuple(pos+direction*length*.65)]
  faces=[(0,1,2),(0,2,3),(1,4,2),(2,4,3)]
  mesh=bpy.data.meshes.new('Pointed foliage');mesh.from_pydata(verts,[],faces);mesh.update();leaf=bpy.data.objects.new('Individual canopy leaf',mesh);bpy.context.collection.objects.link(leaf);finish(leaf,leaf.name,'grass' if j%4 else 'tip')
export('oasis_tree')
# A continuous eroded mesa uses curved ridges and broad cap shelves.
for variant in range(3):
 verts=[];faces=[];rings=64;sectors=96
 for j in range(rings+1):
  t=j/rings
  cap=min(1.,max(.001,(1-t)/.055))**.35
  shelf=1.+.045*math.sin(t*14.+variant)+.012*math.sin(t*53.)
  taper=(1.15-t*.38)*cap
  for k in range(sectors):
   a=k*math.tau/sectors
   radial=(1+.10*math.sin(a*5+variant)+.055*math.sin(a*11+t*.8)+.028*math.sin(a*19-t*1.3))*shelf*taper
   verts.append((math.cos(a)*radial,math.sin(a)*radial*.78,t*2.3))
 for j in range(rings):
  for k in range(sectors):
   a=j*sectors+k;b=j*sectors+(k+1)%sectors;faces.append((a,b,b+sectors,a+sectors))
 mesh=bpy.data.meshes.new('Mesa sculpt');mesh.from_pydata(verts,[],faces);mesh.update();o=bpy.data.objects.new('Layered eroded mesa',mesh);bpy.context.collection.objects.link(o);finish(o,o.name,'rock')
 export('mesa_sculpt_'+str(variant))
(SRC/'manifest.json').write_text(json.dumps({'generator':'tools/build_quality_showcase.py','seed':9206,'assets':manifest},indent=2))
print('SHOWCASE_COMPLETE_ASSETS',len(manifest))
