"""Original Space Y CARRIER cargo spine. Blender +Y / Godot -Z forward, meters."""
from pathlib import Path
import bpy,sys,math,json,hashlib
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
import ink_blender as ink
import corporate_marks as marks
SRC=ROOT/'art/blender/ships';OUT=ROOT/'우주-비즈니스/assets/models/ships';CAP=ROOT/'docs/production/media/corporate-space'
LOD=False

def finish(o,name,role,parent=None,bevel=.2):
 o.name=name;o.data.materials.append(ink.material(role));ink.manufactured_edges(o,bevel if not LOD else 0,3)
 if parent:o.parent=parent
 return o
def box(name,p,size,role='enamel_cream',parent=None):
 bpy.ops.mesh.primitive_cube_add(size=1,location=p);o=bpy.context.object;o.scale=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 return finish(o,name,role,parent,min(size)*.14)
def hull(name,sections,role='enamel_cream',parent=None):
 verts=[]
 for y,w,h,z in sections:
  for x,zz in [(-.75,-1),(.75,-1),(1,-.65),(1,.55),(.65,1),(-.65,1),(-1,.55),(-1,-.65)]:verts.append((x*w,y,z+zz*h))
 faces=[tuple(reversed(range(8))),tuple(range(len(verts)-8,len(verts)))]
 for j in range(len(sections)-1):
  for i in range(8):faces.append((j*8+i,j*8+(i+1)%8,(j+1)*8+(i+1)%8,(j+1)*8+i))
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update();o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);return finish(o,name,role,parent,.35)
def cylinder(name,p,r,depth,role='edge_steel',parent=None,axis='Z'):
 bpy.ops.mesh.primitive_cylinder_add(vertices=16 if LOD else 48,radius=r,depth=depth,location=p);o=bpy.context.object
 if axis=='Y':o.rotation_euler.x=math.pi/2
 return finish(o,name,role,parent,.12)
def empty(name,p):
 bpy.ops.object.empty_add(location=p);o=bpy.context.object;o.name=name;return o

def build():
 hull('Armored central service spine',[(-45,7,5,1),(30,7,5,1),(49,4,3,2)],'structural_dark')
 hull('Forward pressure cabin',[(25,10,6,3),(38,11,7,3),(53,5,4,1),(57,1,2,0)])
 hull('Recessed wraparound cockpit',[(40,9.2,2.5,6),(48,6,2.3,5),(51,4,1.2,4)],'structural_dark')
 box('Cabin upper armor',(0,35,11),(15,15,1.8))
 hull('Aft power module',[(-49,12,8,0),(-33,12,8,0),(-27,8,5,0)])
 for side in [-1,1]:
  box('Cargo lock rail',(side*8,-2,1),(3,61,5),'edge_steel')
  for n,y in enumerate([-19,8]):
   pod=empty('Anim_Pod_%s_%s'%(side,n),(side*19,y,0))
   hull('Removable pressurized cargo pod',[(-11,9,7,0),(-8,10,8,0),(8,10,8,0),(11,9,7,0)],'enamel_cream',pod)
   box('Blue cargo identity band',(0,0,8),(17,13,1.3),'enamel_teal',pod)
   for yy in [-8,8]:box('Load bearing collar',(0,yy,0),(21,2.3,17),'edge_steel',pod)
   box('Recessed loading door',(0,11.2,0),(14,.8,11),'structural_dark',pod)
   for xx in [-6,6]:box('Handling latches',(xx,11.9,0),(1.8,1.5,7),'safety_orange',pod)
   if not LOD:
    for yy in [-7,7]:box('Lift attachment',(0,yy,9),(5,2,2),'safety_orange',pod)
  for y in [-27,-10,0,17]:box('Exposed clamp',(side*11,y,2),(8,3,3),'safety_orange')
  engine=empty('Anim_Engine_'+str(side),(side*14,-40,0))
  cylinder('Engine pressure casing',(0,0,0),6,21,'enamel_cream',engine,'Y')
  cylinder('Engine dark throat',(0,-11,0),5,5,'structural_dark',engine,'Y')
  cylinder('Engine bell rim',(0,-14,0),6,1.5,'edge_steel',engine,'Y')
  cylinder('Luminous nozzle',(0,-15,0),4,1,'enamel_teal',engine,'Y')
  empty('Socket_Exhaust_'+str(side),(side*14,-55,0))
  for y in [-22,23]:
   box('Docking leg',(side*10,y,-8),(3,4,7),'edge_steel')
   box('Magnetic landing shoe',(side*10,y,-12),(7,9,2),'structural_dark')
 if not LOD:
  for y in [-34,-30,-26]:box('Power module cooling grille',(0,y,8.2),(16,1.5,1),'structural_dark')
  marks.mount('Cabin dorsal insignia','space_y',(0,33,12.1),(1,0,0),(0,1,0),12)
  for side in [-1,1]:marks.mount('Hull side '+str(side),'space_y',(side*12.4,-40,2),(0,side,0),(0,0,1),9)

def export(id):
 scene=bpy.context.scene;scene.unit_settings.system='METRIC';scene.render.engine='CYCLES';scene.cycles.samples=24
 scene.world=bpy.data.worlds.new('Freighter studio');scene.world.color=(.07,.085,.11)
 bpy.ops.object.camera_add(location=(110,160,110));cam=bpy.context.object;cam.rotation_euler=(-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=157;scene.camera=cam
 for p,power,size in [((-70,100,150),600000,100),((120,30,70),250000,90),((0,-120,90),500000,70)]:
  bpy.ops.object.light_add(type='AREA',location=p);o=bpy.context.object;o.data.energy=power;o.data.size=size;o.rotation_euler=(-o.location).to_track_quat('-Z','Y').to_euler()
 scene.render.resolution_x=1100;scene.render.resolution_y=820;scene.render.resolution_percentage=100;scene.render.filepath=str(CAP/(id+'-blender.png'))
 bpy.ops.wm.save_as_mainfile(filepath=str(SRC/(id+'.blend')))
 count=ink.consolidate_static_surfaces();geo=[o for o in scene.objects if o.type in ['MESH','EMPTY']]
 bpy.ops.object.select_all(action='DESELECT')
 for o in geo:o.select_set(True)
 path=OUT/(id+'.glb');bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_yup=True,export_apply=True,export_animations=False)
 if not LOD:bpy.ops.render.render(write_still=True)
 return {'id':id,'source':str((SRC/(id+'.blend')).relative_to(ROOT)),'model':'res://assets/models/ships/'+id+'.glb','meshes':count,'triangles':sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in geo if o.type=='MESH'),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'forward':'Blender +Y / Godot -Z','pivots':[o.name for o in geo if o.type=='EMPTY']}
if __name__=='__main__':
 records=[]
 for LOD in [False,True]:
  bpy.ops.wm.read_factory_settings(use_empty=True);build();records.append(export('space_y_freighter'+('_lod1' if LOD else '')))
 (SRC/'space_y_freighter.json').write_text(json.dumps(records,indent=2)+'\n')
