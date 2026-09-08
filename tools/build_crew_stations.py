"""A03 medical scanner and specimen bench. Blender -Y / Godot +Z work face.
Editable parts and named animation/socket transforms are saved before consolidation.
"""
from pathlib import Path
import bpy, math, sys, json
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import ink_blender as ink
OUT=ROOT/'art/blender/crew'; GAME=ROOT/'우주-비즈니스/assets/models/crew'
REVIEW=ROOT/'docs/production/media/crew-stations'; REVIEW.mkdir(parents=True,exist_ok=True)
OUT.mkdir(parents=True,exist_ok=True);GAME.mkdir(parents=True,exist_ok=True)
def start():
 bpy.ops.wm.read_factory_settings(use_empty=True)
 global M
 M={k:ink.material(v) for k,v in {'cream':'enamel_cream','teal':'enamel_teal','orange':'safety_orange','dark':'structural_dark','steel':'edge_steel','rubber':'rubber'}.items()}
 m=bpy.data.materials.new('Station diagnostic cyan');m.diffuse_color=(.10,.65,.52,1);m.use_nodes=True
 p=m.node_tree.nodes['Principled BSDF'];p.inputs['Base Color'].default_value=m.diffuse_color;p.inputs['Emission Color'].default_value=m.diffuse_color;p.inputs['Emission Strength'].default_value=.6
 M['light']=m

def finish(o,name,role,parent=None,bevel=.025):
 o.name=name;o.data.materials.append(M[role]);ink.manufactured_edges(o,bevel,4)
 if parent:o.parent=parent;o.matrix_parent_inverse=parent.matrix_world.inverted()
 return o

def box(name,p,s,role,parent=None,bevel=.035):
 bpy.ops.mesh.primitive_cube_add(size=1,location=p);o=bpy.context.object;o.scale=s;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 return finish(o,name,role,parent,bevel)
def cyl(name,p,r,h,role,parent=None,rot=(0,0,0)):
 bpy.ops.mesh.primitive_cylinder_add(vertices=40,radius=r,depth=h,location=p,rotation=rot)
 return finish(bpy.context.object,name,role,parent,min(.018,h*.15))
def pivot(name,p):
 o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.location=p;bpy.context.view_layer.update();return o

def tube(name,points,r,role,parent=None):
 curve=bpy.data.curves.new(name,'CURVE');curve.dimensions='3D';curve.bevel_depth=r;curve.bevel_resolution=4
 poly=curve.splines.new('POLY');poly.points.add(len(points)-1)
 for p,co in zip(poly.points,points):p.co=(*co,1)
 o=bpy.data.objects.new(name,curve);bpy.context.collection.objects.link(o);bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.convert(target='MESH');o.select_set(False)
 return finish(o,name,role,parent,0)
def foot(x,y):
 cyl('Isolation foot',(x,y,.075),.13,.15,'rubber');cyl('Foot collar',(x,y,.17),.105,.09,'steel')
def export(name):
 scene=bpy.context.scene;scene.unit_settings.system='METRIC'
 bpy.ops.wm.save_as_mainfile(filepath=str(OUT/(name+'.blend')))
 editable=sum(o.type=='MESH' for o in scene.objects);surfaces=ink.consolidate_static_surfaces()
 bpy.ops.export_scene.gltf(filepath=str(GAME/(name+'.glb')),export_format='GLB',export_apply=True,export_cameras=False,export_lights=False)
 # Render the exported geometry with Blender as a separate form/normal review.
 scene.world=bpy.data.worlds.new('Studio');scene.world.color=(.13,.16,.18)
 box('Studio floor',(0,0,-.045),(200,200,.06),'cream')
 bpy.ops.object.camera_add(location=(4,-6,4));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,1.2))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=3.8;scene.camera=cam
 for p,energy,size in [((2,-4,6),950,4),((-3,-1,4),600,3),((0,4,5),900,3)]:
  bpy.ops.object.light_add(type='AREA',location=p);o=bpy.context.object;o.data.energy=energy;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
 scene.render.engine='CYCLES';scene.cycles.samples=24;scene.render.resolution_x=1000;scene.render.resolution_y=1000;scene.render.resolution_percentage=100;scene.render.filepath=str(REVIEW/(name+'-blender.png'));bpy.ops.render.render(write_still=True)
 return {'id':name,'source':str((OUT/(name+'.blend')).relative_to(ROOT)),'output':str((GAME/(name+'.glb')).relative_to(ROOT)),'editable_objects':editable,'export_surfaces':surfaces,'blender':bpy.app.version_string,'material_preset':ink.PRESET['version'],'front':'Blender -Y / Godot +Z','generator':'tools/build_crew_stations.py'}

start()
for x in [-.64,.64]:
 for y in [-.46,.44]:foot(x,y)
box('Scanner platform',(0,0,.22),(1.65,1.30,.18),'dark',bevel=.10)
box('Standing deck',(0,-.14,.335),(1.44,.94,.07),'steel',bevel=.06)
for x in [-.22,.22]:box('Foot placement',(x,-.15,.38),(.22,.44,.025),'rubber',bevel=.055)
# The open front leaves the person visible; the arch and vertical rails explain the scan motion.
for x in [-.69,.69]:
 box('Load column',(x,.41,1.39),(.23,.36,2.20),'dark',bevel=.07)
 box('Removable column shield',(x,-.005,1.39),(.29,.35,2.05),'cream',bevel=.10)
 box('Linear scan rail',(x,-.20,1.40),(.075,.055,1.63),'steel',bevel=.018)
 box('Recessed guidance light',(x-.065*(1 if x>0 else -1),-.19,1.56),(.025,.022,.68),'light',bevel=.008)
 tube('Safety hand grip',[(x,-.25,.85),(x,-.42,.96),(x,-.42,1.23),(x,-.25,1.31)],.045,'orange')
