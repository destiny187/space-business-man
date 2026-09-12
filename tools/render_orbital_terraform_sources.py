"""Inspect existing Blender relief used by orbital terraforming without changing assets."""
from pathlib import Path
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'docs/production/media/orbital-terraforming'
DEST.mkdir(parents=True, exist_ok=True)
for family in ('oxidized', 'fractured'):
    bpy.ops.wm.open_mainfile(filepath=str(ROOT / 'art/blender/planet-variants' / (family + '.blend')))
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 12
    scene.render.resolution_x = scene.render.resolution_y = 600
    scene.render.resolution_percentage = 100
    scene.world = bpy.data.worlds.new('Orbital source review')
    scene.world.color = (.035, .045, .06)
    bpy.ops.object.camera_add(location=(2, -4, 1.6))
    camera = bpy.context.object
    camera.rotation_euler = (-camera.location).to_track_quat('-Z', 'Y').to_euler()
    camera.data.type = 'ORTHO'
    camera.data.ortho_scale = 2.7
    scene.camera = camera
    for location, power in [((-3, -4, 5), 650), ((4, -1, 2), 150)]:
        bpy.ops.object.light_add(type='AREA', location=location)
        light = bpy.context.object
        light.data.energy, light.data.size = power, 3
        light.rotation_euler = (-Vector(location)).to_track_quat('-Z', 'Y').to_euler()
    scene.render.filepath = str(DEST / (family + '-blender.png'))
    bpy.ops.render.render(write_still=True)
    print('SOURCE_REVIEW', family, flush=True)
