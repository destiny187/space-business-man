"""Blender source and seamless packed basalt relief, without baked lighting.
Run with Blender --background --python tools/build_volcanic_surface.py.
The existing ten-layer Godot array keeps its resolution and channel contract.
"""
from pathlib import Path
import bpy, sys, json, math, hashlib
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import ink_blender as INK
OUT = ROOT / '우주-비즈니스/assets/textures/surfaces/lava_crust.png'
SRC = ROOT / 'art/blender/surface-materials/volcanic-crust.blend'
PIC = ROOT / 'docs/production/media/volcanic-surface/blender-crust.png'
for path in [OUT, SRC, PIC]: path.parent.mkdir(parents=True, exist_ok=True)
N = 1024
u, v = np.meshgrid((np.arange(N) + .5) / N, (np.arange(N) + .5) / N)

def smooth(lo, hi, value):
    t = np.clip((value - lo) / (hi - lo), 0, 1)
    return t * t * (3 - 2 * t)

def field(seed, octaves=4):
    rng = np.random.default_rng(seed)
    value = np.zeros_like(u)
    for octave in range(octaves):
        for _ in range(4):
            fx = int(rng.integers(1, 4)) * 2**octave
            fy = int(rng.integers(-3, 4)) * 2**octave
            value += np.sin((u * fx + v * fy) * math.tau + rng.uniform(0, math.tau)) * .5**octave / 4
    return value

# Periodic distortion and wrapped, jittered cell sites avoid straight hexagons.
x = (u + .026 * np.sin(v * math.tau * 3) + .018 * field(771, 3)) % 1
y = (v + .025 * np.sin((u + v) * math.tau * 2) + .018 * field(883, 3)) % 1
rng = np.random.default_rng(71503)
first = np.full_like(u, 9.0)
second = first.copy()
plate_tone = np.zeros_like(u)
for row in range(4):
    for col in range(5):
        px, py = ((col + rng.uniform(.1, .9)) / 5, (row + rng.uniform(.1, .9)) / 4)
        dx, dy = abs(x - px), abs(y - py)
        dx, dy = np.minimum(dx, 1 - dx), np.minimum(dy, 1 - dy)
        distance = np.sqrt(dx * dx + dy * dy)
        plate_tone = np.where(distance < first, rng.uniform(-.045, .045), plate_tone)
        second = np.minimum(second, np.maximum(first, distance))
        first = np.minimum(first, distance)
edge = second - first
crust = smooth(.002, .024, edge)
grain = field(691, 6)
fold = np.sin((u * 9 + v * 3) * math.tau + field(422, 3) * 4)
rim = smooth(.006, .019, edge) * (1 - smooth(.019, .034, edge))
height = .28 + crust * (.24 + plate_tone + grain * .055 + fold * .028) + rim * .065
# Glossy fissure floor and dry crust also encode heat coverage in the same fetch.
fissure_floor = .20 + .34 * smooth(-.12, .15, field(177, 2))
roughness = fissure_floor + (.94 - fissure_floor) * smooth(.0015, .017, edge)
dx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * N / 8 * .085
dy = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * N / 8 * .085
normal = np.stack([-dx, -dy, np.ones_like(height)], axis=-1)
normal /= np.linalg.norm(normal, axis=-1)[..., None]
rgba = np.stack([normal[..., 0] * .5 + .5, normal[..., 1] * .5 + .5, height, roughness], axis=-1).astype(np.float32)
bpy.ops.wm.read_factory_settings(use_empty=True)
image = bpy.data.images.new('Basalt::normal_xy_height_roughness', width=N, height=N, alpha=True)
image.colorspace_settings.name = 'Non-Color'
image.pixels.foreach_set(rgba.ravel())
image.filepath_raw = str(OUT)
image.file_format = 'PNG'
image.save()
image.pack()

