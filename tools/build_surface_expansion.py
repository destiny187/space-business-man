"""Eighteen authored geological height fields; Blender sources and Cycles review.

Linear RGBA = tangent normal XY / unlit height-tone / roughness. Periodic fields
share the same height source with the editable preview geometry. No photo assets.
Run with Blender --background --python tools/build_surface_expansion.py.
"""
from pathlib import Path
import hashlib
import json
import math
import sys

import bpy
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import ink_blender as INK

OUT = ROOT / '우주-비즈니스/assets/textures/surfaces'
SOURCE = ROOT / 'art/blender/surface-materials'
REVIEW = ROOT / 'docs/production/media/surface-expansion'
for folder in (OUT, SOURCE, REVIEW):
    folder.mkdir(parents=True, exist_ok=True)
N = 1024
u, v = np.meshgrid((np.arange(N) + .5) / N, (np.arange(N) + .5) / N)
TAU = math.tau

# Names describe different structures, not palette or random-seed duplicates.
SPECS = [
    ('dune_crossbeds', '사층리 모래', 'b89a70', .94, .12, 6.2),
    ('wind_ripple_sand', '끊어진 풍성 사문', 'c5ad80', .96, .06, 3.8),
    ('desert_pavement', '사막 포석', '947c68', .92, .17, 4.2),
    ('eroded_clay', '침식 점토 홈', 'b18972', .97, .10, 5.5),
    ('scoured_sandstone', '풍식 사암 선반', 'aa805d', .92, .20, 7.4),
    ('flint_shingle', '편평한 부싯돌', '8e8274', .85, .15, 3.6),
    ('granite_plates', '화강암 박리판', '929b9b', .89, .24, 7.0),
    ('schist_ridges', '편암 엽리', '78868b', .84, .17, 5.8),
    ('vesicular_basalt', '기공 현무암', '696b70', .96, .18, 5.0),
    ('pebble_conglomerate', '역암 노출면', '9d9181', .90, .20, 5.6),
    ('shale_chips', '박편 셰일', '8c8a87', .94, .12, 3.4),
    ('mineral_veins', '맥상 암반', '8d9898', .82, .15, 6.8),
    ('glacier_foliation', '압축 빙하층', '91b1bc', .37, .15, 8.2),
    ('blue_ice_bubbles', '기포 노출 얼음', '85afbf', .25, .07, 5.6),
    ('frost_heave', '동결 융기토', 'a2a69e', .90, .18, 5.4),
    ('snow_sastrugi', '바람 침식 설릉', 'cbd4d4', .84, .12, 7.2),
    ('firn_granules', '굳은 입상설', 'c1d0d4', .73, .06, 3.2),
    ('ice_shards', '포개진 얼음편', '9ab9c2', .45, .17, 4.8),
]


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def field(seed, octaves=4):
    rng = np.random.default_rng(seed)
    value = np.zeros((N, N))
    for octave in range(octaves):
        for _ in range(6):
            fx = int(rng.integers(1, 4)) * 2 ** octave
            fy = int(rng.integers(-3, 4)) * 2 ** octave
            value += np.sin((u * fx + v * fy) * TAU + rng.uniform(0, TAU)) * .52 ** octave / 6
    return .5 + value * .5


def cells(seed, count, aspect=1.0):
    rng = np.random.default_rng(seed)
    first = np.full((N, N), 9.0)
    second = first.copy()
    for x, y in rng.random((count, 2)):
        dx = (u - x + .5) % 1 - .5
        dy = (v - y + .5) % 1 - .5
        angle = rng.uniform(-.5, .5)
        ratio = aspect * rng.uniform(.7, 1.3)
        rx = (dx * math.cos(angle) + dy * math.sin(angle)) / ratio
        ry = (-dx * math.sin(angle) + dy * math.cos(angle)) * ratio
        distance = np.sqrt(rx * rx + ry * ry) / rng.uniform(.75, 1.25)
        second = np.minimum(second, np.maximum(first, distance))
        first = np.minimum(first, distance)
    return first, second - first


