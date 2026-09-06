"""Render original Blender assets as transparent product portraits for the game UI.
Run with Blender --background --python tools/render_catalog.py. Sources are read only.
"""
from pathlib import Path
import math
import sys
import bpy
from mathutils import Vector

root=Path(__file__).resolve().parents[1]
output=root/'우주-비즈니스/assets/ui/previews'
output.mkdir(parents=True,exist_ok=True)
assets=['manual_tool','miner','surveyor','guardian','storage','solar','charger','factory','atmosphere','thermal','water','biolab','reactor','ruin','microbe','animal','civilization']
if "--" in sys.argv:
    requested=sys.argv[sys.argv.index("--")+1:]
    if set(requested)-set(assets): raise SystemExit("Unknown portrait ID")
    if requested: assets=[name for name in assets if name in requested]
for name in assets:
    bpy.ops.wm.open_mainfile(filepath=str(root/'art/blender'/(name+'.blend')))
    scene=bpy.context.scene
    points=[obj.matrix_world@Vector(v) for obj in scene.objects if obj.type=='MESH' for v in obj.bound_box]
    low=Vector(tuple(min(p[i] for p in points) for i in range(3)))
    high=Vector(tuple(max(p[i] for p in points) for i in range(3)))
    center=(low+high)/2
    span=max(high-low)
    camera_data=bpy.data.cameras.new('Catalog camera')
    camera=bpy.data.objects.new('Catalog camera',camera_data)
    scene.collection.objects.link(camera)
    camera.location=center+Vector((1.4,-2.0,1.25))*span
    camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler()
    camera_data.type='ORTHO'
    view=camera.rotation_euler.to_matrix().transposed()
    projected=[view@(point-center) for point in points]
    width=max(point.x for point in projected)-min(point.x for point in projected)
    height=max(point.y for point in projected)-min(point.y for point in projected)
    camera_data.ortho_scale=max(width,height*1.5)*1.12
    scene.camera=camera
    for label,offset,power,color in [('Key',(-2,-3,4),650,(1,.9,.76)),('Fill',(3,-1,2),400,(.66,.87,1)),('Rim',(1,3,3),900,(.54,1,.85))]:
        light_data=bpy.data.lights.new(label,'AREA')
        light_data.energy=power*max(1,span*span/10)
        light_data.color=color
        light_data.shape='DISK'
        light_data.size=span*1.5
        light=bpy.data.objects.new(label,light_data)
        scene.collection.objects.link(light)
        light.location=center+Vector(offset)*span
        light.rotation_euler=(center-light.location).to_track_quat('-Z','Y').to_euler()
    scene.render.engine='CYCLES'
    scene.cycles.samples=24
    scene.cycles.use_denoising=True
    scene.render.resolution_x=480
    scene.render.resolution_y=320
    scene.render.resolution_percentage=100
    scene.render.film_transparent=True
    scene.render.image_settings.file_format='PNG'
    scene.render.image_settings.color_mode='RGBA'
    scene.render.filepath=str(output/(name+'.png'))
    if scene.world is None: scene.world=bpy.data.worlds.new('Catalog studio')
    scene.world.color=(.22,.25,.3)
    scene.view_settings.view_transform='AgX'
    bpy.ops.render.render(write_still=True)
    print('CATALOG_RENDER',name,flush=True)
