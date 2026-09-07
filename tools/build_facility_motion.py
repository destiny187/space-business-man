"""Add inspectable moving mechanisms to existing Blender facilities; preserve their bodies.
Run with Blender --background --python tools/build_facility_motion.py.
"""
from pathlib import Path
import bpy, math, json
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]

def material(name,color):
    m=bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.diffuse_color=(*color,1);m.use_nodes=True
    m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*color,1)
    m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.65
    return m

def part(name,loc,scale,mat,parent=None,cylinder=False):
    if cylinder:bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=1,depth=2,location=loc)
    else:bpy.ops.mesh.primitive_cube_add(size=2,location=loc)
    ob=bpy.context.object;ob.name='Motion_'+name;ob.scale=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    ob.data.materials.append(mat);ob['ground_motion']=True
    bevel=ob.modifiers.new('Machined edges','BEVEL');bevel.width=.035;bevel.segments=2
    ob.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
    if parent:ob.parent=parent;ob.matrix_parent_inverse=parent.matrix_world.inverted()
    return ob

records=[]
for kind in ['atmosphere','thermal','water','biolab']:
    src=ROOT/'art/blender'/f'{kind}.blend';out=ROOT/'우주-비즈니스/assets/models'/f'{kind}.glb'
    bpy.ops.wm.open_mainfile(filepath=str(src))
    for ob in list(bpy.data.objects):
        if ob.get('ground_motion'):bpy.data.objects.remove(ob,do_unlink=True)
    dark=material('Motion graphite',(.06,.095,.12));metal=material('Motion ceramic',(.68,.78,.77));accent=material('Motion process accent',{'atmosphere':(.38,.76,.70),'thermal':(.96,.43,.12),'water':(.20,.55,.82),'biolab':(.36,.80,.40)}[kind])
    loc=(1.18,0,2.12) if kind in ['atmosphere','thermal'] else ((1.18,0,1.55) if kind=='water' else (0,0,3.12))
    name='Anim_Fan_Process' if kind in ['atmosphere','thermal'] else ('Anim_Piston_Process' if kind=='water' else 'Anim_Agitator_Process')
    rotor=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(rotor);rotor.location=loc;rotor['ground_motion']=True;bpy.context.view_layer.update()
    if kind in ['atmosphere','thermal']:
        part('fan bracket',(1.0,0,1.80),(.44,.43,.10),dark)
        part('fan hub',loc,(.13,.13,.11),accent,rotor,True)
        for angle in [0,math.pi/2]:
            blade=part('fan blade',loc,(.49,.085,.035),metal,rotor);blade.rotation_euler.z=angle
        for y in [-.48,.48]:part('fan guard',(1.18,y,2.2),(.55,.035,.035),dark)
    elif kind=='water':
        part('pump base',(1.18,0,.70),(.32,.32,.3),dark, cylinder=True)
        part('pump guide',(1.18,0,1.25),(.19,.19,.38),metal,cylinder=True)
        part('piston',loc,(.11,.11,.36),accent,rotor,True)
        part('piston cap',(1.18,0,1.89),(.30,.30,.08),accent,rotor,True)
    else:
        for angle in [0,math.pi/2,math.pi,math.pi*1.5]:
            x,y=.86*math.cos(angle),.86*math.sin(angle)
            part('culture paddle',(x,y,3.12),(.10,.10,.19),accent,rotor)
        # An external service stirrer ring leaves the existing glass dome intact.
        bpy.ops.mesh.primitive_torus_add(major_radius=.86,minor_radius=.045,major_segments=32,minor_segments=8,location=loc)
        ring=bpy.context.object;ring.name='Motion_culture_ring';ring.data.materials.append(dark);ring['ground_motion']=True;ring.parent=rotor;ring.matrix_parent_inverse=rotor.matrix_world.inverted()
    bpy.ops.wm.save_as_mainfile(filepath=str(src))
    bpy.ops.export_scene.gltf(filepath=str(out),export_format='GLB',export_cameras=False,export_lights=False,export_apply=True)
    scene=bpy.context.scene;scene.world=bpy.data.worlds.new('Temporary review world');scene.world.color=(.18,.18,.18)
    bpy.ops.object.camera_add(location=(7,-9,6));camera=bpy.context.object;camera.rotation_euler=(Vector((0,0,1.9))-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='ORTHO';camera.data.ortho_scale=7.5;scene.camera=camera
    for pos,energy in [((3,-5,8),1800),((-4,-1,5),900)]:
        bpy.ops.object.light_add(type='AREA',location=pos);light=bpy.context.object;light.data.energy=energy;light.data.shape='DISK';light.data.size=5;light.rotation_euler=(Vector((0,0,1.5))-light.location).to_track_quat('-Z','Y').to_euler()
    scene.render.engine='CYCLES';scene.cycles.samples=16;scene.render.resolution_x=800;scene.render.resolution_y=600;scene.render.resolution_percentage=100;scene.render.filepath=f'/tmp/ground-facility-{kind}.png';bpy.ops.render.render(write_still=True)
    records.append({'kind':kind,'source':str(src.relative_to(ROOT)),'game_file':str(out.relative_to(ROOT)),'moving_node':name,'review':scene.render.filepath})
(ROOT/'art/blender/ground-motion-manifest.json').write_text(json.dumps({'version':1,'generator':'tools/build_facility_motion.py','models':records},ensure_ascii=False,indent=2)+'\n')
