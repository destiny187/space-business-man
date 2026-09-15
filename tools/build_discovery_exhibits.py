"""Author static exhibition replicas from existing Blender-authored field assets.
Blender --background --python tools/build_discovery_exhibits.py -- [template IDs]
Original discoveries stay untouched. Separate editable blend sources precede export.
"""
from pathlib import Path
import sys,json,math
import bpy
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import build_ink_industry as k
import ink_blender as ink
DATA=json.loads((ROOT/'우주-비즈니스/data/discovery_exhibits.json').read_text())['items']
MODELS=ROOT/'우주-비즈니스/assets/models';SOURCES=ROOT/'art/blender/exhibits';OUT=ROOT/'output/discovery-exhibits'
SOURCES.mkdir(parents=True,exist_ok=True);(MODELS/'exhibits').mkdir(parents=True,exist_ok=True);OUT.mkdir(parents=True,exist_ok=True)
selected=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
def mat(name,color):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True;m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(*color,1);m.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.85;return m

def replica(d):
 bpy.ops.import_scene.gltf(filepath=str(MODELS/(d['source_model']+'.glb')))
 bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get();original=list(bpy.context.scene.objects);meshes=[];points=[]
 for o in original:
  if o.type!='MESH':continue
  evaluated=o.evaluated_get(deps);mesh=bpy.data.meshes.new_from_object(evaluated);world=o.matrix_world.copy()
  for v in mesh.vertices:points.append(world@v.co)
  meshes.append((o.name,mesh,world))
 low=Vector(tuple(min(v[i] for v in points) for i in range(3)));high=Vector(tuple(max(v[i] for v in points) for i in range(3)))
 size=high-low;scale=min(2.05/max(size.x,size.y,.01),1.9/max(size.z,.01));center=Vector(((low.x+high.x)*.5,(low.y+high.y)*.5,low.z))
 transform=Matrix.Translation(Vector((0,0,.24)))@Matrix.Diagonal(Vector((scale,scale,scale,1)))@Matrix.Translation(-center)
 for o in original:bpy.data.objects.remove(o,do_unlink=True)
 for name,mesh,world in meshes:
  mesh.transform(transform@world);o=bpy.data.objects.new('Replica '+name,mesh);bpy.context.collection.objects.link(o)
 return len(meshes)

def native_trace(template):
 k.P['trace']=mat('Exhibit mineral impression',(.32,.39,.36));k.P['stone']=mat('Exhibit fossil stone',(.58,.52,.38))
 if template=='native_giant_passage':
  # Stylized cast records scale and passage; never copies or grants a living animal.
  for x,y,a in [(-.5,.25,-.15),(.5,-.25,.15)]:
   k.cyl('Footprint heel',(x,y,.31),.28,.1,'trace')
   for n in [-1,0,1]:k.cyl('Three toe impression',(x+n*.19,y+.34,.31),.12,.1,'trace')
 elif template=='native_cave_presence':
  for n in range(5):
   k.box('Layered resonance stone',(0,.32,.3+n*.13),(1.45-n*.12,.7,.12),'stone',.025)
  for i in range(9):k.cyl('Recorded vibration',(-.8+i*.2,-.45,.32),.055,.12+abs(math.sin(i*1.6))*.55,'teal')
 elif template=='native_rare_sighting':
  for i,color in enumerate([(.21,.61,.62),(.74,.34,.68),(.86,.64,.23),(.39,.52,.75),(.59,.72,.42)]):
   key='tone'+str(i);k.P[key]=mat('Recorded rare hue '+str(i),color)
   k.cyl('Color sample crystal',(-.65+i*.32,0,.52),.19,.5+math.sin(i)*.25,key)
 else:return False
 return True

