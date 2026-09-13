"""Metre-space two-joint biped setup; save a bent, planted rest pose, not locked knees."""
import math
import bpy
from mathutils import Vector

def knee_target(h,k,f,target,bend_hint=None):
    upper=(k-h).length;lower=(f-k).length
    axis=(target-h).normalized();distance=min(max((target-h).length,abs(upper-lower)+.001),upper+lower-.001)
    along=(upper*upper-lower*lower+distance*distance)/(2*distance)
    bend=(k-h) if bend_hint is None else Vector(bend_hint)
    bend-=axis*bend.dot(axis)
    if bend.length<.001:raise ValueError('Biped knee plane needs an explicit forward direction')
    return h+axis*along+bend.normalized()*math.sqrt(max(0,upper*upper-along*along)),h+axis*distance

def rotate_node(node,old,new):
    matrix=node.matrix_world.copy();q=old.normalized().rotation_difference(new.normalized())
    matrix=q.to_matrix().to_4x4()@matrix;matrix.translation=node.matrix_world.translation
    node.matrix_world=matrix;bpy.context.view_layer.update()

def plant_nodes(hip,knee,foot,target):
    h=hip.matrix_world.translation.copy();k=knee.matrix_world.translation.copy();f=foot.matrix_world.translation.copy();basis=foot.matrix_world.to_3x3()
    bend,goal=knee_target(h,k,f,target,(0,-1,0))
    rotate_node(hip,k-h,bend-h)
    k=knee.matrix_world.translation.copy();f=foot.matrix_world.translation.copy()
    rotate_node(knee,f-k,goal-k)
    matrix=basis.to_4x4();matrix.translation=foot.matrix_world.translation;foot.matrix_world=matrix;bpy.context.view_layer.update()

def rotate_bone(rig,bone,old,new):
    value=bone.matrix.copy();q=old.normalized().rotation_difference(new.normalized())
    rotated=q.to_matrix().to_4x4()@value;rotated.translation=value.translation
    bone.matrix=rotated;bpy.context.view_layer.update()

def plant_bones(rig,hip,knee,foot,target):
    h=hip.matrix.translation.copy();k=knee.matrix.translation.copy();f=foot.matrix.translation.copy();basis=foot.matrix.to_3x3()
    bend,goal=knee_target(h,k,f,target,(0,1,0))
    rotate_bone(rig,hip,k-h,bend-h)
    k=knee.matrix.translation.copy();f=foot.matrix.translation.copy()
    rotate_bone(rig,knee,f-k,goal-k)
    matrix=basis.to_4x4();matrix.translation=foot.matrix.translation;foot.matrix=matrix;bpy.context.view_layer.update()

def set_planted_rest(rig,mesh,drop=.16):
    feet={s:rig.pose.bones['foot_'+str(s)].matrix.translation.copy() for s in [-1,1]}
    pelvis=rig.pose.bones['pelvis'];value=pelvis.matrix.copy();value.translation.z-=drop;pelvis.matrix=value;bpy.context.view_layer.update()
    for side,target in feet.items():plant_bones(rig,*[rig.pose.bones[n+'_'+str(side)] for n in ['hip','knee','foot']],target)
    # Bake the same pose into vertices AND bind matrices; neither envelope nor weights drift.
    bpy.context.view_layer.objects.active=mesh
    for modifier in list(mesh.modifiers):
        if modifier.type=='ARMATURE':bpy.ops.object.modifier_apply(modifier=modifier.name)
    bpy.context.view_layer.objects.active=rig;bpy.ops.object.mode_set(mode='POSE');bpy.ops.pose.armature_apply(selected=False);bpy.ops.object.mode_set(mode='OBJECT')
    modifier=mesh.modifiers.new('Mechanical joint skin','ARMATURE');modifier.object=rig

def walk(rig,t,stride=1.8,lift=.20):
    for side in [-1,1]:
        u=(t+(0.5 if side<0 else 0))%1
        foot=rig.pose.bones['foot_'+str(side)];target=rig.data.bones[foot.name].matrix_local.translation.copy()
        if u<.6:along=stride*.6*(.5-u/.6);height=0
        else:
            q=(u-.6)/.4;ease=q*q*(3-2*q);along=stride*.6*(ease-.5);height=math.sin(q*math.pi)*lift
        target.y+=along;target.z+=height
        plant_bones(rig,rig.pose.bones['hip_'+str(side)],rig.pose.bones['knee_'+str(side)],foot,target)
