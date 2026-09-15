"""Four nature-inspired functional discoveries. Blender sources precede GLB export."""
from pathlib import Path
import bpy,sys,math,json
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
import build_ink_industry as k
import ink_blender as ink
OUT=ROOT/'output/discovery-utilities';OUT.mkdir(parents=True,exist_ok=True)
def natural():
 for role,color in [('shell',(.55,.40,.23,1)),('stone',(.25,.31,.29,1)),('lip',(.42,.47,.36,1))]:
  mat=bpy.data.materials.new(role);mat.diffuse_color=color;mat.use_nodes=True;mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=color;k.P[role]=mat

def rock(name,loc,scale,role='stone'):
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1,location=loc);o=bpy.context.object;o.scale=scale;k.finish(o,name,role,0);return o

def shell():
 # Continuous vaulted shell with sculpted ribs; front and rear remain walkable.
 for i in range(16):
  a=i*math.pi/16;b=(i+1)*math.pi/16
  aa=Vector((2.7*math.cos(a),0,.25+2.8*math.sin(a)));bb=Vector((2.7*math.cos(b),0,.25+2.8*math.sin(b)))
  o=k.box('Shell vault plate',(aa+bb)*.5,((bb-aa).length+.045,4.,.18),'shell',.065);o.rotation_euler.y=-math.atan2(bb.z-aa.z,bb.x-aa.x)
 for y in [-2,-1.35,-.65,0,.65,1.35,2]:
  points=[(2.78*math.cos(a),y,.25+2.87*math.sin(a)) for a in [i*math.pi/24 for i in range(25)]]
  k.pipe('Shell growth rib',points,.075,'lip')
 for x in [-2.65,2.65]:
  k.box('Anchored shell foot',(x,0,.13),(.48,4.25,.26),'stone',.10)
 k.box('Small weather plaque',(2.4,-2.1,.85),(.3,.09,.25),'teal',.04)

def tank():
 rock('Tidepool mineral basin',(0,0,.42),(1.4,1.15,.48))
 k.ring('Eroded basin rim',(0,0,.85),1.02,.16,'lip')
 k.cyl('Culturing water',(0,0,.82),.98,.065,'water')
 pivot=k.pivot('Anim_Glow_Culture',(0,0,.85))
 for i in range(11):
  a=i*2.4;r=.25+.06*i;x=r*math.cos(a);y=r*math.sin(a)
  o=rock('Cultured microbial colony',(x,y,.91),(.16,.12,.075),'status');m=o.matrix_world.copy();o.parent=pivot;o.matrix_world=m
 k.box('Removable specimen chamber',(1.04,-.5,.91),(.55,.5,.8),'teal',.12)
 k.cyl('Specimen seal',(1.04,-.5,1.34),.19,.10,'cream')
 k.box('Thermal controller',(1.04,-.79,1.),(.32,.07,.24),'status',.025)
 k.pipe('Culture circulation',[(.98,-.5,.6),(.75,-.6,.48),(.48,-.73,.84)],.045,'steel')

def alarm():
 rock('Water-worn recorder foundation',(0,0,.22),(1.,.9,.27))
 k.box('Recovered recorder casing',(0,0,.79),(.9,.66,1.1),'teal',.13)
 for x in [-.48,.48]:k.box('Sediment shell edge',(x,.03,.71),(.20,.82,1.12),'stone',.075)
 k.box('Status window',(0,-.36,.96),(.54,.045,.3),'dark',.02)
 for x in [-.18,0,.18]:k.box('Level display',(x,-.39,.96),(.07,.025,.2),'status',.01)
 k.rod('Water level probe',(.72,0,.24),(.72,0,1.86),.06,'steel')
 for z in [.4,.65,.9,1.15,1.4,1.65]:k.box('Probe graduations',(.72,-.07,z),(.2,.04,.04),'cream',.01)
 k.ring('Sensor float',(.72,0,.38),.2,.08,'orange')
 k.cyl('Beacon seat',(0,0,1.44),.30,.16,'dark')
 p=k.pivot('Anim_Glow_Beacon',(0,0,1.66));k.cyl('Amber beacon',(0,0,1.66),.23,.32,'orange',parent=p)
 k.cyl('Beacon cap',(0,0,1.87),.3,.08,'cream')
 k.pipe('Probe cable',[(.6,.12,.45),(.3,.4,.42),(0,.4,.8)],.035,'rubber')

