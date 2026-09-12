"""Blender EEVEE source inspection; the delivered INK render is still Godot Forward+."""
from pathlib import Path
import bpy
from mathutils import Vector as V
import ink_blender as ink
ROOT=Path(__file__).resolve().parents[2]
def render(s):
    scene=bpy.context.scene;scene.frame_set(1);bpy.context.view_layer.update()
    points=[o.matrix_world@V(p) for o in scene.objects if o.type=='MESH' for p in o.bound_box];lo=V(tuple(min(p[i] for p in points) for i in range(3)));hi=V(tuple(max(p[i] for p in points) for i in range(3)));center=(lo+hi)*.5;size=max(hi-lo)
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.04));bpy.context.object.data.materials.append(ink.material('structural_dark'))
    bpy.ops.object.camera_add(location=center+V((1.2,-1.7,1.1)).normalized()*size*3);cam=bpy.context.object;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=size*1.6;scene.camera=cam
    scene.world=bpy.data.worlds.new('Studio');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.20,.23,.28,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.5
    for offset,energy in [((1,-1.5,2),130),((-1,-.2,.8),60),((.5,1.3,1.4),100)]:
        bpy.ops.object.light_add(type='AREA',location=center+V(offset)*size);lamp=bpy.context.object;lamp.data.energy=energy*size*size;lamp.data.size=size*1.1;lamp.rotation_euler=(center-lamp.location).to_track_quat('-Z','Y').to_euler()
    scene.render.engine='BLENDER_EEVEE';scene.eevee.use_raytracing=True;scene.eevee.fast_gi_method='AMBIENT_OCCLUSION_ONLY';scene.eevee.fast_gi_distance=3.;scene.eevee.fast_gi_quality=.75;scene.eevee.fast_gi_ray_count=4;scene.eevee.shadow_ray_count=3;scene.eevee.taa_render_samples=64
    scene.render.resolution_x=640;scene.render.resolution_y=560;scene.render.resolution_percentage=100
    scene.render.filepath=str(ROOT/'docs/production/media/creature-remodel'/s.spec['production_batch']/'blender'/(s.spec['id']+'.png'));bpy.ops.render.render(write_still=True)
