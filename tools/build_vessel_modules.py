"""INK v1 expedition vessel: editable Blender original, merged export by material."""
from pathlib import Path
import bpy, math, json
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'art/blender/ships/modules'; OUTPUT=ROOT/'우주-비즈니스/assets/models/ships/modules'
SOURCE.mkdir(parents=True,exist_ok=True); OUTPUT.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
def mat(name,color,metal=.1,rough=.5,emission=0):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
 if emission:p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=emission
 return m
P={'cream':mat('Ceramic enamel',(.76,.78,.65)), 'teal':mat('Lagoon armor',(.025,.26,.26),.3), 'dark':mat('Graphite frame',(.016,.027,.032)), 'steel':mat('Edge steel',(.24,.34,.36),.65,.27), 'orange':mat('Safety orange',(.93,.31,.035),.2), 'glass':mat('Cockpit glass',(.015,.075,.11),.45,.17), 'light':mat('Drive plasma',(.08,.75,.9),.1,.3,3)}
def finish(o,n,key,b=.06,smooth=True):
 o.name=n;o.data.materials.append(P[key])
 if b:
  mod=o.modifiers.new('Machined curvature','BEVEL');mod.width=b;mod.segments=4;o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
 for poly in o.data.polygons:poly.use_smooth=smooth
 return o
def box(n,p,s,key,b=.07):
 bpy.ops.mesh.primitive_cube_add(size=1,location=p);o=bpy.context.object;o.scale=s;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return finish(o,n,key,b)
def cylinder(n,p,r,d,key,rot=(math.pi/2,0,0),verts=64):
 bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=r,depth=d,location=p,rotation=rot);return finish(bpy.context.object,n,key,min(.06,d*.15))
def hull(n,sections,key,b=.1):
 vertices=[];faces=[]
 # Octagonal, beveled hull cross sections; Blender +Y becomes Godot -Z.
 profile=[(-.72,1),(.72,1),(1,.55),(1,-.5),(.70,-1),(-.70,-1),(-1,-.5),(-1,.55)]
 for y,w,h,z in sections:
  vertices.extend((x*w,y,k*h+z) for x,k in profile)
 for i in range(len(sections)-1):
  for j in range(8):a=i*8+j;faces.append((a,i*8+(j+1)%8,(i+1)*8+(j+1)%8,a+8))
 faces.extend([tuple(reversed(range(8))),tuple((len(sections)-1)*8+j for j in range(8))])
 mesh=bpy.data.meshes.new(n);mesh.from_pydata(vertices,[],faces);mesh.update();o=bpy.data.objects.new(n,mesh);bpy.context.collection.objects.link(o)
 # Recalculate outward normals before export.
 bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT');o.select_set(False)
 return finish(o,n,key,b)
