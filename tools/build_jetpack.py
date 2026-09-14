"""Editable T2 jetpack, shared INK materials; local origin is the backpack centre."""
import sys
from pathlib import Path
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import ink_blender as ink
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def box(name,at,size,role):
    bpy.ops.mesh.primitive_cube_add(size=1,location=at);o=bpy.context.object;o.name=name;o.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.data.materials.append(ink.material(role));ink.manufactured_edges(o,.025,4);return o
def cylinder(name,at,radius,depth,role):
    bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=radius,depth=depth,location=at)
    o=bpy.context.object;o.name=name;o.data.materials.append(ink.material(role));ink.manufactured_edges(o,.012,3);return o
box('Spine mounting frame',(0,.09,0),(.42,.11,.58),'enamel_teal')
box('Battery cassette',(0,0,.04),(.26,.23,.43),'enamel_cream')
box('Controller cover',(0,-.14,.13),(.18,.05,.16),'enamel_teal')
for side in [-1,1]:
    x=side*.27
    cylinder('Duct housing',(x,0,.02),.135,.5,'enamel_cream')
    cylinder('Intake rim',(x,0,.285),.145,.045,'enamel_teal')
    cylinder('Intake recess',(x,0,.302),.112,.012,'enamel_teal')
    for i in range(5):box('Intake grille',(x,-.075+i*.0375,.312),(.18,.014,.015),'enamel_cream')
    cylinder('Gimbal collar',(x,0,-.24),.145,.06,'enamel_teal')
    cylinder('Nozzle throat',(x,0,-.295),.105,.06,'enamel_teal')
    box('Side battery rail',(x+side*.11,.07,0),(.04,.1,.32),'enamel_teal')
    box('Harness lug',(side*.15,.16,.23),(.09,.08,.07),'enamel_teal')
for z in [-.14,-.08,-.02]:box('Cooling rib',(0,-.132,z),(.2,.03,.023),'enamel_teal')
src=ROOT/'art/blender/equipment/jetpack_mk2.blend';src.parent.mkdir(parents=True,exist_ok=True)
out=ROOT/'우주-비즈니스/assets/models/equipment/jetpack_mk2.glb'
bpy.ops.wm.save_as_mainfile(filepath=str(src))
ink.consolidate_static_surfaces()
bpy.ops.export_scene.gltf(filepath=str(out),export_format='GLB',export_yup=True)
# Cycles source render, independent from the required Godot INK review.
bpy.ops.object.camera_add(location=(1.5,-2,1.1));cam=bpy.context.object
cam.rotation_euler=(Vector((0,0,0))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=1.15
bpy.context.scene.camera=cam
bpy.ops.object.light_add(type='AREA',location=(1,-2,3));bpy.context.object.data.energy=350;bpy.context.object.data.shape='DISK';bpy.context.object.data.size=3
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.world.color=(.3,.3,.3)
scene.render.resolution_x=800;scene.render.resolution_y=800;scene.render.resolution_percentage=100
review=ROOT/'output/flight-combat';review.mkdir(parents=True,exist_ok=True)
scene.render.filepath=str(review/'jetpack-blender.png');bpy.ops.render.render(write_still=True)