def height_field(name, index):
    f = field(6101 + index)
    fine = field(8103 + index, 5)
    counts = {'desert_pavement': 30, 'flint_shingle': 37, 'granite_plates': 12,
              'pebble_conglomerate': 45, 'shale_chips': 68, 'firn_granules': 170,
              'ice_shards': 26, 'blue_ice_bubbles': 60, 'vesicular_basalt': 90}
    aspect = 2.4 if name in ('flint_shingle', 'shale_chips', 'ice_shards') else 1.0
    dist, edge = cells(7109 + index, counts.get(name, 24), aspect)
    joint = 1 - smooth(.002, .012, edge)
    if name == 'dune_crossbeds':
        ridge = np.sin((u * 3 + v * 5) * TAU + np.sin(v * TAU) * 2.7 + f * 6)
        cross = np.sin((u * 9 - v * 4) * TAU + f * 5)
        h = .26 + smooth(-.7, .9, ridge) * .28 + smooth(.48, .63, f) * cross * .065 + f * .14
    elif name == 'wind_ripple_sand':
        ripple = np.sin((v * 17 + u * 2) * TAU + np.sin(u * TAU * 3) * 1.5 + f * 8)
        h = .32 + f * .24 + smooth(-.5, .8, ripple) * smooth(.32, .60, f) * .13
    elif name == 'desert_pavement':
        h = .30 + smooth(.005, .045, edge) * .29 + f * .12 - joint * .06
    elif name == 'eroded_clay':
        channels = abs(np.sin((v * 5 + u) * TAU + np.sin(u * TAU * 2) * 1.9 + f * 4))
        h = .42 + f * .20 - (1 - smooth(.035, .48, channels)) * .26 + fine * .025
    elif name == 'scoured_sandstone':
        strata = (v * 4 + np.sin(u * TAU * 2) * .13 + f * .45) % 1
        h = .28 + smooth(.10, .90, strata) * .37 + f * .10 - joint * .025
    elif name == 'flint_shingle':
        h = .29 + smooth(.005, .040, edge) * .22 + np.clip(1 - dist / .12, 0, 1) * .16 + fine * .025
    elif name == 'granite_plates':
        h = .24 + smooth(.004, .022, edge) * .29 + smooth(.46, .68, f) * .19 + fine * .055
    elif name == 'schist_ridges':
        folia = np.sin((u * 9 + v * 2) * TAU + np.sin(v * TAU) * 3 + f * 3)
        h = .28 + smooth(-.5, .9, folia) * .26 + f * .17 - joint * .04
    elif name == 'vesicular_basalt':
        h = .48 + f * .12 - (1 - smooth(.008, .034, dist)) * .32 - joint * .025 + fine * .04
    elif name == 'pebble_conglomerate':
        h = .28 + np.sqrt(np.clip(1 - (dist / .060) ** 2, 0, 1)) * .34 + f * .09 + fine * .025
    elif name == 'shale_chips':
        h = .27 + smooth(.002, .018, edge) * .20 + np.clip(1 - dist / .055, 0, 1) * .19 - joint * .035
    elif name == 'mineral_veins':
        vein = abs(np.sin((u * 2 - v * 3) * TAU + np.sin(u * TAU) * 2.3 + f * 5))
        h = .30 + f * .23 + (1 - smooth(.07, .34, vein)) * .24 - joint * .06
    elif name == 'glacier_foliation':
        bands = np.sin((v * 6 + u) * TAU + np.sin(u * TAU) * 2 + f * 6)
        h = .32 + smooth(-.8, .6, bands) * .22 + f * .12 - joint * .075
    elif name == 'blue_ice_bubbles':
        bubble = (1 - smooth(.002, .019, dist))
        rim = smooth(.010, .017, dist) * (1 - smooth(.017, .025, dist))
        h = .40 + f * .18 - bubble * .22 + rim * .055
    elif name == 'frost_heave':
        h = .30 + smooth(.008, .024, edge) * (1 - smooth(.024, .055, edge)) * .25 + f * .24 - joint * .06
    elif name == 'snow_sastrugi':
        drift = (v * 5 + np.sin(u * TAU) * .4 + f * .65) % 1
        h = .30 + smooth(.08, .82, drift) * .26 * smooth(.25, .65, f) + f * .17
    elif name == 'firn_granules':
        h = .32 + np.sqrt(np.clip(1 - (dist / .021) ** 2, 0, 1)) * .17 + f * .19 + fine * .035
    else:  # Interlocking, flat elongated plates; not rounded snow granules.
        h = .27 + smooth(.003, .015, edge) * .25 + np.clip(1 - dist / .10, 0, 1) * .15 - joint * .08
    return np.clip(h, .08, .92), f


