"""INK manufacturer plates from the same compact SVG masters used by the HUD.

Blender authoring helper; run directly to update the four existing editable sources.
Only corporate geometry is replaced. Motion parents and all other objects persist.
"""
from pathlib import Path
import json
import math
import re
import sys
import struct
import xml.etree.ElementTree as ET
import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import ink_blender as ink

ASSETS = {
    'heron': ('lotus/heron', 'LOTUS_HERON'),
    'supply_crate': ('lotus/supply_crate', 'LOTUS_SupplyCrate'),
    'miner': ('miner', None),
    'robot': ('incidents/robot', 'Anim_Torso'),
}


def contours(path):
    """Tessellate the absolute M/L/H/V/C/Q/Z subset of our own vector masters."""
    tokens = re.findall(r'[A-Za-z]|[-+]?(?:\d*\.\d+|\d+)', path)
    i = 0
    current = Vector((0, 0))
    points = []
    result = []
    while i < len(tokens):
        command = tokens[i]; i += 1
        count = {'M': 2, 'L': 2, 'H': 1, 'V': 1, 'C': 6, 'Q': 4, 'Z': 0}[command]
        values = list(map(float, tokens[i:i + count])); i += count
        if command == 'Z':
            result.append(points); points = []; continue
        if command in ('M', 'L'):
            current = Vector(values); points.append(current.copy())
        elif command == 'H':
            current.x = values[0]; points.append(current.copy())
        elif command == 'V':
            current.y = values[0]; points.append(current.copy())
        else:
            start = current.copy()
            a, b = Vector(values[:2]), Vector(values[2:4])
            end = Vector(values[4:]) if command == 'C' else b
            for sample in range(1, 17):
                t = sample / 16; u = 1 - t
                points.append(start*u**3 + a*3*u*u*t + b*3*u*t*t + end*t**3 if command == 'C'
                              else start*u*u + a*2*u*t + end*t*t)
            current = end
    if points:
        result.append(points)
    return result


def mount(name, company, at, right, up, size, parent=None, plate=True, role='edge_steel'):
    normal = Vector(right).cross(Vector(up))
    basis = Matrix((Vector(right), Vector(up), normal)).transposed().to_4x4()
    basis.translation = Vector(at)
    if plate:
        bpy.ops.mesh.primitive_cube_add(size=1)
        obj = bpy.context.object; obj.name = 'Corporate_' + name + '_plate'
        obj.matrix_world = basis
        obj.scale = (size*1.14, size*1.14, .026)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        obj.data.materials.append(ink.material('structural_dark'))
        ink.manufactured_edges(obj, .018, 3)
        if parent:
            world = obj.matrix_world.copy(); obj.parent = parent; obj.matrix_world = world
    root = ET.parse(ROOT / 'art/branding/corporations' / (company + '.svg')).getroot()
    group = root.find('{*}g[@id="compact"]')
    curve = bpy.data.curves.new('Corporate_' + name, 'CURVE')
    curve.dimensions = '2D'; curve.fill_mode = 'BOTH'; curve.extrude = .001
    for path in group.findall('{*}path'):
        for points in contours(path.attrib['d']):
            spline = curve.splines.new('POLY'); spline.points.add(len(points)-1)
            for vert, point in zip(spline.points, points):
                vert.co = ((point.x-128)/256*size, (128-point.y)/256*size, 0, 1)
            spline.use_cyclic_u = True
    obj = bpy.data.objects.new('Corporate_' + name + '_mark', curve)
    bpy.context.collection.objects.link(obj)
    obj.matrix_world = basis; obj.location += normal * (.015 if plate else .004)
    curve.materials.append(ink.material(role))
    bpy.ops.object.select_all(action='DESELECT'); obj.select_set(True); bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target='MESH')
    obj = bpy.context.object
    if parent:
        world = obj.matrix_world.copy(); obj.parent = parent; obj.matrix_world = world


