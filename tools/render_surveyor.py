"""Blender source render: inspect deformed surveyor knees, ankle and elbows."""
from pathlib import Path
import bpy, math
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
rig=bpy.data.objects.get('SurveyorRig')
assert rig and len(rig.data.bones)==13
for name,angle in {'thigh_L':.55,'shin_L':-.9,'foot_L':.35,'thigh_R':-.1,'shin_R':-.18,'foot_R':.28,'upper_arm_L':-.2,'forearm_L':.55,'upper_arm_R':.3,'forearm_R':.3}.items():
 bone=rig.pose.bones[name];bone.rotation_mode='XYZ';bone.rotation_euler.x=angle
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.04))
floor=bpy.context.object
mat=bpy.data.materials.new('Review floor');mat.diffuse_color=(.08,.11,.14,1);floor.data.materials.append(mat)
bpy.ops.object.camera_add(location=(3.1,4.8,2.7));camera=bpy.context.object
camera.rotation_euler=(Vector((0,0,1))-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='ORTHO';camera.data.ortho_scale=2.65
scene=bpy.context.scene;scene.camera=camera;scene.render.engine='CYCLES';scene.cycles.samples=24
for name,p,energy,size in [('Key', (2,3,5),650,4),('Fill',(-3,2,3),350,3),('Rim',(1,-3,4),800,3)]:
 bpy.ops.object.light_add(type='AREA',location=p);o=bpy.context.object;o.name=name;o.data.energy=energy;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
scene.world.color=(.22,.22,.22);scene.render.resolution_x=900;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
out=ROOT/'docs/production/media/crew-locomotion';out.mkdir(parents=True,exist_ok=True)
scene.render.filepath=str(out/'blender-joints.png');bpy.ops.render.render(write_still=True)
print('SURVEYOR_SOURCE_RENDER',scene.render.filepath)
