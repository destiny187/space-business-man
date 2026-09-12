"""Compare a Blender static far export against its original animated far export."""
from pathlib import Path
import argparse, json
from lod_animation import read, accessor_bytes, transplant


def verify(near_path, original_path, static_path):
    original = read(original_path)
    static = read(static_path)
    assert len(original[0]['meshes']) == len(static[0]['meshes'])
    primitives = 0
    for a, b in zip(original[0]['meshes'], static[0]['meshes']):
        assert a['name'] == b['name'] and len(a['primitives']) == len(b['primitives'])
        for p, q in zip(a['primitives'], b['primitives']):
            assert p.get('mode', 4) == q.get('mode', 4)
            assert p.get('material') == q.get('material')
            assert p['attributes'].keys() == q['attributes'].keys()
            for key in p['attributes']:
                assert accessor_bytes(*original, p['attributes'][key]) == accessor_bytes(*static, q['attributes'][key]), key
            assert accessor_bytes(*original, p['indices']) == accessor_bytes(*static, q['indices'])
            primitives += 1
    assert original[0]['materials'] == static[0]['materials']
    if not static[0].get('animations'):
        transplant(near_path, static_path)
    reused = read(static_path)
    def tracks(data):
        gltf, binary = data
        return {(a['name'], gltf['nodes'][c['target']['node']]['name'], c['target']['path']): a['samplers'][c['sampler']]
                for a in gltf['animations'] for c in a['channels']}
    before, after = tracks(original), tracks(reused)
    assert before.keys() == after.keys()
    for key, a in before.items():
        b = after[key]
        assert a.get('interpolation', 'LINEAR') == b.get('interpolation', 'LINEAR')
        for attribute in ['input', 'output']:
            assert accessor_bytes(*original, a[attribute]) == accessor_bytes(*reused, b[attribute]), (key, attribute)
    return {'original': str(original_path), 'reused': str(static_path), 'primitives': primitives,
            'tracks': len(before), 'mesh_and_skin_bytes_identical': True, 'animation_bytes_identical': True}


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('near', type=Path)
    parser.add_argument('original', type=Path)
    parser.add_argument('static', type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    result = verify(args.near, args.original, args.static)
    if args.output:
        args.output.write_text(json.dumps(result, indent=2)+'\n')
    print('LOD_REUSE_EXACT', json.dumps(result), flush=True)
