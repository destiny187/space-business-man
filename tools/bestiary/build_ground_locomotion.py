"""Derive ground contact anchors from the existing Blender GLBs, without changing assets.
Run with Python + NumPy. Authored pivots, skin weights and sole geometry define each foot;
labels or ID hashes never choose a gait phase. Both LODs share the near model's contacts.
"""
import json
import struct
import hashlib
from pathlib import Path
import numpy as np
from verify_geometry import transform

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / '우주-비즈니스/data'
DTYPES = {5120: '<i1', 5121: '<u1', 5122: '<i2', 5123: '<u2', 5125: '<u4', 5126: '<f4'}
WIDTHS = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}


def contacts(form):
    raw = (ROOT / form['lods']['near']['path']).read_bytes()
    if raw[:4] != b'glTF':
        raise ValueError(f"Missing LFS asset: {form['id']}")
    size = struct.unpack_from('<I', raw, 12)[0]
    doc = json.loads(raw[20:20+size])
    binary = raw[28+size:]
    nodes = doc['nodes']
    parents = {c: i for i, n in enumerate(nodes) for c in n.get('children', [])}
    matrices = {}
    def matrix(i):
        if i not in matrices:
            local = np.array(transform(nodes[i]))
            matrices[i] = matrix(parents[i]) @ local if i in parents else local
        return matrices[i]
    def accessor(i):
        a = doc['accessors'][i]; v = doc['bufferViews'][a['bufferView']]
        dtype = np.dtype(DTYPES[a['componentType']]); width = WIDTHS[a['type']]
        result = np.ndarray((a['count'], width), dtype=dtype, buffer=binary,
            offset=v.get('byteOffset', 0)+a.get('byteOffset', 0),
            strides=(v.get('byteStride', width*dtype.itemsize), dtype.itemsize))
        if a.get('normalized') and a['componentType'] != 5126:
            return result.astype(float) / np.iinfo(dtype).max
        return result
    chains = {d['hip']: d for d in form.get('gait', {}).get('limbs', {}).values()}
    hips = {n['name']: i for i, n in enumerate(nodes)
            if n.get('name', '').startswith('Anim_Leg') or n.get('name', '') in chains}
    tips = {name: chains[name]['ankle'] if name in chains else name for name in hips}
    groups = {name: [] for name in hips}
    tip_to_hip = {tip: hip for hip, tip in tips.items()}
    for i, node in enumerate(nodes):
        if 'mesh' not in node:
            continue
        owner = i; rigid = None
        while owner in parents:
            owner = parents[owner]
            if nodes[owner].get('name') in tip_to_hip:
                rigid = tip_to_hip[nodes[owner]['name']]; break
        for p in doc['meshes'][node['mesh']]['primitives']:
            attributes = p['attributes']; points = accessor(attributes['POSITION'])
            world = points @ matrix(i)[:3, :3].T + matrix(i)[:3, 3]
            if rigid:
                groups[rigid].append(world)
            elif 'skin' in node and 'JOINTS_0' in attributes:
                skin = doc['skins'][node['skin']]
                joints = accessor(attributes['JOINTS_0']); weights = accessor(attributes['WEIGHTS_0'])
                for joint, bone in enumerate(skin['joints']):
                    name = nodes[bone].get('name', '').removeprefix('Rig_')
                    if name not in tip_to_hip:
                        continue
                    mask = ((joints == joint) & (weights > .5)).any(axis=1)
                    if mask.any(): groups[tip_to_hip[name]].append(world[mask])
    result = []
    for name, index in hips.items():
        if not groups[name]: raise ValueError(f"No weighted foot geometry: {form['id']} {name}")
        points = np.concatenate(groups[name])
        low = points[:, 1].min()
        sole = points[points[:, 1] <= low + max(.008, np.ptp(points[:, 1])*.025)].mean(axis=0)
        sole[1] = low
        tip_index = next(i for i, n in enumerate(nodes) if n.get('name') == tips[name])
        tip = np.linalg.solve(matrix(tip_index), np.append(sole, 1))[:3]
        result.append({'hip': name, 'tip': [round(float(x), 5) for x in tip],
                       'rest': [round(float(x), 5) for x in sole]})
    # Sort by physical front-to-back then left-to-right, including numeric radial leg labels.
    result.sort(key=lambda leg: (-leg['rest'][2], leg['rest'][0]))
    return result, hashlib.sha256(raw).hexdigest()


def kind(form, limbs):
    construction = form.get('construction', form['family'])
    if construction in ('macropod', 'lagomorph', 'anuran'): return 'hop'
    if not limbs:
        return 'slither' if construction in ('serpent', 'coil', 'ribbon', 'ribbon_colony', 'braid_crawler', 'corkscrew_spine') else 'crawl'
    if len(limbs) == 2: return 'biped'
    if construction in ('radial', 'tower', 'mantle', 'flat', 'crown', 'amphora', 'branch') or len(limbs) % 2:
        return 'radial'
    if len(limbs) == 4:
        width=max(abs(leg['rest'][0]) for leg in limbs)
        return 'radial' if any(abs(leg['rest'][0]) < width*.2 for leg in limbs) else 'quadruped'
    return 'many'


def main():
    families = json.loads((DATA/'ecology.json').read_text())['ground_families']
    rows = [r for file in ['forms', 'xenofauna_forms', 'xenoflora_forms', 'biota_forms']
            for r in json.loads((DATA/'bestiary'/f'{file}.json').read_text())['forms']]
    selected = [r for r in rows if r['category'] == 'animal'
                and r.get('locomotion_medium', '') not in ('surface_air', 'atmosphere')
                and (r.get('locomotion_medium') == 'ground' or r['family'] in families)]
    forms = {}; hashes = hashlib.sha256(); counts = {}
    for i, form in enumerate(selected):
        limbs, sha = contacts(form)
        profile = kind(form, limbs); counts[profile] = counts.get(profile, 0)+1
        forms[form['id']] = {'kind': profile, 'limbs': limbs}
        hashes.update((form['id']+sha).encode())
        if (i+1) % 500 == 0: print('CONTACTS', i+1, '/', len(selected), flush=True)
    result = {'version': 1, 'source': 'Blender near GLB weighted soles and authored pivots',
              'source_sha256': hashes.hexdigest(), 'counts': counts, 'forms': forms}
    (DATA/'bestiary/ground_locomotion.json').write_text(json.dumps(result, ensure_ascii=False, separators=(',', ':'))+'\n')
    print('GROUND_CONTACTS', len(forms), counts, flush=True)

if __name__ == '__main__': main()
