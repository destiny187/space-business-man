"""Blender-authored flight nozzle, fractured orbital rock and ring ice, with renders."""
import bpy, sys, math, json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import ink_blender as ink
SRC=ROOT/'art/blender/space-polish';OUT=ROOT/'우주-비즈니스/assets/models/space';PRE=ROOT/'docs/production/media/space-polish-v2'
for p in [SRC,OUT,PRE]:p.mkdir(parents=True,exist_ok=True)
def natural(name,color,rough):
 m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*color,1);bs=m.node_tree.nodes['Principled BSDF'];bs.inputs['Base Color'].default_value=m.diffuse_color;bs.inputs['Roughness'].default_value=rough;return m
def cylinder(name,r,depth,y,mat):
 bpy.ops.mesh.primitive_cylinder_add(vertices=40,radius=r,depth=depth,location=(0,y,0),rotation=(math.pi/2,0,0));o=bpy.context.object;o.name=name;o.data.materials.append(mat);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);ink.manufactured_edges(o,width=.014,segments=3);return o
records=[]
for name in ['attitude_nozzle','orbital_rock','orbital_ice']:
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 if name=='attitude_nozzle':
  cream=ink.material('enamel_cream');dark=ink.material('structural_dark');steel=ink.material('edge_steel');orange=ink.material('safety_orange')
  cylinder('Mount',.25,.13,.25,dark);cylinder('Housing',.20,.34,.05,cream);cylinder('SafetyCollar',.208,.035,-.06,orange);cylinder('NozzleRim',.16,.13,-.17,steel);cylinder('RecessedCeramic',.125,.02,-.24,dark)
  for i in range(4):
   a=i*math.pi/2;bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=8,radius=.038,location=(math.cos(a)*.225,.19,math.sin(a)*.225));o=bpy.context.object;o.name='MountFastener';o.data.materials.append(steel)
 else:
  icy=name=='orbital_ice';mat=natural('Orbital ice cleavage' if icy else 'Orbital fractured silicate',(.38,.58,.65) if icy else (.22,.18,.14),.38 if icy else .91)
  inset=natural('Fresh cleavage' if icy else 'Weathered seams',(.60,.76,.78) if icy else (.36,.28,.20),.46 if icy else .97)
  bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3,radius=1);o=bpy.context.object;o.name=name
  for v in o.data.vertices:
   p=v.co.copy();r=1+.11*math.sin(p.x*8+p.z*4)*math.sin(p.y*7)+.07*math.cos(p.z*14)
   p*=r;p.x*=1.25;p.z*=.67
   if icy:p.x=min(p.x,.84);p.z=max(p.z,-.46)
   else:p.x-=.12*math.exp(-p.y*p.y*120)
   v.co=p
  o.data.materials.append(mat);o.data.materials.append(inset)
  for f in o.data.polygons:
   f.material_index=1 if f.index%13<2 else 0;f.use_smooth=False
  ink.manufactured_edges(o,width=.025,segments=2)
 assets=list(bpy.context.scene.objects)
 bpy.ops.wm.save_as_mainfile(filepath=str(SRC/(name+'.blend')))
 ink.consolidate_static_surfaces()
 bpy.ops.object.select_all(action='SELECT')
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_apply=True)
 bpy.ops.object.camera_add(location=(2.5,-4,2.2));cam=bpy.context.object;cam.rotation_euler=(-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=1.1 if name=='attitude_nozzle' else 3.6
 scene=bpy.context.scene;scene.camera=cam
 bpy.ops.object.light_add(type='AREA',location=(-3,-4,6));lamp=bpy.context.object;lamp.data.energy=450;lamp.data.size=4;lamp.rotation_euler=(-lamp.location).to_track_quat('-Z','Y').to_euler()
 scene.render.engine='CYCLES';scene.cycles.samples=16;scene.render.resolution_x=512;scene.render.resolution_y=512;scene.render.resolution_percentage=100;scene.world.color=(.04,.04,.04);scene.render.filepath=str(PRE/(name+'-blender.png'))
 bpy.ops.render.render(write_still=True)
 records.append({'id':name,'source':str((SRC/(name+'.blend')).relative_to(ROOT)),'model':str((OUT/(name+'.glb')).relative_to(ROOT)),'preview':str((PRE/(name+'-blender.png')).relative_to(ROOT)),'axis':'Nozzle outlet Blender -Y / Godot +Z' if name=='attitude_nozzle' else 'Blender Z up / Godot Y up','status':'blender_rendered_pending_game_review'})
 print('ORBITAL_DETAIL_DONE',name,flush=True)
(SRC/'manifest.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n')