def garden():
 rock('Resonance stone bed',(0,0,.15),(1.9,1.65,.22))
 for n,(x,y,r,h) in enumerate([(-.85,.3,.43,2.5),(.35,.7,.5,3.),(.73,-.55,.39,1.9)]):
  # Hollow fluted stone tubes, uneven circumference suggests mineral growth.
  vertices=[];faces=[];count=32
  for rad,z in [(r,0),(r*1.1,h*.45),(r*.95,h),(r*.62,h+.015),(r*.60,h-.52)]:
   for i in range(count):
    a=i*math.tau/count;rr=rad*(1+.07*math.sin(a*5+n));vertices.append((x+rr*math.cos(a),y+rr*math.sin(a),.28+z))
  for row in range(4):
   for i in range(count):j=(i+1)%count;faces.append((row*count+i,row*count+j,(row+1)*count+j,(row+1)*count+i))
  mesh=bpy.data.meshes.new('Hollow singing stone');mesh.from_pydata(vertices,[],faces);mesh.materials.append(k.P['stone']);o=bpy.data.objects.new('Wind-worn stone tube',mesh);bpy.context.collection.objects.link(o)
  k.ring('Mineral mouth',(x,y,h+.28),r*.8,r*.15,'lip')
  p=k.pivot('Anim_Glow_Resonance'+str(n),(x,y,h*.52));k.ring('Resonance band',(x,y,.28+h*.52),r*1.08,.035,'status',parent=p)
 k.box('Acoustic tuning clamp',(-.4,-1.2,.46),(.75,.42,.34),'teal',.08)
 for x in [-.6,-.4,-.2]:k.cyl('Tuning knob',(x,-1.2,.68),.065,.1,'cream')

records=[];bounds={}
selected=sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
for key,build in [('shell_refuge',shell),('luminous_vivarium',tank),('flood_sentinel',alarm),('resonance_garden',garden)]:
 if selected and key not in selected:continue
 k.reset();natural();build();scene=bpy.context.scene;scene.unit_settings.system='METRIC';bpy.context.view_layer.update()
 coords=[o.matrix_world@Vector(c) for o in scene.objects if o.type=='MESH' for c in o.bound_box]
 lo=[min(p[i] for p in coords) for i in range(3)];hi=[max(p[i] for p in coords) for i in range(3)]
 bounds[key]={'min':[lo[0],lo[2],-hi[1]],'max':[hi[0],hi[2],-lo[1]]}
 source=ROOT/'art/blender/buildings'/f'{key}.blend';model=ROOT/'우주-비즈니스/assets/models'/f'{key}.glb'
 bpy.ops.wm.save_as_mainfile(filepath=str(source));ink.consolidate_static_surfaces();bpy.ops.export_scene.gltf(filepath=str(model),export_format='GLB',export_apply=True,export_cameras=False,export_lights=False)
 records.append({'id':key,'source':str(source.relative_to(ROOT)),'model':str(model.relative_to(ROOT)),'generator':'tools/build_discovery_utilities.py'})
 k.box('Review ground',(0,0,-.1),(100,100,.1),'cream',0)
 scene.world=bpy.data.worlds.new('Discovery utility studio');scene.world.color=(.16,.16,.16)
 center=Vector((0,0,1.35));bpy.ops.object.camera_add(location=(7,-11,6));cam=bpy.context.object;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=7.4 if key=='shell_refuge' else 5.0;scene.camera=cam
 for loc,power in [((2,-5,9),1800),((-5,2,7),1300)]:
  bpy.ops.object.light_add(type='AREA',location=loc);light=bpy.context.object;light.data.energy=power;light.data.size=6;light.rotation_euler=(center-light.location).to_track_quat('-Z','Y').to_euler()
 scene.render.engine='CYCLES';scene.cycles.samples=12;scene.render.resolution_x=800;scene.render.resolution_y=700;scene.render.resolution_percentage=100;scene.render.filepath=str(OUT/f'{key}-blender.png');bpy.ops.render.render(write_still=True)
manifest=ROOT/'art/blender/buildings/discovery_utilities.json'
if selected and manifest.exists():records=[r for r in json.loads(manifest.read_text()) if r['id'] not in selected]+records
manifest.write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n')
p=ROOT/'우주-비즈니스/data/discovery_utilities.json';cfg=json.loads(p.read_text());cfg.setdefault('water_bounds',{}).update(bounds);p.write_text(json.dumps(cfg,ensure_ascii=False,indent=2)+'\n')
