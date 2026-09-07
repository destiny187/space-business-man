"""Build a deforming surveyor armature in Blender; preserve rigid armor panels."""
import bpy
from mathutils import Vector

def rig_suit():
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    assignment = {}
    for o in meshes:
        name = o.name
        side = 'L' if o.matrix_world.translation.x < 0 else 'R'
        parent = o.parent.name if o.parent else ''
        if parent.startswith('Anim_Arm'):
            bone = ('forearm_' if name.startswith(('Elbow', 'Gauntlet', 'Glove')) else 'upper_arm_') + side
        elif parent.startswith('Anim_Leg'):
            bone = ('foot_' if name.startswith(('Magnetic', 'Boot')) else 'shin_' if name.startswith(('Knee', 'Shin')) else 'thigh_') + side
        elif name.startswith(('Helmet', 'Recessed', 'Panoramic', 'Comms')):
            bone = 'head'
        elif name.startswith(('Utility', 'Belt')):
            bone = 'pelvis'
        else:
            bone = 'spine'
        assignment[o.name] = bone
        matrix = o.matrix_world.copy(); o.parent = None; o.matrix_world = matrix
    for o in list(bpy.context.scene.objects):
        if o.type == 'EMPTY': bpy.data.objects.remove(o, do_unlink=True)
    armature = bpy.data.armatures.new('SurveyorSkeleton')
    rig = bpy.data.objects.new('SurveyorRig', armature)
    bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig; rig.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    definitions = [('pelvis', (0, .85, 0), None), ('spine', (0, 1.04, 0), 'pelvis'), ('head', (0, 1.49, 0), 'spine')]
    for side, x in [('L', -1), ('R', 1)]:
        definitions += [
            ('upper_arm_'+side, (x*.39, 1.35, 0), 'spine'),
            ('forearm_'+side, (x*.45, .96, -.025), 'upper_arm_'+side),
            ('thigh_'+side, (x*.18, .85, 0), 'pelvis'),
            ('shin_'+side, (x*.18, .43, 0), 'thigh_'+side),
            ('foot_'+side, (x*.18, .14, 0), 'shin_'+side)]
    # Parallel rest axes make procedural joint rotations deterministic across exports.
    for name, p, parent in definitions:
        bone = armature.edit_bones.new(name)
        bone.head = (p[0], -p[2], p[1]); bone.tail = bone.head + Vector((0, 0, .10))
        if parent: bone.parent = armature.edit_bones[parent]
    bpy.ops.object.mode_set(mode='OBJECT')
    for o in meshes:
        bpy.context.view_layer.objects.active = o
        for modifier in list(o.modifiers): bpy.ops.object.modifier_apply(modifier=modifier.name)
        bone = assignment[o.name]
        group = o.vertex_groups.new(name=bone)
        group.add(list(range(len(o.data.vertices))), 1.0, 'REPLACE')
        # Soft gasket vertices blend over the hinge, while armor stays rigid.
        if o.name.startswith(('Elbow gasket', 'Knee gasket')):
            parent = ('upper_arm_' if bone.startswith('forearm') else 'thigh_') + bone[-1]
            other = o.vertex_groups.new(name=parent)
            joint_z = .96 if bone.startswith('forearm') else .43
            for v in o.data.vertices:
                weight = max(0.0, min(1.0, .5 + ((o.matrix_world @ v.co).z-joint_z)/.20))
                group.add([v.index], 1-weight, 'REPLACE'); other.add([v.index], weight, 'REPLACE')
        modifier = o.modifiers.new('Surveyor deformation', 'ARMATURE'); modifier.object = rig
        o.parent = rig
    rig.show_in_front = True
    return rig

def export_suit(source, output):
    rig = rig_suit()
    bpy.context.scene.unit_settings.system = 'METRIC'
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    bpy.ops.object.select_all(action='DESELECT')
    for o in meshes: o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]; bpy.ops.object.join()
    bpy.ops.export_scene.gltf(filepath=str(output), export_format='GLB', export_yup=True, export_animations=False)
    mesh = bpy.context.object.data; mesh.calc_loop_triangles()
    return len(mesh.loop_triangles), len(mesh.materials), len(rig.data.bones)
