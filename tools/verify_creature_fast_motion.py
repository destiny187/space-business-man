"""Verify the full new motion set against BOTH existing glTF skeletons, without importing meshes."""
import collections
import gzip
import hashlib
import json
import math
import struct
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / '우주-비즈니스/data'
OUT = ROOT / 'output/creature-fast-motion'


def roster():
    return {r['source_id']: r for batch in ['r01', 'r02', 'r03', 'r04', 'r05', 'r06', 'combat', 'flight']
            for r in json.loads((DATA / f'creature_remodel_{batch}.json').read_text())['forms']}


def skeleton(path):
    with path.open('rb') as f:
        magic, version, _ = struct.unpack('<4sII', f.read(12))
        assert magic == b'glTF' and version == 2, path
        size, kind = struct.unpack('<I4s', f.read(8))
        assert kind == b'JSON', path
        gltf = json.loads(f.read(size))
    nodes = gltf['nodes']
    joints = set(j for skin in gltf['skins'] for j in skin['joints'])
    parents = {child: parent for parent, node in enumerate(nodes) for child in node.get('children', [])}
    return {nodes[i]['name']: dict(parent=nodes[parents[i]]['name'] if parents.get(i) in joints else None,
                                    translation=nodes[i].get('translation', [0, 0, 0]),
                                    rotation=nodes[i].get('rotation', [0, 0, 0, 1]),
                                    scale=nodes[i].get('scale', [1, 1, 1]),
                                    matrix=nodes[i].get('matrix', [])) for i in joints}


def main():
    rows = roster()
    forms = {r['id']: r for batch in ['forms','xenofauna_forms','xenoflora_forms','biota_forms']
             for r in json.loads((DATA/'bestiary'/(batch+'.json')).read_text())['forms'] if r['category']=='animal'}
    assert len(rows) == 5600
    assert {p.stem for p in (DATA / 'creature_fast_motion').glob('*.json')} == set(rows)
    assert {p.stem for p in (ROOT / 'art/blender/creature_fast_motion').glob('*.blend')} == set(rows)
    assert {p.stem for p in (ROOT / '우주-비즈니스/assets/animations/creatures').glob('*.motion')} == set(rows)
    results = []
    for id, row in rows.items():
        row['medium'] = forms[id].get('locomotion_medium', row.get('locomotion_medium','ground'))
        source_sha = hashlib.sha256((ROOT / row['source']).read_bytes()).hexdigest()
        stamp = hashlib.sha256((ROOT/'tools/creature_remodel/fast_motion.py').read_bytes()+json.dumps(row,sort_keys=True).encode()+source_sha.encode()).hexdigest()
        deadline=time.monotonic()+3600
        while True:
            try:meta=json.loads((DATA / 'creature_fast_motion' / (id + '.json')).read_text())
            except (FileNotFoundError,json.JSONDecodeError):meta={}
            if meta.get('fingerprint')==stamp or '--wait' not in sys.argv:break
            assert time.monotonic()<deadline,('Authoring did not finish',id)
            time.sleep(1)
        assert stamp == meta.get('fingerprint'), ('Outdated authoring', id)
        asset = (ROOT / meta['asset']).read_bytes()
        assert hashlib.sha256(asset).hexdigest() == meta['asset_sha256'], id
        assert source_sha == meta['original_source_sha256'], id
        pack = json.loads(gzip.decompress(asset))
        assert pack['species_id'] == id and pack['version'] == 1 and pack['profile'] == meta['profile'], id
        near, far = (skeleton(ROOT / row['lods'][lod]['path']) for lod in ['near', 'far'])
        assert near == far, ('LOD rest transforms differ', id)
        assert {n: b['parent'] for n, b in near.items()} == pack['parents'], ('Skeleton mismatch', id)
        assert len(near) == pack['profile']['bone_count'], id
        assert set(pack['clips']) == set(meta['clips']) and 'sprint_loop' in pack['clips'], id
        assert ('sprint_charge_loop' in pack['clips']) == (row.get('host_motion') == 'charge'), id
        moving_bones = set()
        for clip in pack['clips'].values():
            assert set(clip['tracks']) == set(near) and clip['duration'] > 0, id
            for name, frames in clip['tracks'].items():
                assert len(frames) == 33 and frames[0] == frames[-1], (id, name)
                for v in frames:
                    assert len(v) == 10 and all(math.isfinite(n) for n in v), (id, name)
                    assert abs(sum(n*n for n in v[3:7]) - 1) < .0001, (id, name)
                    assert min(v[7:]) > 0, (id, name)
                if name != 'root' and any(max(abs(a-b) for a,b in zip(frames[0], f)) > .002 for f in frames[1:]):
                    moving_bones.add(name)
        assert len(moving_bones) >= 2, ('Only rigid motion', id)
        p = pack['profile']
        assert p['medium'] == row['medium'], id
        if p['medium']=='water':assert p['mode']=='swim', id
        if p['medium'] in ['air','surface_air']:assert p['mode']=='flight', id
        assert 0 < p['stance'] < 1 and .2 <= p['period'] <= 1.5 and .01 < p['natural_speed'] < 50, id
        assert abs(p['natural_speed'] - p['stride']/p['stance']/p['period']) < .00001, id
        assert all(n + '_foot' in near for n in p['limb_phases']), id
        prior = row['motion_profile']['run']
        results.append(dict(species_id=id, art_id=row['id'], kind=row['kind'], mode=p['mode'],
                            bones=len(near), moving_bones=len(moving_bones), natural_speed=p['natural_speed'],
                            prior_run_speed=prior['stride']/prior['stance']/prior['period'],
                            clips=len(pack['clips']), source_bytes=(ROOT/meta['source']).stat().st_size, motion_bytes=len(asset)))
        if len(results) % 500 == 0: print('FAST_VERIFY', len(results), flush=True)
    OUT.mkdir(parents=True, exist_ok=True)
    summary = dict(species=len(results), clips=sum(r['clips'] for r in results), lod_skeletons=len(results)*2,
                   modes=dict(collections.Counter(r['mode'] for r in results)),
                   sources_bytes=sum(r['source_bytes'] for r in results), motions_bytes=sum(r['motion_bytes'] for r in results),
                   scope='All motion tracks, loop closure, two existing glTF skeletons/rests, original source hashes. Not visual approval of each species.',
                   species_results=results)
    (OUT / 'asset-verification.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({k:v for k,v in summary.items() if k != 'species_results'}, ensure_ascii=False))


if __name__ == '__main__':
    main()
