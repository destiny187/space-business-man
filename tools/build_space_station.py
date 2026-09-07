"""WAYFARER trade station and two Kestrel-compatible hulls; editable Blender originals."""
from pathlib import Path
import bpy, math, json
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'art/blender/ships'; OUT=ROOT/'우주-비즈니스/assets/models/ships'
CAP=ROOT/'test-results/space-station'; CAP.mkdir(parents=True,exist_ok=True)
def palette():
 result={}
 for name,color in {'cream':(.75,.79,.69),'teal':(.025,.25,.27),'dark':(.018,.03,.04),'orange':(.95,.32,.04),'light':(.16,.8,.9),'glass':(.035,.10,.15)}.items():
  m=bpy.data.materials.new('Station '+name);m.diffuse_color=(*color,1);m.use_nodes=True
  m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*color,1)
  m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.48
  result[name]=m
 return result
def finish(obj,name,key,bevel=0):
 obj.name=name;obj.data.materials.append(P[key])
 if bevel:
  mod=obj.modifiers.new('Rounded armor','BEVEL');mod.width=bevel;mod.segments=3
  obj.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
 for f in obj.data.polygons:f.use_smooth=True
 return obj
def box(name,p,s,key):
 bpy.ops.mesh.primitive_cube_add(size=1,location=p);o=bpy.context.object;o.scale=s;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return finish(o,name,key,min(s)*.12)
def cyl(name,p,r,d,key):
 bpy.ops.mesh.primitive_cylinder_add(vertices=64,radius=r,depth=d,location=p);return finish(bpy.context.object,name,key,min(r,d)*.07)
def torus(name,p,r,t,key):
 bpy.ops.mesh.primitive_torus_add(major_radius=r,minor_radius=t,major_segments=96,minor_segments=12,location=p);return finish(bpy.context.object,name,key)
def export(name,size):
 bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/(name+'.blend')))
 groups={}
 for o in list(bpy.context.scene.objects):
  if o.type!='MESH':continue
  bpy.context.view_layer.objects.active=o
  for mod in list(o.modifiers):
   try:bpy.ops.object.modifier_apply(modifier=mod.name)
   except RuntimeError:pass
  groups.setdefault(o.data.materials[0].name,[]).append(o)
 for rows in groups.values():
  bpy.ops.object.select_all(action='DESELECT')
  for o in rows:o.select_set(True)
  bpy.context.view_layer.objects.active=rows[0];bpy.ops.object.join()
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',export_yup=True)
 # Actual Blender render for source/export form review.
 scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=16
 scene.world.color=(.15,.15,.15)
 bpy.ops.object.camera_add(location=(size*.95,-size*1.4,size*.95));cam=bpy.context.object
 cam.rotation_euler=(Vector((0,0,0))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=size*2.4;scene.camera=cam
 for point,power in [((size,-size,size*2),size*size*300),((-size,0,size),size*size*100)]:
  bpy.ops.object.light_add(type='AREA',location=point);light=bpy.context.object;light.data.energy=power;light.data.shape='DISK';light.data.size=size
  light.rotation_euler=(-light.location).to_track_quat('-Z','Y').to_euler()
 scene.render.resolution_x=800;scene.render.resolution_y=650;scene.render.resolution_percentage=100
 scene.render.image_settings.file_format='PNG';scene.render.filepath=str(CAP/(name+'-blender.png'));bpy.ops.render.render(write_still=True)
for name in ['swift','mule']:
 bpy.ops.wm.open_mainfile(filepath=str(SOURCE/'kestrel.blend'));P=palette()
 if name=='swift':
  for side in [-1,1]:
   o=box('Swept exploration wing',(side*5,1,.1),(5,4,.24),'teal');o.rotation_euler.z=side*.45
   box('Orange wing tip',(side*7,0,.16),(.3,2,.3),'orange')
   box('Dorsal fin',(side*1.8,-3,2.2),(.18,3,1.8),'cream')
 else:
  for side in [-1,1]:
   for y in [-2.5,1]:
    box('Freight pressure pod',(side*5,y,.4),(2.4,3.1,2.2),'cream')
    box('Recessed cargo hatch',(side*6.24,y,.45),(.12,2.45,1.5),'teal')
    box('Cargo latch',(side*6.34,y,.45),(.09,.45,.8),'orange')
   box('Cargo spine reinforcement',(side*4.2,0,-.85),(.45,8,.45),'dark')
 export(name,9)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False);P=palette()
cyl('Central trade hub',(0,0,0),52,92,'dark')
cyl('Habitat drum',(0,0,10),57,48,'cream')
cyl('Observation deck',(0,0,40),48,15,'teal')
cyl('Panoramic windows',(0,0,48),43,9,'glass')
cyl('Communications mast',(0,0,80),6,55,'orange')
torus('Survey dish rim',(0,0,112),24,3,'cream')
torus('Habitat structural ring',(0,0,0),155,14,'dark')
torus('Habitat outer armor',(0,0,4),155,10,'cream')
torus('Guidance light ribbon',(0,0,13),155,1.8,'light')
for i in range(12):
 a=i*math.tau/12;x,y=math.cos(a),math.sin(a)
 o=box('Ring habitat compartment',(x*155,y*155,5),(23,35,23),'teal');o.rotation_euler.z=a
 o=box('Window band',(x*169,y*169,10),(2,23,7),'light');o.rotation_euler.z=a
 if i%3==0:
  o=box('Truss spoke',(x*101,y*101,-9),(105,12,14),'dark');o.rotation_euler.z=a
for side in [-1,1]:
 box('Service bridge',(side*178,0,-36),(154,24,18),'cream')
 box('Docking apron',(side*248,0,-30),(74,110,12),'teal')
 for y in [-42,42]:
  box('Dock light guide',(side*248,y,-22),(65,3,3),'light')
  box('Protective gantry',(side*277,y,-10),(8,8,40),'orange')
 for y in [-25,0,25]:box('Landing berth marking',(side*247,y,-23),(32,2,1),'orange')
 box('Solar boom',(0,side*214,-15),(12,130,12),'dark')
 for x in [-57,57]:
  box('Solar array frame',(x,side*220,-15),(92,85,5),'cream')
  box('Photovoltaic field',(x,side*220,-11),(85,78,3),'glass')
  for yy in [-27,-9,9,27]:box('Array segmentation',(x,side*220+yy,-9),(84,1,1),'teal')
export('wayfarer_station',320)
(SOURCE/'station-manifest.json').write_text(json.dumps({'generator':'tools/build_space_station.py','assets':['wayfarer_station','swift','mule'],'style':'INK v1','compatible_mounts':'kestrel','source_template':'kestrel.blend'},indent=2)+'\n')
