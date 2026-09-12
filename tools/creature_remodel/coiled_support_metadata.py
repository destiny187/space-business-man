"""Visual terrain supports for articulated coils and low branched mouths."""
import itertools
import atexit
import json
import os
import struct
from pathlib import Path
from lod_animation import read, accessor_bytes
from strike_metadata import inverse

ROOT=Path(__file__).resolve().parents[2]
CACHE=ROOT/'output/creature-remodel/production/coiled-body-support-cache-v1.json'
_cache=json.loads(CACHE.read_text()) if CACHE.exists() else {}
_dirty=False

@atexit.register
def flush():
    global _dirty
    if not _dirty:return
    temporary=CACHE.with_suffix(f'.{os.getpid()}.tmp')
    temporary.write_text(json.dumps(_cache,separators=(',',':')))
    os.replace(temporary,CACHE);_dirty=False

def patch(row):
    global _dirty
    if row.get('construction') not in ['gyre_tower','spiral_maw','spiral_hinge','corkscrew_spine','braid_crawler','offset_halo','root_octant']:
        return
    key=row['lods']['near']['sha256']
    if key not in _cache:
        data,binary=read(ROOT/row['lods']['near']['path']);skin=data['skins'][0]
        names=[data['nodes'][i]['name'] for i in skin['joints']]
        raw=accessor_bytes(data,binary,skin['inverseBindMatrices']);points={}
        for i,name in enumerate(names):
            values=struct.unpack_from('<16f',raw,i*64)
            bind=inverse([[values[c*4+r] for c in range(4)] for r in range(4)])
            points[name]=[bind[r][3] for r in range(3)]
        graph=row['skeleton_topology'];supports=[]
        for name in names:
            if not name.startswith('coiled_organ'):continue
            supports.append({'bone':name,'owner':name,'point':points[name],'radius':.19})
            child=next((n for n,p in graph.items() if p==name and n.startswith('coiled_organ')),None)
            if child:
                supports.append({'bone':name,'owner':name,'point':[(a+b)*.5 for a,b in zip(points[name],points[child])],'radius':.19})
        mouths={}
        for mesh in data['meshes']:
            for primitive in mesh['primitives']:
                a=primitive['attributes']
                if 'JOINTS_0' not in a:continue
                component=data['accessors'][a['JOINTS_0']]['componentType']
                joints=struct.iter_unpack('<4'+{5121:'B',5123:'H'}[component],accessor_bytes(data,binary,a['JOINTS_0']))
                weights=struct.iter_unpack('<4f',accessor_bytes(data,binary,a['WEIGHTS_0']))
                vertices=struct.iter_unpack('<3f',accessor_bytes(data,binary,a['POSITION']))
                for vertex,indices,values in zip(vertices,joints,weights):
                    slot=max(range(4),key=lambda i:values[i]);name=names[indices[slot]]
                    if name.startswith(('coil_oral','terminal_oral')) and values[slot]>.999:mouths.setdefault(name,[]).append(vertex)
        for bone,vertices in mouths.items():
            owner=bone
            while not owner.startswith(('coiled_organ','fork_tip')):owner=graph[owner]
            bounds=[(min(p[i] for p in vertices),max(p[i] for p in vertices)) for i in range(3)]
            supports.extend({'bone':bone,'owner':owner,'point':list(p)} for p in itertools.product(*bounds))
        # Parent owners must be posed before descendant owners whose global pose is stored.
        def depth(name):return 0 if graph[name] is None else 1+depth(graph[name])
        supports.sort(key=lambda s:depth(s['owner']))
        _cache[key]=supports;_dirty=True
    row['motion_profile'].update(body_supports=_cache[key],body_supports_before_limbs=True,clearance_footprint=True,body_support_lift_ratio=.50,knee_clearance=.14,knee_radius=.12)
    row['body_support_version']=4
