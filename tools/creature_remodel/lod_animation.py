"""Reuse the unchanged near-LOD animation bytes in a separately decimated far skin.

Only the second export avoids animation baking. Bone names, parent relationships,
rest transforms and inverse bind matrices must agree before any tracks are copied.
"""
from pathlib import Path
import ast, copy, inspect, json, struct


def read(path):
    raw = Path(path).read_bytes()
    assert struct.unpack_from('<III', raw) == (0x46546C67, 2, len(raw))
    length, kind = struct.unpack_from('<II', raw, 12)
    assert kind == 0x4E4F534A
    data = json.loads(raw[20:20+length])
    start = 20+length
    size, kind = struct.unpack_from('<II', raw, start)
    assert kind == 0x004E4942 and start+8+size == len(raw)
    assert len(data['buffers']) == 1 and 'uri' not in data['buffers'][0]
    return data, raw[start+8:start+8+size]


def write(path, data, binary):
    data['buffers'][0]['byteLength'] = len(binary)
    header = json.dumps(data, separators=(',', ':')).encode()
    header += b' '*((-len(header)) % 4)
    binary += b'\0'*((-len(binary)) % 4)
    raw = (struct.pack('<III', 0x46546C67, 2, 28+len(header)+len(binary))
           + struct.pack('<II', len(header), 0x4E4F534A)+header
           + struct.pack('<II', len(binary), 0x004E4942)+binary)
    Path(path).write_bytes(raw)


def accessor_bytes(data, binary, index):
    accessor = data['accessors'][index]
    assert 'sparse' not in accessor
    view = data['bufferViews'][accessor['bufferView']]
    assert view.get('buffer', 0) == 0 and not view.get('extensions')
    count = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}[accessor['type']]
    size = {5121: 1, 5123: 2, 5125: 4, 5126: 4}[accessor['componentType']]*count
    start = view.get('byteOffset', 0)+accessor.get('byteOffset', 0)
    stride = view.get('byteStride', size)
    return b''.join(binary[start+i*stride:start+i*stride+size] for i in range(accessor['count']))


def transplant(near_path, far_path):
    near, source = read(near_path)
    far, target = read(far_path)
    assert near.get('animations') and not far.get('animations')
    assert len(near['skins']) == len(far['skins']) == 1
    def names(data):
        result = {node['name']: i for i, node in enumerate(data['nodes'])}
        assert len(result) == len(data['nodes']), 'Node names must be unique'
        return result
    near_names, far_names = names(near), names(far)
    mapping = {i: far_names[name] for name, i in near_names.items()}
    near_skin, far_skin = near['skins'][0], far['skins'][0]
    assert [mapping[i] for i in near_skin['joints']] == far_skin['joints']
    assert accessor_bytes(near, source, near_skin['inverseBindMatrices']) == accessor_bytes(far, target, far_skin['inverseBindMatrices'])
    parents = lambda data: {child: i for i, node in enumerate(data['nodes']) for child in node.get('children', [])}
    source_parents, target_parents = parents(near), parents(far)
    defaults = {'matrix': [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1],
                'translation': [0, 0, 0], 'rotation': [0, 0, 0, 1], 'scale': [1, 1, 1]}
    for i, node in enumerate(near['nodes']):
        other = far['nodes'][mapping[i]]
        assert mapping.get(source_parents.get(i)) == target_parents.get(mapping[i])
        for key in ['matrix', 'translation', 'rotation', 'scale']:
            a, b = node.get(key, defaults[key]), other.get(key, defaults[key])
            # Re-evaluated empty sockets can differ by a few float ULPs.
            # q and -q encode the same rotation, including a 180-degree socket.
            error=max(abs(x-y) for x,y in zip(a,b))
            if key=='rotation':error=min(error,max(abs(x+y) for x,y in zip(a,b)))
            assert len(a)==len(b) and error<=.000002, ('Changed rest transform', node['name'], key)
    views, accessors = {}, {}
    def copy_accessor(index):
        nonlocal target
        if index in accessors:
            return accessors[index]
        value = copy.deepcopy(near['accessors'][index])
        assert 'sparse' not in value and not value.get('extensions')
        view_index = value['bufferView']
        if view_index not in views:
            view = copy.deepcopy(near['bufferViews'][view_index])
            assert view.get('buffer', 0) == 0 and not view.get('extensions')
            offset = view.get('byteOffset', 0)
            target += b'\0'*((-len(target)) % 4)
            view['byteOffset'] = len(target)
            target += source[offset:offset+view['byteLength']]
            views[view_index] = len(far['bufferViews'])
            far['bufferViews'].append(view)
        value['bufferView'] = views[view_index]
        accessors[index] = len(far['accessors'])
        far['accessors'].append(value)
        return accessors[index]
    far['animations'] = copy.deepcopy(near['animations'])
    for animation in far['animations']:
        for sampler in animation['samplers']:
            for key in ['input', 'output']:
                sampler[key] = copy_accessor(sampler[key])
        for channel in animation['channels']:
            assert not channel.get('extensions') and not channel['target'].get('extensions')
            channel['target']['node'] = mapping[channel['target']['node']]
    write(far_path, far, target)


def export_scene(**kwargs):
    import bpy
    path = Path(kwargs['filepath'])
    if path.name.endswith('_near.glb'):
        return bpy.ops.export_scene.gltf(**kwargs)
    assert path.name.endswith('_far.glb')
    # A non-animated export otherwise bakes the current idle pose into the mesh.
    # Match the animated export's bind geometry, then restore the live scene.
    armatures = [(arm, arm.pose_position) for arm in bpy.data.armatures]
    try:
        for arm, _ in armatures:
            arm.pose_position = 'REST'
        result = bpy.ops.export_scene.gltf(**{**kwargs, 'export_animations': False})
    finally:
        for arm, position in armatures:
            arm.pose_position = position
    assert result == {'FINISHED'}
    transplant(path.with_name(path.name.removesuffix('_far.glb')+'_near.glb'), path)
    return result


def compile_build(module):
    tree = ast.parse(inspect.getsource(module.build))
    calls = 0
    class Rewrite(ast.NodeTransformer):
        def visit_Call(self, node):
            nonlocal calls
            node = self.generic_visit(node)
            if ast.unparse(node.func) == 'bpy.ops.export_scene.gltf':
                node.func = ast.Name(id='_reuse_lod_export', ctx=ast.Load())
                calls += 1
            return node
    tree = Rewrite().visit(tree)
    assert calls == 1, 'The production export loop changed; inspect it before adapting'
    tree.body[0].name = '_build_reusing_lod_animation'
    module.__dict__['_reuse_lod_export'] = export_scene
    exec(compile(ast.fix_missing_locations(tree), str(Path(module.__file__)), 'exec'), module.__dict__)
    return module.__dict__['_build_reusing_lod_animation']
