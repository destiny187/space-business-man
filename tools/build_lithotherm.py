"""Reproducible Blender source for the first lithotherm visual case (Z up)."""
from pathlib import Path
import bpy, math, json, random, hashlib
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
SRC=ROOT/'art/blender/creatures/lithotherm'
OUT=ROOT/'우주-비즈니스/assets/models/creatures/lithotherm'
SRC.mkdir(parents=True,exist_ok=True); OUT.mkdir(parents=True,exist_ok=True)
random.seed(9401)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
def mat(name,color,metal=0,rough=.65,emission=0):
 m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*color,1)
 p.inputs['Metallic'].default_value=metal; p.inputs['Roughness'].default_value=rough
 if emission: p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=emission
 return m
M={'skin':mat('Charcoal flexible mineral skin',(.07,.095,.11)),
'plate':mat('Weathered blue basalt',(.25,.33,.36),.1),
'light':mat('Basalt exposed fracture',(.38,.46,.47),.12),
'dark':mat('Obsidian sockets',(.019,.027,.031),.2,.3),
'heat':mat('Amber thermal fissure',(.95,.23,.025),.1,.5,.22),
'copper':mat('Oxidized mineral edge',(.23,.105,.045),.28),
'eye':mat('Amber sensory organ',(1,.56,.09),.15,.25,.3),
'lichen':mat('Teal symbiotic crust',(.05,.39,.34)),
'ivory':mat('Pale silicate claw',(.67,.68,.52),.1)}
def root(name,loc,parent=None):
 o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.location=loc;o.parent=parent;return o
body=root('Anim_Body',(0,0,0))
def finish(o,name,material,parent,bevel=0,smooth=True):
 o.name=name;o.data.materials.append(M[material]);o.parent=parent
 for p in o.data.polygons:p.use_smooth=smooth
 if bevel:
  b=o.modifiers.new('Broad worn edge','BEVEL');b.width=bevel;b.segments=3
  o.modifiers.new('Face normals','WEIGHTED_NORMAL')
 return o
def ell(name,loc,scale,material,parent=body,segments=24):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=12,radius=1,location=loc)
 o=bpy.context.object;o.scale=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 return finish(o,name,material,parent)
def bone(name,a,b,r,material,parent):
 mid=(Vector(a)+Vector(b))/2
 o=ell(name,mid,(r,r,(Vector(a)-Vector(b)).length/2+r*.5),material,parent)
 o.rotation_euler=(Vector(b)-Vector(a)).to_track_quat('Z','Y').to_euler();return o
def plate(name,loc,size,material,parent=body,angle=0):
 # A broad, irregular shield with bevelled fracture edges, not a low-poly sphere.
 outline=[(-.7,-.72),(.25,-1),(.86,-.46),(.92,.36),(.24,.91),(-.71,.65),(-.95,-.12)]
 verts=[]
 for z,s in [(0,.86),(.22,1),(.69,.69)]:
  for x,y in outline:verts.append((x*size[0]*s,y*size[1]*s,z*size[2]))
 faces=[tuple(reversed(range(7))),tuple(range(14,21))]
 for k in range(2):
  for i in range(7):faces.append((k*7+i,k*7+(i+1)%7,(k+1)*7+(i+1)%7,(k+1)*7+i))
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
 o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);o.location=loc;o.rotation_euler.z=angle
 return finish(o,name,material,parent,.055,False)
def prism(name,loc,r,height,parent=body):
 bpy.ops.mesh.primitive_cone_add(vertices=6,radius1=r,radius2=r*.26,depth=height,location=loc)
 return finish(bpy.context.object,name,'light',parent,.035,False)
ell('Low flexible torso',(0,.12,.94),(1.02,1.56,.63),'skin')
ell('Warm under-shell',(0,.13,1.20),(.99,1.43,.46),'copper')
# Interlocking large armor plates: center ridge plus flanking courses.
for row,y in enumerate([-.83,-.05,.76,1.32]):
 z=[1.36,1.51,1.40,1.12][row]
 plate('Dorsal shield %d'%row,(0,y,z),(.55,.59,.45),'plate' if row%2 else 'light',angle=.07*(-1)**row)
 for side in [-1,1]:
  o=plate('Flank shield %d %d'%(row,side),(side*.65,y+.06,z-.20),(.52,.52,.35),'plate',angle=side*.16)
  o.rotation_euler.y=side*.35
  # Short visible thermal seams under shield edges.
  bone('Subdermal heat seam',(side*.78,y-.22,z-.19),(side*.90,y+.20,z-.29),.038,'heat',body)
for y,h in [(-.04,.48),(.64,.56),(1.17,.37)]:
 p=prism('Dorsal silicate vent',(0,y,1.76 if y<1 else 1.46),.14,h)
 p.rotation_euler.x=.3
