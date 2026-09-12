"""Read-only Blender source check for reused weapons; render a representative mechanism.
Run with Blender --background --python tools/media/review_firearm_sources.py.
"""
from pathlib import Path
import hashlib
import json
import sys
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
import ink_blender as ink

OUT = ROOT / 'output/ground-weapon-feedback'
OUT.mkdir(parents=True, exist_ok=True)
records = []
for source in sorted((ROOT / 'art/blender/equipment').glob('gun_*.blend')):
    bpy.ops.wm.open_mainfile(filepath=str(source))
    family = source.stem.removeprefix('gun_')
    output = ROOT / '우주-비즈니스/assets/models/equipment' / (source.stem + '.glb')
    sockets = [o for o in bpy.data.objects if o.name.startswith('Socket_Muzzle')]
    parts = [o.name for o in bpy.data.objects if o.name.startswith('Anim_')]
    assert len(sockets) == 1 and 'Anim_Bolt' in parts and 'Anim_Magazine' in parts
    records.append({'family': family, 'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
                    'glb_sha256': hashlib.sha256(output.read_bytes()).hexdigest(), 'parts': parts,
                    'muzzle': list(sockets[0].location), 'status': 'existing source and export preserved'})
    if family != 'carbine':continue
    bpy.context.scene.world = bpy.data.worlds.new('Read only weapon review')
    bpy.context.scene.world.color = (.19, .19, .19)
    bpy.data.objects['Anim_Bolt'].location.y -= .055
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -.50))
    bpy.context.object.data.materials.append(ink.material('enamel_cream'))
    target = Vector((0, 0, -.01))
    bpy.ops.object.camera_add(location=(2.2, 2.8, 1.65))
    camera = bpy.context.object
    camera.rotation_euler = (target - camera.location).to_track_quat('-Z', 'Y').to_euler()
    camera.data.type = 'ORTHO'; camera.data.ortho_scale = 1.8
    scene = bpy.context.scene; scene.camera = camera
    for position, energy in [((1, 1, 4), 450), ((-2, -1, 2), 250)]:
        bpy.ops.object.light_add(type='AREA', location=position)
        lamp = bpy.context.object; lamp.data.energy = energy; lamp.data.size = 3
        lamp.rotation_euler = (target - lamp.location).to_track_quat('-Z', 'Y').to_euler()
    scene.render.engine = 'CYCLES'; scene.cycles.samples = 16
    scene.render.threads_mode = 'FIXED'; scene.render.threads = 3
    scene.render.resolution_x = 960; scene.render.resolution_y = 700; scene.render.resolution_percentage = 100
    scene.render.filepath = str(OUT / 'blender-carbine-action.png')
    bpy.ops.render.render(write_still=True)
(OUT / 'blender-sources.json').write_text(json.dumps(records, indent=2) + '\n')
