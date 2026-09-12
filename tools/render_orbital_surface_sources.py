"""Review existing Blender geometry with the new maps; preserve original .blend files."""
from pathlib import Path
import bpy, math, sys
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
DEST=ROOT/'docs/production/media/orbital-surfaces'
DEST.mkdir(parents=True,exist_ok=True)
selected=next((a.split('=',1)[1].split(',') for a in sys.argv if a.startswith('--only=')),['oxidized','earth','jupiter'])
for name in selected:
    solar=name!='oxidized'
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender'/('solar-system' if solar else 'planet-variants')/(name+'.blend')))
    obj=bpy.data.objects['Anim_Surface' if solar else 'Surface']
    mesh=obj.data;uv=mesh.uv_layers.new(name='OrbitalMapReview')
    for face in mesh.polygons:
        coords=[]
        for loop in face.loop_indices:
            p=mesh.vertices[mesh.loops[loop].vertex_index].co.normalized()
            coords.append([math.atan2(-p.y,p.x)/(2*math.pi)+.5,1-math.acos(max(-1,min(1,p.z)))/math.pi])
        if max(v[0] for v in coords)-min(v[0] for v in coords)>.5:
            for v in coords:
                if v[0]<.5:v[0]+=1
        for loop,co in zip(face.loop_indices,coords):uv.data[loop].uv=co
    mat=mesh.materials[0].copy();mesh.materials[0]=mat
    nodes=mat.node_tree.nodes;links=mat.node_tree.links
    image=nodes.new('ShaderNodeTexImage');image.image=bpy.data.images.load(str(ROOT/'우주-비즈니스/assets/textures/orbital'/(name+'.png')))
    uvnode=nodes.new('ShaderNodeUVMap');uvnode.uv_map=uv.name;links.new(uvnode.outputs['UV'],image.inputs['Vector'])
    if solar:links.new(image.outputs['Color'],nodes.get('Principled BSDF').inputs['Base Color'])
    else:
        image.image.colorspace_settings.name='Non-Color';links.new(image.outputs['Color'],next(n for n in nodes if n.type=='VALTORGB').inputs[0])
    for o in list(bpy.data.objects):
        if o.type in ['CAMERA','LIGHT'] or o.name=='Anim_Clouds':bpy.data.objects.remove(o,do_unlink=True)
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=16
    scene.render.resolution_x=scene.render.resolution_y=600;scene.render.resolution_percentage=100
    scene.world=bpy.data.worlds.new('Mapped orbital source review');scene.world.color=(.04,.05,.065)
    bpy.ops.object.camera_add(location=(.6,-3.8,.5));camera=bpy.context.object;camera.rotation_euler=(-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.type='ORTHO';camera.data.ortho_scale=2.4;scene.camera=camera
    for position,power in [((-3,-4,5),650),((4,-1,2),160)]:
        bpy.ops.object.light_add(type='AREA',location=position);light=bpy.context.object;light.data.energy=power;light.data.size=3;light.rotation_euler=(-Vector(position)).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(DEST/(name+'-blender.png'))
    bpy.ops.wm.save_as_mainfile(filepath='/tmp/orbital-'+name+'-review.blend')
    bpy.ops.render.render(write_still=True)
    print('ORBITAL_SOURCE_REVIEW',name,flush=True)
