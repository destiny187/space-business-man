import bpy, math, random
from pathlib import Path
root=Path(__file__).resolve().parents[1]
out=root/'art/blender/space';out.mkdir(parents=True,exist_ok=True)
export=root/'우주-비즈니스/assets/models/space';export.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
random.seed(67321)
verts=[];faces=[]
for i in range(14000):
 r=random.random()**.65;a=random.random()*math.tau
 if i%3:a=(i%4)*math.tau/4+r*4+random.gauss(0,.12)
 x,y,z=math.cos(a)*r,math.sin(a)*r,random.gauss(0,.012)*(1.1-r)
 d=random.uniform(.00045,.0012);j=len(verts)
 verts.extend([(x-d,y-d,z),(x+d,y-d,z),(x,y+d,z),(x,y,z+d*2)])
 faces.extend([(j,j+1,j+2),(j,j+3,j+1),(j+1,j+3,j+2),(j+2,j+3,j)])
mesh=bpy.data.meshes.new('SpiralStellarCloud');mesh.from_pydata(verts,[],faces);mesh.update()
obj=bpy.data.objects.new('SpiralStellarCloud',mesh);bpy.context.collection.objects.link(obj)
mat=bpy.data.materials.new('stellar_light');mat.diffuse_color=(.56,.72,1,1);mat.use_nodes=True
bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(.56,.72,1,1);bs.inputs['Emission Color'].default_value=(.56,.72,1,1);bs.inputs['Emission Strength'].default_value=2
obj.data.materials.append(mat)
bpy.ops.wm.save_as_mainfile(filepath=str(out/'galaxy_map.blend'))
bpy.ops.export_scene.gltf(filepath=str(export/'galaxy_map.glb'),export_format='GLB')

for label,stride in [('far',24),('medium',6)]:
 lv=[];lf=[]
 for i in range(0,14000,stride):
  j=len(lv);lv.extend(verts[i*4:i*4+4]);lf.extend([(j,j+1,j+2),(j,j+3,j+1),(j+1,j+3,j+2),(j+2,j+3,j)])
 lm=bpy.data.meshes.new('cloud_'+label);lm.from_pydata(lv,[],lf);lm.update()
 lo=bpy.data.objects.new('cloud_'+label,lm);bpy.context.collection.objects.link(lo);lo.data.materials.append(mat)
 bpy.ops.object.select_all(action='DESELECT');lo.select_set(True)
 bpy.ops.export_scene.gltf(filepath=str(export/('galaxy_map_'+label+'.glb')),export_format='GLB',use_selection=True)
 lo.hide_render=True;lo.hide_viewport=True
bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,radius=1)
star=bpy.context.object;star.name='navigation_star';star.data.materials.append(mat)
for polygon in star.data.polygons:polygon.use_smooth=True
bpy.ops.object.select_all(action='DESELECT');star.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(export/'navigation_star.glb'),export_format='GLB',use_selection=True)
star.hide_render=True;star.hide_viewport=True

bpy.ops.object.camera_add(location=(0,-2.6,2.7));camera=bpy.context.object;camera.rotation_euler=((mathutils:=__import__('mathutils')).Vector((0,0,0))-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='ORTHO';camera.data.ortho_scale=2.45
scene=bpy.context.scene;scene.camera=camera;scene.render.engine='CYCLES';scene.cycles.samples=8;scene.world.color=(.003,.003,.003);scene.render.resolution_x=1000;scene.render.resolution_y=760;scene.render.resolution_percentage=100
scene.render.filepath=str(out/'galaxy_map-preview.png');bpy.ops.wm.save_as_mainfile(filepath=str(out/'galaxy_map.blend'));bpy.ops.render.render(write_still=True)
