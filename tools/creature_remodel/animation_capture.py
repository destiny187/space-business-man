"""Capture analytically authored poses without repeatedly evaluating the skinned scene.

The anatomical modules reset every pose and solve their own rest-space IK. They do
not read evaluated meshes, constraints or drivers while sampling. Keep their exact
30 fps poses and action curves; evaluate the scene only after the action is built.
The original source and this implementation both participate in build provenance.
"""
from pathlib import Path
import ast, hashlib


def fingerprint(base):
    return hashlib.sha256(base.encode()+Path(__file__).read_bytes()).hexdigest()


class PoseCapture:
    def __init__(self, rig, action):
        self.rig, self.action = rig, action
        self.frames = []
        self.values = {}

    def sample(self, frame):
        for bone in self.rig.pose.bones:
            for prop in ['location', 'rotation_euler', 'scale']:
                path = bone.path_from_id(prop)
                self.values.setdefault(path, []).append(tuple(getattr(bone, prop)))
                if not self.frames:
                    # Let Blender create the same layered-action slots and groups.
                    bone.keyframe_insert(data_path=prop, frame=frame, group=bone.name)
        self.frames.append(frame)

    def finish(self):
        import numpy as np
        bag = self.action.layers[0].strips[0].channelbag(self.action.slots[0])
        arrays = {path: np.asarray(values) for path, values in self.values.items()}
        for curve in bag.fcurves:
            first = curve.keyframe_points[0]
            interpolation, left, right = first.interpolation, first.handle_left_type, first.handle_right_type
            curve.keyframe_points.add(len(self.frames)-1)
            co = np.column_stack((self.frames, arrays[curve.data_path][:, curve.array_index]))
            curve.keyframe_points.foreach_set('co', co.ravel())
            for key in curve.keyframe_points:
                key.interpolation, key.handle_left_type, key.handle_right_type = interpolation, left, right
            curve.update()


def compile_animation(module, bulk=True):
    tree = ast.parse(Path(module.__file__).read_text())
    clock = 'frame' if module.__name__ == 'air_motion' else 'f'

    class Capture(ast.NodeTransformer):
        evaluations = 0
        writers = 0
        loops = 0

        def visit_Expr(self, node):
            if isinstance(node.value, ast.Call) and ast.unparse(node.value) == 'scene.frame_set('+clock+' + 1)':
                self.evaluations += 1
                return None
            return node

        def visit_For(self, node):
            if bulk and isinstance(node.target, ast.Name) and node.target.id in ['b', 'bone'] and any(
                isinstance(n, ast.Call) and isinstance(n.func, ast.Attribute) and n.func.attr == 'keyframe_insert'
                for n in ast.walk(node)
            ):
                self.writers += 1
                return ast.parse('__capture.sample('+clock+' + 1)').body[0]
            node = self.generic_visit(node)
            if bulk and isinstance(node.target, ast.Name) and node.target.id == clock:
                assert ast.unparse(node.iter) in ['range(count + 1)', 'range(scene.frame_end)'], 'Unknown authoring clock'
                self.loops += 1
                return [ast.parse('__capture = PoseCapture(rig, action)').body[0], node,
                        ast.parse('__capture.finish()').body[0]]
            return node

    change = Capture()
    tree = change.visit(tree)
    assert change.evaluations == 1 and (not bulk or change.writers == change.loops == 1), 'Unexpected animation authoring structure'
    scope = dict(vars(module), PoseCapture=PoseCapture)
    exec(compile(ast.fix_missing_locations(tree), module.__file__+' [pose capture]', 'exec'), scope)
    return scope['animate']
