"""Bind the existing contractile pads and mouth undersides to their axial skin.

These dimensions come from legacy_anatomy.classic's coil/slug construction.
They are visual support geometry, independent of movement or combat balance.
"""
import struct
from pathlib import Path
from lod_animation import read, accessor_bytes
from strike_metadata import inverse

ROOT=Path(__file__).resolve().parents[2]
_cache={}

def patch(row):
    if row.get('construction') not in ['coil','slug']:
        return
    key=row['lods']['near']['sha256']
    if key not in _cache:
        data,binary=read(ROOT/row['lods']['near']['path'])
        skin=data['skins'][0];raw=accessor_bytes(data,binary,skin['inverseBindMatrices'])
        supports=[]
        for index,node in enumerate(skin['joints']):
            name=data['nodes'][node]['name']
            if not name.startswith('peristaltic_axis'):
                continue
            values=struct.unpack_from('<16f',raw,index*64)
            bind=inverse([[values[c*4+r] for c in range(4)] for r in range(4)])
            point=[bind[r][3] for r in range(3)];point[1]-=.16+.055
            supports.append({'bone':name,'owner':name,'point':point})
        assert len(supports)>=9
        mouth=row['sockets']['Socket_Muzzle'];point=list(mouth['point'])
        point[1]-=.16 if row['construction']=='coil' else .11
        owner=row['skeleton_topology'][mouth['bone']]
        assert owner.startswith('peristaltic_axis')
        supports.append({'bone':mouth['bone'],'owner':owner,'point':point})
        _cache[key]=supports
    row['motion_profile']['body_supports']=_cache[key]
    row['body_support_version']=1
