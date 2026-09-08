"""Blender source and smooth orbital-map star glyph; shaders provide in-game light."""
from pathlib import Path
import bpy
from mathutils import Vector
root = Path(__file__).resolve().parents[1]
source = root / 'art/blender/space'
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=1)
star = bpy.context.object
star.name = 'NavigationStar'
for polygon in star.data.polygons:
    polygon.use_smooth = True
material = bpy.data.materials.new('stellar_light')
material.diffuse_color = (.56, .72, 1, 1)
material.use_nodes = True
bsdf = material.node_tree.nodes.get('Principled BSDF')
bsdf.inputs['Base Color'].default_value = (.56, .72, 1, 1)
bsdf.inputs['Roughness'].default_value = .5
bsdf.inputs['Emission Color'].default_value = (.2, .35, .6, 1)
bsdf.inputs['Emission Strength'].default_value = .25
star.data.materials.append(material)
bpy.ops.wm.save_as_mainfile(filepath=str(source / 'navigation_star.blend'))
bpy.ops.export_scene.gltf(filepath=str(root / '우주-비즈니스/assets/models/space/navigation_star.glb'), export_format='GLB', use_selection=True)
bpy.ops.object.camera_add(location=(0, -4, 2))
camera = bpy.context.object
camera.rotation_euler = (-camera.location).to_track_quat('-Z', 'Y').to_euler()
camera.data.type = 'ORTHO'
camera.data.ortho_scale = 3.2
bpy.context.scene.camera = camera
bpy.ops.object.light_add(type='AREA', location=(-3, -3, 5))
bpy.context.object.data.energy = 350
bpy.context.object.data.shape = 'DISK'
bpy.context.object.data.size = 4
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 16
scene.world.color = (.015, .02, .03)
scene.render.resolution_x = 512
scene.render.resolution_y = 512
scene.render.resolution_percentage = 100
scene.render.filepath = str(source / 'navigation_star-preview.png')
bpy.ops.wm.save_as_mainfile(filepath=str(source / 'navigation_star.blend'))
bpy.ops.render.render(write_still=True)