def material(hot):
    mat = bpy.data.materials.new('Volcanic::' + ('hot' if hot else 'cooled'))
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bs = nodes.get('Principled BSDF')
    tex = nodes.new('ShaderNodeTexImage'); tex.image = image; tex.extension = 'REPEAT'
    sep = nodes.new('ShaderNodeSeparateColor'); links.new(tex.outputs['Color'], sep.inputs[0])
    ramp = nodes.new('ShaderNodeValToRGB')
    palette = [(.20, (1, .27, .008)), (.38, (.55, .05, .002)), (.68, (.065, .012, .008)), (.86, (.030, .037, .045)), (.94, (.085, .090, .099))] if hot else [(.20, (.014, .018, .024)), (.94, (.085, .090, .099))]
    for i, (position, color) in enumerate(palette):
        element = ramp.color_ramp.elements[i] if i < 2 else ramp.color_ramp.elements.new(position)
        element.position = position; element.color = (*color, 1)
    links.new(tex.outputs['Alpha'], ramp.inputs[0]); links.new(ramp.outputs[0], bs.inputs['Base Color'])
    if hot:
        links.new(tex.outputs['Alpha'], bs.inputs['Roughness'])
        heat = nodes.new('ShaderNodeMapRange'); heat.clamp = True
        heat.inputs['From Min'].default_value = .70; heat.inputs['From Max'].default_value = .25
        heat.inputs['To Min'].default_value = 0; heat.inputs['To Max'].default_value = 1.6
        links.new(tex.outputs['Alpha'], heat.inputs['Value']); links.new(heat.outputs['Result'], bs.inputs['Emission Strength']); links.new(ramp.outputs[0], bs.inputs['Emission Color'])
    else: bs.inputs['Roughness'].default_value = .94
    bump = nodes.new('ShaderNodeBump'); bump.inputs['Strength'].default_value = .42; bump.inputs['Distance'].default_value = .085
    links.new(sep.outputs['Blue'], bump.inputs['Height']); links.new(bump.outputs[0], bs.inputs['Normal'])
    return mat

for hot in [False, True]:
    bpy.ops.mesh.primitive_grid_add(x_subdivisions=193, y_subdivisions=193, size=4, location=(2.2 if hot else -2.2, 0, 0))
    obj = bpy.context.object; obj.name = 'Editable_hot_crust' if hot else 'Editable_cooled_crust'
    for vertex in obj.data.vertices:
        ix = int((vertex.co.x / 4 + .5) * N) % N; iy = int((vertex.co.y / 4 + .5) * N) % N
        vertex.co.z = (float(height[iy, ix]) - .5) * .2
    obj.data.materials.append(material(hot))
    for polygon in obj.data.polygons: polygon.use_smooth = True
bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -.15)); bpy.context.object.data.materials.append(INK.material('structural_dark'))
bpy.ops.object.camera_add(location=(0, -7.5, 9.5)); camera = bpy.context.object
camera.rotation_euler = (Vector((0, 0, 0)) - camera.location).to_track_quat('-Z', 'Y').to_euler(); camera.data.type = 'ORTHO'; camera.data.ortho_scale = 10.2
scene = bpy.context.scene; scene.camera = camera
bpy.ops.object.light_add(type='AREA', location=(-3, -4, 8)); bpy.context.object.data.energy = 1300; bpy.context.object.data.size = 5
scene.world = bpy.data.worlds.new('Crust review'); scene.world.color = (.12, .14, .18)
scene.render.engine = 'CYCLES'; scene.cycles.samples = 24
scene.render.resolution_x = 1400; scene.render.resolution_y = 850; scene.render.resolution_percentage = 100; scene.render.filepath = str(PIC)
bpy.ops.wm.save_as_mainfile(filepath=str(SRC)); bpy.ops.render.render(write_still=True)
SRC.with_suffix('.json').write_text(json.dumps({'version': 1, 'blender': bpy.app.version_string, 'seed': 71503, 'resolution': N, 'tile_meters': 4, 'plates_per_tile': 20, 'channels': 'linear normal XY / height / roughness; low roughness marks fissure floor', 'lighting_baked': False, 'texture': str(OUT.relative_to(ROOT)), 'sha256': hashlib.sha256(OUT.read_bytes()).hexdigest(), 'seamless': 'periodic Fourier distortion and wrapped Voronoi', 'preview_only_displacement': True}, ensure_ascii=False, indent=2) + '\n')
print('VOLCANIC_SURFACE_COMPLETE', flush=True)
