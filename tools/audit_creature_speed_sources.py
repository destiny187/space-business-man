"""Read and render the five current Blender sources; never save or export assets."""
import hashlib
import json
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'output/creature-speed-audit-20260913/blender'
WANTED = ['sailhorn', 'shearprowler', 'pressureurn', 'vaulthopper', 'reedserpent']


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    rows = {}
    for name in ['creature_remodel_r01.json', 'creature_remodel_combat.json']:
        for row in json.loads((ROOT / '우주-비즈니스/data' / name).read_text())['forms']:
            rows[row['id']] = row
    records = []
    for name in WANTED:
        row = rows[name]
        source = ROOT / row['source']
        before = hashlib.sha256(source.read_bytes()).hexdigest()
        bpy.ops.wm.open_mainfile(filepath=str(source))
        scene = bpy.context.scene
        arm = next(o for o in scene.objects if o.type == 'ARMATURE')
        for track in arm.animation_data.nla_tracks:
            track.mute = True
        meshes = [o for o in scene.objects if o.type == 'MESH']
        records.append(dict(id=name, source=row['source'], source_sha256=before,
                            bones=len(arm.data.bones), weighted_meshes=sum(bool(o.vertex_groups) for o in meshes),
                            actions=[a.name for a in bpy.data.actions]))
        arm.animation_data.action = bpy.data.actions['idle_loop']
        scene.frame_set(1)
        bpy.context.view_layer.update()
        points = [o.matrix_world @ Vector(p) for o in meshes for p in o.bound_box]
        lo = Vector([min(p[i] for p in points) for i in range(3)])
        hi = Vector([max(p[i] for p in points) for i in range(3)])
        center, size = (lo + hi) * .5, max(hi - lo)
        bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -.03))
        bpy.ops.object.camera_add(location=center + Vector((1.3, -1.7, .9)).normalized() * size * 3)
        camera = bpy.context.object
        camera.rotation_euler = (center - camera.location).to_track_quat('-Z', 'Y').to_euler()
        camera.data.type, camera.data.ortho_scale = 'ORTHO', size * 1.45
        scene.camera = camera
        scene.world = bpy.data.worlds.new('AuditStudio')
        scene.world.use_nodes = True
        scene.world.node_tree.nodes['Background'].inputs[0].default_value = (.3, .34, .32, 1)
        for offset, energy in [((1, -2, 2), 140), ((-1, .5, 1), 75)]:
            bpy.ops.object.light_add(type='AREA', location=center + Vector(offset) * size)
            lamp = bpy.context.object
            lamp.data.energy, lamp.data.size = energy * size * size, size
            lamp.rotation_euler = (center - lamp.location).to_track_quat('-Z', 'Y').to_euler()
        scene.render.engine = 'CYCLES'
        scene.cycles.samples = 12
        scene.cycles.use_denoising = True
        scene.render.resolution_x, scene.render.resolution_y = 480, 400
        scene.render.resolution_percentage = 100
        for clip in ['move_loop', 'run_loop']:
            arm.animation_data.action = bpy.data.actions[clip]
            profile = row['motion_profile']
            period = profile['run']['period'] if clip == 'run_loop' else profile['period']
            scene.frame_set(1 + round(period * .3 * 30))
            scene.render.filepath = str(OUT / f'{name}-{clip}.png')
            bpy.ops.render.render(write_still=True)
        assert before == hashlib.sha256(source.read_bytes()).hexdigest()
        print('SPEED_SOURCE_AUDIT', name, flush=True)
    (OUT / 'evidence.json').write_text(json.dumps(records, ensure_ascii=False, indent=2) + '\n')


if __name__ == '__main__':
    main()
