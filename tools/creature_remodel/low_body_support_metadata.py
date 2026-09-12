"""Terrain clearance for the existing low radial/mantle pad-leg anatomy.

Only runtime pose metadata changes. Oral support samples come from the exported
skin, so its mouth keeps its own anatomy and animation rather than a guessed box.
"""
import atexit
import json
import os
import struct
from pathlib import Path
from lod_animation import read, accessor_bytes

ROOT = Path(__file__).resolve().parents[2]
CACHE = ROOT/'output/creature-remodel/production/low-body-support-cache.json'
_cache = json.loads(CACHE.read_text()) if CACHE.exists() else {}
_dirty = False

def flush():
    global _dirty
    if not _dirty:
        return
    CACHE.parent.mkdir(parents=True, exist_ok=True)
    temporary = CACHE.with_suffix(f'.{os.getpid()}.tmp')
    temporary.write_text(json.dumps(_cache, separators=(',', ':')))
    os.replace(temporary, CACHE)
    _dirty=False

atexit.register(flush)

def patch(row):
    global _dirty
    if row.get('construction') not in ['mantle', 'flat', 'radial']:
        return
    # The explicit knee capsule has a 0.14 m maximum radius.
    row['motion_profile'].update(knee_clearance=.16, knee_radius=.14)
    row['body_support_version'] = 2
    key = row['lods']['near']['sha256']
    if key not in _cache:
        data, binary = read(ROOT/row['lods']['near']['path'])
        names = [data['nodes'][i]['name'] for i in data['skins'][0]['joints']]
        points = {}
        for mesh in data['meshes']:
            for primitive in mesh['primitives']:
                attrs = primitive['attributes']
                if 'JOINTS_0' not in attrs:
                    continue
                component = data['accessors'][attrs['JOINTS_0']]['componentType']
                joints = struct.iter_unpack('<4'+{5121:'B',5123:'H'}[component], accessor_bytes(data,binary,attrs['JOINTS_0']))
                weights = struct.iter_unpack('<4f',accessor_bytes(data,binary,attrs['WEIGHTS_0']))
                vertices = struct.iter_unpack('<3f',accessor_bytes(data,binary,attrs['POSITION']))
                for vertex, indices, values in zip(vertices,joints,weights):
                    slot=max(range(4),key=lambda i:values[i]);name=names[indices[slot]]
                    if name.startswith('ventral_oral') and values[slot]>.999:
                        points.setdefault(name,[]).append(vertex)
        supports=[]
        for bone,vertices in sorted(points.items()):
            # Lower hull corners retain lateral extent on uneven terrain.
            bottom=min(p[1] for p in vertices)
            lower=[p for p in vertices if p[1]<=bottom+.035]
            selected={min(vertices,key=lambda p:p[1])}
            for axis in [0,2]:
                selected.update([min(lower,key=lambda p:p[axis]),max(lower,key=lambda p:p[axis])])
            supports.extend({'bone':bone,'owner':'head','point':list(p)} for p in sorted(selected))
        _cache[key]=supports;_dirty=True
    if _cache[key]:
        row['motion_profile']['body_supports']=_cache[key]