# Six separate limbs, local pivots retain animation contracts through export.
for row,y in enumerate([-.92,.03,.91]):
 for side in [-1,1]:
  leg=root('Anim_Leg_%d_%s'%(row,'L' if side<0 else 'R'),(side*.75,y,.87),body)
  bone('Flexible shoulder',(0,0,0),(side*.41,.03,-.20),.22,'skin',leg)
  plate('Shoulder armor',(side*.20,-.02,-.05),(.31,.38,.32),'plate',leg,side*.2)
  bone('Load bearing foreleg',(side*.39,.03,-.20),(side*.53,-.12,-.61),.19,'skin',leg)
  plate('Foreleg scute',(side*.48,-.08,-.43),(.23,.28,.32),'light',leg)
  ell('Broad grounded foot',(side*.57,-.21,-.72),(.27,.34,.14),'dark',leg)
  for toe in range(3):
   o=ell('Silicate digging claw',(side*.57+(toe-1)*.145,-.45,-.74),(.07,.19,.07),'ivory',leg,16)
# Curious low head and a protected jaw; non-human paired sensory organs.
head=root('Anim_Head',(0,-1.24,1.02),body)
ell('Head mineral skin',(0,-.32,0),(.62,.65,.40),'skin',head)
plate('Broad head crown',(0,-.23,.20),(.65,.65,.31),'light',head)
plate('Nasal shield',(0,-.74,-.01),(.37,.30,.20),'plate',head)
for side in [-1,1]:
 ell('Recessed eye socket',(side*.46,-.67,.04),(.18,.15,.15),'dark',head)
 ell('Amber sensory lens',(side*.48,-.782,.053),(.105,.055,.08),'eye',head)
 ell('Vertical lens pupil',(side*.48,-.826,.058),(.027,.016,.055),'dark',head,16)
 bone('Protective orbital brow',(side*.27,-.66,.18),(side*.60,-.58,.18),.09,'plate',head)
 for j in range(2):
  ell('Thermal cheek slit',(side*.57,-.33+j*.19,-.07),(.036,.056,.10),'heat',head,16)
jaw=root('Anim_Jaw',(0,-.44,-.21),head)
ell('Crusher lower jaw',(0,-.14,-.055),(.43,.40,.13),'plate',jaw)
for side in [-1,1]:
 ell('Blunt mineral mandible',(side*.28,-.41,.06),(.11,.20,.12),'ivory',jaw,16)
# Rear tapered tail with armored sections.
tail=root('Anim_Tail',(0,1.31,.77),body)
bone('Tapered tail',(0,0,0),(0,.74,-.24),.23,'skin',tail)
for i in range(3):plate('Tail scute',(0,i*.25,.02-i*.10),(.28-i*.055,.32,.25),'plate',tail)
# Sparse teal crust gives age/identity without painting every surface with noise.
for x,y,z,s in [(-.24,.64,1.77,.16),(-.44,.81,1.64,.11),(.30,-.10,1.82,.12),(.71,.64,1.55,.13),(-.78,-.82,1.34,.11)]:
 plate('Symbiotic teal crust',(x,y,z),(s,s*.8,.035),'lichen',angle=random.uniform(-1,1))
bpy.context.view_layer.update()
# Source kept editable with named articulated parts and unapplied worn-edge modifiers.
bpy.ops.wm.save_as_mainfile(filepath=str(SRC/'lithotherm.blend'))
for o in list(bpy.context.scene.objects):
 if o.type!='MESH':continue
 bpy.context.view_layer.objects.active=o
 for mod in list(o.modifiers):bpy.ops.object.modifier_apply(modifier=mod.name)
# Join only per articulated parent + material, preserving all named motion pivots.
groups={}
for o in list(bpy.context.scene.objects):
 if o.type=='MESH':groups.setdefault((o.parent.name,o.data.materials[0].name),[]).append(o)
for group in groups.values():
 bpy.ops.object.select_all(action='DESELECT')
 for o in group:o.select_set(True)
 bpy.context.view_layer.objects.active=group[0]
 if len(group)>1:bpy.ops.object.join()
def stats():
 count=0
 for o in bpy.context.scene.objects:
  if o.type=='MESH':o.data.calc_loop_triangles();count+=len(o.data.loop_triangles)
 return {'triangles':count,'mesh_nodes':sum(o.type=='MESH' for o in bpy.context.scene.objects)}
records={}
for lod in ['near','far']:
 if lod=='far':
  for o in list(bpy.context.scene.objects):
   if o.type!='MESH' or len(o.data.polygons)<90:continue
   bpy.context.view_layer.objects.active=o;d=o.modifiers.new('Distant silhouette reduction','DECIMATE');d.ratio=.30;bpy.ops.object.modifier_apply(modifier=d.name)
 path=OUT/('lithotherm_'+lod+'.glb')
 bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',export_yup=True,export_animations=False)
 records[lod]={**stats(),'path':str(path.relative_to(ROOT)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
manifest={'case_id':'lithotherm','version':1,'status':'visual-prototype','generator':'tools/build_lithotherm.py','source':str((SRC/'lithotherm.blend').relative_to(ROOT)),'source_axes':'Z up, head -Y; glTF Y up, head +Z','motion':'Godot procedural named pivots; no baked clips','lods':records,'materials':list(M),'pivots':[o.name for o in bpy.context.scene.objects if o.type=='EMPTY']}
(SRC/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print('LITHOTHERM_MODELS_COMPLETE',json.dumps(records))