records=[]
for kind in ['vector_drive','mobile_lab','robot_pod']:
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 box('Load bearing coupling',(0,0,.12),(1.3,2.5,.24),'dark',.09)
 for x in [-.48,.48]:
  box('Quick release rail',(x,0,.28),(.17,2.3,.2),'steel',.04)
  for y in [-.85,.85]:box('Orange locking latch',(x,y,.36),(.24,.22,.12),'orange',.025)
 if kind=='vector_drive':
  hull('Aerodynamic power spine',[(-1.2,.64,.44,.83),(-.6,.78,.58,.89),(.8,.63,.47,.84),(1.4,.35,.21,.68)],'teal',.10)
  hull('Heat shield',[(-.8,.61,.15,1.36),(.6,.56,.15,1.30),(1.3,.30,.12,.89)],'cream',.075)
  for x in [-.84,.84]:
   cylinder('Vector nacelle',(x,-.15,.74),.40,2.35,'cream')
   for y in [-1.18,-.60,.5]:cylinder('Magnetic containment ring',(x,y,.74),.435,.13,'teal')
   cylinder('Recessed exhaust',(x,-1.4,.74),.33,.16,'dark')
   cylinder('Plasma aperture',(x,-1.49,.74),.22,.04,'light')
   for j in range(8):
    a=j*math.tau/8;box('Nozzle cooling tooth',(x+math.cos(a)*.32,-1.48,.74+math.sin(a)*.32),(.06,.24,.06),'steel',.012)
  for y in [-.7,-.42,-.14,.14]:box('Dorsal heat exchanger',(0,y,1.55),(.70,.11,.12),'dark',.02)
 elif kind=='mobile_lab':
  hull('Sealed mobile laboratory',[(-1.25,.56,.59,.93),(-.85,.79,.70,.96),(.85,.79,.70,.96),(1.25,.55,.57,.93)],'teal',.12)
  box('Laboratory dorsal armor',(0,0,1.65),(1.22,1.96,.18),'cream',.09)
  for x in [-.78,.78]:
   box('Optical observation recess',(x,0,1.02),(.12,1.65,.88),'dark',.065)
   for y in [-.51,0,.51]:
    box('Sealed glass sample chamber',(x*1.075,y,1.07),(.08,.42,.59),'glass',.035)
    box('Culture illumination',(x*1.13,y,.81),(.035,.28,.035),'light',.008)
   for y in [-.97,.97]:box('Pressure bulkhead',(x*.89,y,.98),(.15,.17,1.03),'steel',.04)
  cylinder('Sterile service port',(0,1.28,.92),.35,.12,'steel')
  cylinder('Sterile service seal',(0,1.36,.92),.23,.06,'orange')
  for x in [-.38,0,.38]:box('Radiator vane',(x,-.44,1.82),(.15,.91,.16),'steel',.025)
 else:
  hull('Robot transport pressure shell',[(-1.25,.66,.61,.96),(-.97,.86,.74,1),(.97,.86,.74,1),(1.25,.66,.61,.96)],'cream',.12)
  box('Transport backbone',(0,0,1.78),(.42,2.0,.16),'teal',.06)
  for x in [-.84,.84]:
   box('Robot service hatch recess',(x,0,1.02),(.08,1.86,1.12),'dark',.06)
   for y in [-.46,.46]:
    box('Armored robot hatch',(x*1.045,y,1.04),(.07,.82,.94),'teal',.06)
    box('Robot retention lock',(x*1.10,y,1.04),(.05,.25,.25),'orange',.025)
    box('Bay status lamp',(x*1.11,y,1.34),(.045,.28,.035),'light',.012)
   for y in [-1.02,1.02]:box('Load bearing cage rib',(x*.87,y,1),(.22,.18,1.38),'steel',.05)
  for y in [-1.29,1.29]:
   box('Airlock frame',(0,y,.98),(1.19,.12,1.03),'dark',.06)
   box('Pressure door',(0,y*1.055,.98),(1.0,.06,.86),'teal',.04)
   for x in [-.29,.29]:box('Cargo clamp',(x,y*1.08,1),(.10,.08,.42),'orange',.02)
 bpy.context.scene.unit_settings.system='METRIC'
 source=SOURCE/(kind+'.blend');output=OUTPUT/(kind+'.glb')
 bpy.ops.wm.save_as_mainfile(filepath=str(source))
 groups={}
 for o in list(bpy.context.scene.objects):
  if o.type!='MESH':continue
  bpy.context.view_layer.objects.active=o
  for mod in list(o.modifiers):bpy.ops.object.modifier_apply(modifier=mod.name)
  groups.setdefault(o.data.materials[0].name,[]).append(o)
 for objects in groups.values():
  bpy.ops.object.select_all(action='DESELECT')
  for o in objects:o.select_set(True)
  bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join()
 bpy.ops.export_scene.gltf(filepath=str(output),export_format='GLB',export_yup=True)
 triangles=0
 for o in bpy.context.scene.objects:
  if o.type=='MESH':o.data.calc_loop_triangles();triangles+=len(o.data.loop_triangles)
 records.append({'id':kind,'source':str(source.relative_to(ROOT)),'output':str(output.relative_to(ROOT)),'triangles':triangles,'materials':len(groups),'style':'ink-v1','review':'in-engine review required; not an approved reference'})
 print('VESSEL_MODULE_EXPORTED',kind,triangles)
(SOURCE/'manifest.json').write_text(json.dumps({'generator':'tools/build_vessel_modules.py','assets':records},indent=2)+'\n')
