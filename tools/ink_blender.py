"""Shared INK v1 industrial authoring contract. Import from Blender generators.
Color factors are explicitly linear sRGB, as required by Principled/glTF.
Source geometry stays editable; export joining never crosses an animation parent.
"""
from pathlib import Path
import json
import bpy

ROOT = Path(__file__).resolve().parents[1]
PRESET = json.loads((ROOT / '우주-비즈니스/data/ink_materials.json').read_text())

def material(role):
    spec = PRESET['roles'][role]
    name = 'INK::' + role
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = (*spec['color_linear'], 1)
    bsdf = mat.node_tree.nodes['Principled BSDF']
    bsdf.inputs['Base Color'].default_value = mat.diffuse_color
    bsdf.inputs['Metallic'].default_value = spec['metallic']
    bsdf.inputs['Roughness'].default_value = spec['roughness']
    mat['ink_role'] = role
    return mat

def manufactured_edges(obj, width, segments=4):
    """Smooth bevels with area-weighted faces, after applying the object's scale."""
    for face in obj.data.polygons:
        face.use_smooth = True
    if width:
        mod = obj.modifiers.new('INK manufactured radius', 'BEVEL')
        mod.width = width
        mod.segments = segments
        obj.modifiers.new('INK weighted face normals', 'WEIGHTED_NORMAL')
    return obj

def consolidate_static_surfaces():
    """Call AFTER saving .blend. Preserve all pivots, sockets and transparent panes."""
    groups = {}
    for obj in list(bpy.context.scene.objects):
        if obj.type != 'MESH' or obj.name.startswith(('Anim_', 'Socket_')) or obj.children:
            continue
        if obj.animation_data or obj.data.shape_keys:
            continue
        mats = list(obj.data.materials)
        if not mats or any(m is None or m.diffuse_color[3] < 1 for m in mats):
            continue
        bpy.context.view_layer.objects.active = obj
        for mod in list(obj.modifiers):
            bpy.ops.object.modifier_apply(modifier=mod.name)
        key = (obj.parent, tuple(mats))
        groups.setdefault(key, []).append(obj)
    for objects in groups.values():
        bpy.ops.object.select_all(action='DESELECT')
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        if len(objects) > 1:
            bpy.ops.object.join()
        # Rotated merged bounds inflate equipment previews. Bake mesh rotation only;
        # parent pivots/translation and the visible world-space geometry stay intact.
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return sum(o.type == 'MESH' for o in bpy.context.scene.objects)