box('Upper rounded bridge',(0,.18,2.43),(1.65,.56,.30),'cream',bevel=.12)
box('Bridge gasket',(0,.12,2.25),(1.35,.42,.07),'dark',bevel=.025)
box('Rear instrument spine',(0,.49,1.40),(.43,.20,1.80),'teal',bevel=.10)
for x in [-.13,.13]:tube('Service umbilical',[(x,.55,.42),(x,.70,.60),(x,.70,1.75),(x,.54,2.18)],.032,'rubber')
scan=pivot('Anim_ScanHead',(0,-.10,1.88))
box('Sensor carriage',(0,-.20,1.88),(1.22,.20,.20),'teal',scan,bevel=.07)
for x in [-.39,0,.39]:
 cyl('Optic housing',(x,-.33,1.88),.09,.09,'dark',scan,(math.pi/2,0,0));cyl('Scan lens',(x,-.39,1.88),.056,.035,'light',scan,(math.pi/2,0,0))
# Side-loading gem cartridge, large enough to identify independently of the body chamber.
box('Gem processor mount',(.93,.18,.86),(.40,.67,1.18),'dark',bevel=.08)
box('Gem processor shell',(.95,.13,1.03),(.42,.62,.63),'teal',bevel=.08)
tray=pivot('Anim_GemTray',(.95,-.25,1.09))
box('Cartridge slide',(.95,-.34,1.08),(.32,.43,.065),'steel',tray)
cyl('Gem socket rim',(.95,-.36,1.135),.11,.055,'orange',tray);cyl('Gem socket well',(.95,-.36,1.16),.075,.027,'dark',tray)
pivot('Socket_Interaction',(0,-.61,1.32));pivot('Socket_Gem',(.95,-.36,1.19))
a=export('augmentation_station')

start()
for x in [-.70,.70]:
 for y in [-.35,.35]:foot(x,y)
box('Bench underframe',(0,0,.47),(1.60,.85,.52),'dark',bevel=.09)
for x in [-.60,.60]:
 box('Tool cabinet',(x,.03,.70),(.38,.77,.87),'cream',bevel=.10)
 box('Drawer seal',(x,-.365,.66),(.30,.025,.35),'dark')
 box('Drawer face',(x,-.40,.66),(.27,.055,.31),'teal',bevel=.04)
 box('Drawer handle',(x,-.448,.72),(.17,.055,.045),'orange',bevel=.018)
box('Bench gasket',(0,0,1.12),(1.84,1.12,.12),'dark',bevel=.065)
box('Worktop',(0,-.03,1.20),(1.84,1.14,.10),'cream',bevel=.07)
box('Inset instrument mat',(0,-.10,1.265),(1.55,.79,.025),'teal',bevel=.04)
rotor=pivot('Anim_SpecimenTurntable',(-.38,-.10,1.29))
cyl('Bearing housing',(-.38,-.10,1.30),.30,.075,'dark')
cyl('Specimen platter',(-.38,-.10,1.365),.255,.065,'steel',rotor)
for angle in [0,120,240]:
 t=math.radians(angle);x=-.38+.20*math.cos(t);y=-.10+.20*math.sin(t)
 box('Specimen retaining jaw',(x,y,1.42),(.11,.075,.08),'orange',rotor,bevel=.02)
# Cantilevered optical head with a hinge and real guide rail.
box('Microscope tower',(-.65,.41,1.56),(.28,.24,.66),'teal',bevel=.08)
cyl('Optical hinge',(-.65,.37,1.87),.13,.19,'steel',rot=(math.pi/2,0,0))
arm=pivot('Anim_OpticalArm',(-.65,.37,1.87))
box('Optical cantilever',(-.39,.10,1.89),(.28,.75,.17),'cream',arm,bevel=.055)
cyl('Focusing barrel',(-.38,-.15,1.72),.115,.24,'dark',arm)
cyl('Objective lens',(-.38,-.15,1.59),.080,.035,'light',arm)
# Two distinct sample wells and an angled display form the secondary work zone.
for x in [.20,.57]:
 cyl('Sample tray socket',(x,-.26,1.32),.135,.075,'dark');cyl('Sample lid',(x,-.26,1.37),.11,.035,'steel')
box('Display foot',(.43,.33,1.39),(.22,.24,.26),'steel')
display=box('Angled display housing',(.43,.36,1.61),(.67,.14,.38),'dark',bevel=.055);display.rotation_euler.x=math.radians(15)
box('Diagnostic screen',(.43,.269,1.61),(.54,.026,.24),'teal',bevel=.02)
for i,h in enumerate([.04,.08,.12,.07,.15]):box('Measurement trace',(.23+i*.09,.250,1.56+h*.25),(.04,.014,h),'light',bevel=.004)
for x in [.22,.43,.64]:cyl('Control dial',(x,.08,1.29),.045,.05,'orange')
tube('Sensor cable',[(-.65,.5,1.6),(-.75,.57,1.45),(-.75,.57,.70),(-.3,.48,.50)],.032,'rubber')
pivot('Socket_Interaction',(0,-.64,1.25));pivot('Socket_Specimen',(-.38,-.10,1.44))
b=export('research_station')
(OUT/'stations_manifest.json').write_text(json.dumps([a,b],ensure_ascii=False,indent=2)+'\n')
print('CREW_STATIONS_EXPORTED',a,b)
