"""Match radial double-sweep contacts to the already authored left/right organs.

Read bind coordinates from the exported skin, preserving every mesh and animation.
Paired hook roots mark each trunk tip; the original two selected tips validate the
coordinate system before a missing left-hand tip is selected.
"""
import json, struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
_cache = {}

def inverse(matrix):
    rows = [list(row) + [float(i == j) for j in range(4)] for i, row in enumerate(matrix)]
    for i in range(4):
        pivot = max(range(i, 4), key=lambda j: abs(rows[j][i]))
        rows[i], rows[pivot] = rows[pivot], rows[i]
        value = rows[i][i]
        assert abs(value) > 1e-10, 'Singular skin bind matrix'
        rows[i] = [x / value for x in rows[i]]
        for j in range(4):
            if j != i:
                factor = rows[j][i]
                rows[j] = [x - factor * y for x, y in zip(rows[j], rows[i])]
    return [row[4:] for row in rows]

def patch(row):
    if row.get('construction') != 'crown_stalker' or row.get('host_motion') != 'double_sweep':
        return
    key = row['lods']['near']['sha256']
    if key not in _cache:
        raw = (ROOT / row['lods']['near']['path']).read_bytes()
        length = struct.unpack_from('<I', raw, 12)[0]
        data = json.loads(raw[20:20 + length]); binary = raw[28 + length:]
        skin = data['skins'][0]; accessor = data['accessors'][skin['inverseBindMatrices']]
        view = data['bufferViews'][accessor['bufferView']]
        assert accessor['componentType'] == 5126 and accessor['type'] == 'MAT4'
        offset = view.get('byteOffset', 0) + accessor.get('byteOffset', 0)
        points = {}
        for i, node in enumerate(skin['joints']):
            values = struct.unpack_from('<16f', binary, offset + i * view.get('byteStride', 64))
            bind = inverse([[values[c * 4 + r] for c in range(4)] for r in range(4)])
            points[data['nodes'][node]['name']] = [bind[r][3] for r in range(3)]
        graph = row['skeleton_topology']; candidates = []
        for name, parent in graph.items():
            if not name.startswith('radial_trunk'):
                continue
            hooks = [child for child, owner in graph.items() if owner == name and child.startswith('opposed_hook')]
            if not hooks:
                continue
            assert len(hooks) == 2
            tip = [sum(points[child][axis] for child in hooks) / 2 for axis in range(3)]
            candidates.append({'bone': name, 'point': tip, 'left': points[parent][0] < -1e-6})
        for original in row['motion_profile']['strike_origins']:
            actual = next(p for p in candidates if p['bone'] == original['bone'])
            assert max(abs(a - b) for a, b in zip(actual['point'], original['point'])) < 2e-5
        selected = [max((p for p in candidates if p['left'] == left), key=lambda p: p['point'][2]) for left in [True, False]]
        _cache[key] = [{'bone': p['bone'], 'point': p['point']} for p in selected]
    row['motion_profile']['strike_origins'] = _cache[key]
    row['contact_metadata_version'] = 1