records=[]
for key,d in DATA.items():
 template=d['template']
 if selected and template not in selected:continue
 k.reset()
 if template=='seismic_gem_chamber':
  k.P['crystal']=mat('Exhibit fracture crystal',(.18,.49,.57))
  for i in range(7):
   a=i*math.tau/7;x=.62*math.cos(a);y=.62*math.sin(a)
   k.cyl('Broken chamber rim',(x,y,.38),.27,.26,'steel')
  for i in range(5):
   x=-.38+i*.19;y=.12*math.sin(i*2);height=.6+.3*math.sin(i+1)
   bpy.ops.mesh.primitive_cone_add(vertices=6,radius1=.13,radius2=.03,depth=height,location=(x,y,.25+height*.5));k.finish(bpy.context.object,'Exposed crystal','crystal',0)
 elif not native_trace(template):replica(d)
 if template in ['spore_sails','molting_trail']:
  # Attach each fragment at its actual lowest vertex, not at guessed world positions.
  vertices=[o.matrix_world@v.co for o in bpy.context.scene.objects if o.type=='MESH' for v in o.data.vertices]
  xmin=min(v.x for v in vertices);xmax=max(v.x for v in vertices)
  for i in range(3):
   band=[v for v in vertices if xmin+(xmax-xmin)*i/3-.001<=v.x<=xmin+(xmax-xmin)*(i+1)/3+.001]
   point=min(band,key=lambda v:v.z)
   k.cyl('Exhibition support',(point.x,point.y,(point.z+.2)*.5),.014,max(.025,point.z-.2+.02),'dark')
 k.P['exhibit_stone']=mat('Exhibit natural stone',(.41,.45,.4))
 k.cyl('Low mineral exhibition base',(0,0,.1),1.18,.2,'exhibit_stone')
 k.box('Record plaque',(0,-1.01,.24),(.58,.24,.075),'cream',.025)
 for x in [-.17,0,.17]:k.box('Archive marker',(x,-1.06,.285),(.07,.06,.02),'teal',.008)
 # All models are static, non-living replicas, without source scene collision or scripts.
 bpy.ops.wm.save_as_mainfile(filepath=str(SOURCES/(template+'.blend')))
 ink.consolidate_static_surfaces()
 bpy.ops.export_scene.gltf(filepath=str(MODELS/(d['model']+'.glb')),export_format='GLB',export_apply=True,export_animations=False,export_cameras=False,export_lights=False)
 records.append({'id':key,'source_model':d['source_model'],'source':'art/blender/exhibits/'+template+'.blend','model':'우주-비즈니스/assets/models/'+d['model']+'.glb','generator':'tools/build_discovery_exhibits.py','static_replica':True})
 if template in ['singing_stones','hollow_geode','native_giant_passage','lost_technology_archive']:
  scene=bpy.context.scene;k.box('Review floor',(0,0,-.12),(200,200,.1),'cream',0)
  scene.world=bpy.data.worlds.new('Exhibit studio');scene.world.color=(.16,.16,.16)
  target=Vector((0,0,.95));bpy.ops.object.camera_add(location=(5,-7,5));cam=bpy.context.object;cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=3.5;scene.camera=cam
  for pos,power in [((3,-5,8),1500),((-4,1,6),1000)]:
   bpy.ops.object.light_add(type='AREA',location=pos);light=bpy.context.object;light.data.energy=power;light.data.size=5;light.rotation_euler=(target-light.location).to_track_quat('-Z','Y').to_euler()
  scene.render.engine='CYCLES';scene.cycles.samples=12;scene.render.resolution_x=640;scene.render.resolution_y=640;scene.render.resolution_percentage=100;scene.render.filepath=str(OUT/(template+'-blender.png'));bpy.ops.render.render(write_still=True)
 print('EXHIBIT_EXPORTED',template,flush=True)
manifest=SOURCES/'manifest.json'
if selected and manifest.exists():
 previous=json.loads(manifest.read_text());ids={r['id'] for r in records};records=[r for r in previous if r['id'] not in ids]+records
manifest.write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n')
print('EXHIBITS_FINISHED',len(records),flush=True)