def apply(asset):
    if asset not in ASSETS:
        return
    for obj in list(bpy.context.scene.objects):
        if obj.name.startswith('Corporate_') or (asset in ('heron', 'supply_crate') and obj.name.startswith('Lotus petal')):
            bpy.data.objects.remove(obj, do_unlink=True)
    parent = bpy.data.objects.get(ASSETS[asset][1]) if ASSETS[asset][1] else None
    if asset == 'heron':
        mount('Lotus_operator_top', 'lotus', (0, .65, 3.84), (1, 0, 0), (0, 1, 0), 1.3, parent, False, 'safety_orange')
        for side in (-1, 1):
            mount('Lotus_operator_' + str(side), 'lotus', (side*1.164, .60, 3.42), (0, side, 0), (0, 0, 1), .63, parent, False, 'safety_orange')
    elif asset == 'supply_crate':
        mount('Lotus_operator', 'lotus', (0, .756, .79), (-1, 0, 0), (0, 0, 1), .46, parent, False, 'safety_orange')
    elif asset == 'miner':
        mount('mine_manufacturer', 'mine', (.28, -.844, 1.13), (1, 0, 0), (0, 0, 1), .35, parent)
        mount('mine_rear_manufacturer', 'mine', (0, 1.269, 1.16), (-1, 0, 0), (0, 0, 1), .25, parent, False, 'structural_dark')
    elif asset == 'robot':
        old = bpy.data.objects.get('Serial plaque')
        if old:
            bpy.data.objects.remove(old, do_unlink=True)
        mount('CooperTech_manufacturer', 'coopertech', (-.47, -.531, 2.08), (1, 0, 0), (0, 0, 1), .32, parent)


def review(asset, output):
    center = Vector((0, 0, 2.5 if asset == 'heron' else .7 if asset == 'supply_crate' else 1.3))
    size = 10 if asset == 'heron' else 3.4 if asset == 'supply_crate' else 4.5
    direction = Vector((1.2, 1.8 if asset in ('heron', 'supply_crate') else -2.1, 1.0))
    bpy.ops.object.camera_add(location=center + direction*size)
    cam = bpy.context.object; cam.rotation_euler = (center-cam.location).to_track_quat('-Z', 'Y').to_euler()
    cam.data.type = 'ORTHO'; cam.data.ortho_scale = size; bpy.context.scene.camera = cam
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -.025))
    bpy.context.object.data.materials.append(ink.material('structural_dark'))
    for loc, energy in [((3,-4,7),1500),((-4,5,6),1800)]:
        bpy.ops.object.light_add(type='AREA', location=loc)
        light=bpy.context.object; light.data.energy=energy; light.data.size=6
        light.rotation_euler=(center-light.location).to_track_quat('-Z','Y').to_euler()
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=16
    scene.render.resolution_x=1000;scene.render.resolution_y=850;scene.render.resolution_percentage=100
    scene.render.filepath=str(output / (asset+'-blender.png'));bpy.ops.render.render(write_still=True)


if __name__ == '__main__':
    output=ROOT/'docs/production/media/corporate-presence';output.mkdir(parents=True,exist_ok=True)
    report_path=ROOT/'art/blender/corporate-marks.json'
    report=json.loads(report_path.read_text()) if report_path.exists() else {}
    requested=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else list(ASSETS)
    for asset in requested:
        path,_=ASSETS[asset]
        source=ROOT/'art/blender'/(path+'.blend')
        bpy.ops.wm.open_mainfile(filepath=str(source))
        pivots={o.name:[list(v) for v in o.matrix_world] for o in bpy.context.scene.objects if o.name.startswith(('Anim_','Socket_','ToolRotor'))}
        apply(asset);bpy.context.view_layer.update()
        assert all(pivots[o.name]==[list(v) for v in o.matrix_world] for o in bpy.context.scene.objects if o.name in pivots)
        bpy.ops.wm.save_as_mainfile(filepath=str(source))
        ink.consolidate_static_surfaces()
        target=ROOT/'우주-비즈니스/assets/models'/(path+'.glb')
        bpy.ops.export_scene.gltf(filepath=str(target),export_format='GLB',export_apply=True,export_cameras=False,export_lights=False)
        report[asset]={'source':str(source.relative_to(ROOT)),'model':str(target.relative_to(ROOT)),'preserved_pivots':list(pivots)}
        blob=target.read_bytes();length=struct.unpack_from('<I',blob,12)[0];gltf=json.loads(blob[20:20+length])
        report[asset].update(mesh_instances=sum('mesh' in node for node in gltf['nodes']),
                             triangles=sum(gltf['accessors'][primitive['indices']]['count']//3 for node in gltf['nodes'] if 'mesh' in node for primitive in gltf['meshes'][node['mesh']]['primitives']),
                             glb_bytes=len(blob))
        review(asset,output)
    report_path.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print('CORPORATE_MARKS_EXPORTED', flush=True)