def linear(hex_value):
    def channel(value):
        return value / 12.92 if value <= .04045 else ((value + .055) / 1.055) ** 2.4
    return tuple(channel(int(hex_value[i:i+2], 16) / 255) for i in (0, 2, 4))


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.unit_settings.system = 'METRIC'
records = []
for index, (name, label, tint, roughness, amplitude, meters) in enumerate(SPECS):
    height, f = height_field(name, index)
    dx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * N / (2 * meters) * amplitude
    dy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * N / (2 * meters) * amplitude
    normal = np.stack([-dx, -dy, np.ones_like(height)], axis=-1)
    normal /= np.linalg.norm(normal, axis=-1)[..., None]
    rgba = np.stack([normal[..., 0] * .5 + .5, normal[..., 1] * .5 + .5,
                     height, np.clip(roughness + (f - .5) * .15, .15, 1)], axis=-1).astype(np.float32)
    image = bpy.data.images.new(name, width=N, height=N, alpha=True)
    image.colorspace_settings.name = 'Non-Color'
    image.pixels.foreach_set(rgba.ravel())
    image.filepath_raw = str(OUT / (name + '.png'))
    image.file_format = 'PNG'
    image.save()
    image.pack()
    material = bpy.data.materials.new('Surface::' + name)
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    bs = nodes.get('Principled BSDF')
    tex = nodes.new('ShaderNodeTexImage'); tex.image = image; tex.extension = 'REPEAT'
    separate = nodes.new('ShaderNodeSeparateColor'); links.new(tex.outputs['Color'], separate.inputs[0])
    ramp = nodes.new('ShaderNodeValToRGB')
    color = linear(tint)
    ramp.color_ramp.elements[0].color = (*(c * .60 for c in color), 1)
    ramp.color_ramp.elements[1].color = (*(c * 1.25 for c in color), 1)
    links.new(separate.outputs['Blue'], ramp.inputs[0]); links.new(ramp.outputs[0], bs.inputs['Base Color'])
    links.new(tex.outputs['Alpha'], bs.inputs['Roughness'])
    bump = nodes.new('ShaderNodeBump'); bump.inputs['Strength'].default_value = .42
    bump.inputs['Distance'].default_value = amplitude
    links.new(separate.outputs['Blue'], bump.inputs['Height']); links.new(bump.outputs[0], bs.inputs['Normal'])
    bpy.ops.mesh.primitive_grid_add(x_subdivisions=129, y_subdivisions=129, size=2,
                                   location=((index % 6 - 2.5) * 2.35, (1 - index // 6) * 2.5, 0))
    obj = bpy.context.object; obj.name = 'Editable_' + name
    for vertex in obj.data.vertices:
        ix = int((vertex.co.x + 1) * .5 * N) % N
        iy = int((vertex.co.y + 1) * .5 * N) % N
        vertex.co.z = (float(height[iy, ix]) - .5) * amplitude * 2
    obj.data.materials.append(material)
    for face in obj.data.polygons: face.use_smooth = True
    records.append({'id': name, 'name': label, 'texture': str((OUT / (name + '.png')).relative_to(ROOT)),
                    'meters': meters, 'height_amplitude_m': amplitude, 'tint_srgb': tint,
                    'sha256': hashlib.sha256((OUT / (name + '.png')).read_bytes()).hexdigest()})
    print('SURFACE_AUTHORED', name, flush=True)

bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -.12))
bpy.context.object.data.materials.append(INK.material('structural_dark'))
bpy.ops.object.camera_add(location=(0, -8, 16))
camera = bpy.context.object
camera.rotation_euler = (Vector((0, 0, 0)) - camera.location).to_track_quat('-Z', 'Y').to_euler()
camera.data.type = 'ORTHO'; camera.data.ortho_scale = 15.5
scene = bpy.context.scene; scene.camera = camera
bpy.ops.object.light_add(type='AREA', location=(-5, -4, 9))
bpy.context.object.data.energy = 2600; bpy.context.object.data.size = 6
scene.world = bpy.data.worlds.new('Surface expansion studio'); scene.world.color = (.19, .21, .24)
scene.render.engine = 'CYCLES'; scene.cycles.samples = 24
scene.render.resolution_x = 1800; scene.render.resolution_y = 1100; scene.render.resolution_percentage = 100
scene.render.filepath = str(REVIEW / 'blender-materials.png')
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / 'surface-expansion.blend'))
(SOURCE / 'surface-expansion.json').write_text(json.dumps({
    'version': 1, 'blender': bpy.app.version_string, 'resolution': N,
    'channels': 'linear normal XY / height-tone / roughness',
    'periodic': 'integer Fourier fields and toroidal cells; same source for normal and height',
    'materials': records}, ensure_ascii=False, indent=2) + '\n')
bpy.ops.render.render(write_still=True)
print('SURFACE_EXPANSION_COMPLETE', len(records), flush=True)
