"""INK v1 expedition vessel: editable Blender original, merged export by material."""
from pathlib import Path
import bpy, math, json
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'art/blender/ships'; OUTPUT=ROOT/'우주-비즈니스/assets/models/ships'
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
hull('Pressure hull',[(-6.8,1.9,1,0),(-5.7,2.7,1.3,0),(1.8,2.8,1.25,0),(5.8,1.8,.7,-.15),(7.2,.45,.3,-.2)],'dark',.18)
hull('Dorsal ceramic armor',[(-5.8,2.35,.24,1.13),(-3.5,2.58,.26,1.28),(1.8,2.5,.2,1.25),(3.1,2,.15,1.1)],'cream',.12)
hull('Nose ceramic armor',[(2.2,2.57,.23,.65),(5.8,1.71,.2,.43),(7.1,.42,.15,-.02)],'cream',.13)
hull('Raised flight cabin',[(-.7,1.85,.65,1.63),(2.3,1.72,.58,1.62),(4.2,1.26,.30,1.12)],'teal',.18)
hull('Panoramic forward glazing',[(2.42,1.59,.34,1.91),(4.14,1.17,.23,1.35)],'glass',.055)
for x in [-1,0,1]:
 o=box('Windshield structural mullion',(x*1.0,3.3,1.97),(.08,1.55,.08),'steel',.025);o.rotation_euler.x=-.31
for side in [-1,1]:
 # Suspended cargo sponsons with armored rail separation.
 box('Cargo spine',(side*3.05,-1.9,-.12),(.48,7.4,.7),'steel',.12)
 for y in [-4.4,-1.8,.8]:
  box('Sealed exploration bay',(side*3.26,y,.22),(1.30,2.32,1.65),'teal',.18)
  box('Cargo inspection hatch',(side*3.94,y,.25),(.08,1.91,1.17),'cream',.07)
  box('Bay lock',(side*4.0,y,.25),(.07,.38,.34),'orange',.04)
  for yy in [-.72,.72]:box('Recessed hatch seam',(side*4.0,y+yy,.25),(.035,.04,.95),'dark',.01)
 box('Drive yoke',(side*3.9,-4.8,-.16),(3.2,1.3,.6),'dark',.14)
 cylinder('Main drive housing',(side*5.0,-5.0,.12),1.07,4.5,'cream')
 cylinder('Intake throat',(side*5.0,-2.69,.12),.78,.13,'dark')
 for j in range(10):
  a=j*math.tau/10; o=box('Intake turbine vane',(side*5+math.cos(a)*.4,-2.58,.12+math.sin(a)*.4),(.60,.08,.055),'steel',.01);o.rotation_euler.y=-a
 for y in [-6.8,-5.4,-3.5]:cylinder('Drive segmented collar',(side*5,y,.12),1.11,.18,'teal')
 cylinder('Exhaust recess',(side*5,-7.31,.12),.83,.18,'dark')
 cylinder('Drive emitter',(side*5,-7.43,.12),.57,.055,'light')
 for j in range(12):
  a=j*math.tau/12;box('Nozzle cooling tooth',(side*5+math.cos(a)*.87,-7.4,.12+math.sin(a)*.87),(.13,.38,.13),'steel',.025)
 for y in [-4.5,-3.9,-3.3,-2.7]:box('Dorsal heat sink',(side*1.65,y,1.62),(.9,.21,.1),'dark',.025)
 box('Approach lamp housing',(side*1.45,5.4,.45),(.52,.30,.30),'dark',.05)
 box('Approach lamp',(side*1.45,5.57,.45),(.37,.05,.13),'light',.035)
 for y in [-4.9,1.2]:
  cylinder('Attitude control port',(side*2.8,y,-.1),.20,.08,'dark',(0,math.pi/2,0),32)
  box('Landing leg recess',(side*1.4,y,-1.1),(.65,1.05,.18),'steel',.06)
box('Central dorsal stripe',(0,-2.8,1.58),(.6,5.35,.045),'orange',.02)
cylinder('Survey dish pedestal',(0,-5.0,1.88),.40,.7,'steel',(0,0,0))
bpy.ops.mesh.primitive_uv_sphere_add(segments=48,ring_count=24,radius=1,location=(0,-5.0,2.3));o=bpy.context.object;o.scale=(.85,.85,.23);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);finish(o,'Sensor radome','teal',0)
# Layered aft access door and readable fleet marking.
box('Aft boarding frame',(0,-6.84,-.12),(2.25,.18,1.6),'steel',.09)
box('Aft boarding hatch',(0,-6.96,-.12),(1.93,.07,1.34),'teal',.065)
for x in [-.52,.52]:box('Hatch grip',(x,-7.03,-.05),(.085,.065,.43),'orange',.025)
bpy.ops.object.text_add(location=(0,-.2,1.58));o=bpy.context.object;o.data.body='LOCUS / KESTREL';o.data.align_x='CENTER';o.data.size=.26;o.data.extrude=.004;o.data.materials.append(P['dark']);bpy.ops.object.convert(target='MESH');o.name='Registry marking'
bpy.context.scene.unit_settings.system='METRIC'
source=SOURCE/'kestrel.blend';output=OUTPUT/'kestrel.glb'
bpy.ops.wm.save_as_mainfile(filepath=str(source))
# Keep full editable source. Export batching reduces draw calls without flattening form.
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
(SOURCE/'manifest.json').write_text(json.dumps({'generator':'tools/build_expedition_ship.py','source':str(source.relative_to(ROOT)),'output':str(output.relative_to(ROOT)),'triangles':triangles,'style':'ink-v1','role':'shared expedition vessel; cabin simulation pending'},indent=2)+'\n')
print('KESTREL_EXPORTED',triangles)
