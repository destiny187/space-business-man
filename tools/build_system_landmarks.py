"""Blender asteroid silhouettes and a layered planetary ring, in game-ready units."""
import bpy, math, json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]; SRC=ROOT/'art/blender/system-landmarks';OUT=ROOT/'우주-비즈니스/assets/models/system-landmarks';PREVIEW=ROOT/'docs/production/media/system-diversity/blender'
for p in (SRC,OUT,PREVIEW):p.mkdir(parents=True,exist_ok=True)
records=[]
for index,name in enumerate(['asteroid_ridge','asteroid_split','asteroid_flat','planet_rings']):
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 material=bpy.data.materials.new(name);material.diffuse_color=(.29,.25,.22,1) if index<3 else (.48,.41,.3,1);material.use_nodes=True;material.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=material.diffuse_color;material.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.95
 if index<3:
  bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3,radius=1);obj=bpy.context.object;obj.name=name
  for v in obj.data.vertices:
   p=v.co.copy();r=1+.13*math.sin(p.x*9+index*3)*math.sin(p.z*7+p.y*2)+.09*math.sin(p.y*15+p.x*3)
   v.co=Vector((p.x*r*[1.3,.85,1.45][index],p.y*r*[.72,1.2,1.1][index],p.z*r*[.9,.85,.45][index]))
  bevel=obj.modifiers.new('Worn edges','BEVEL');bevel.width=.015;bevel.segments=2
  for face in obj.data.polygons:face.use_smooth=True
  obj.data.materials.append(material)
 else:
  vertices=[];faces=[]
  for inner,outer in [(1.3,1.48),(1.52,1.83),(1.9,2.13),(2.17,2.25)]:
   start=len(vertices);n=256
   for rad in (inner,outer):
    for i in range(n):vertices.append((rad*math.cos(i*math.tau/n),rad*math.sin(i*math.tau/n),0))
   for i in range(n):faces.append((start+i,start+(i+1)%n,start+n+(i+1)%n,start+n+i))
  mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update();obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj);obj.data.materials.append(material);obj.select_set(True);bpy.context.view_layer.objects.active=obj
  solid=obj.modifiers.new('Ring thickness','SOLIDIFY');solid.thickness=.002
 bpy.ops.wm.save_as_mainfile(filepath=str(SRC/(name+'.blend')))
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_apply=True,export_yup=True)
 scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=8;scene.render.resolution_x=400;scene.render.resolution_y=400;scene.render.resolution_percentage=100;scene.world.color=(.045,.045,.045)
 bpy.ops.object.camera_add(location=(3,-5,3));cam=bpy.context.object;cam.rotation_euler=(-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=5.4;scene.camera=cam
 bpy.ops.object.light_add(type='AREA',location=(-3,-4,5));lamp=bpy.context.object;lamp.data.energy=850;lamp.data.size=4;lamp.rotation_euler=(-lamp.location).to_track_quat('-Z','Y').to_euler()
 scene.render.filepath=str(PREVIEW/(name+'.png'));bpy.ops.render.render(write_still=True)
 records.append({'id':name,'source':str((SRC/(name+'.blend')).relative_to(ROOT)),'model':'res://assets/models/system-landmarks/'+name+'.glb','preview':str((PREVIEW/(name+'.png')).relative_to(ROOT))})
 print('LANDMARK DONE',name,flush=True)
(SRC/'manifest.json').write_text(json.dumps(records,indent=2)+'\n')
