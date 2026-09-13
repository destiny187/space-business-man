"""Render the SAVED action libraries appended to their original weighted Blender meshes."""
import gzip
import hashlib
import json
import sys
from pathlib import Path
import bpy
from mathutils import Matrix, Quaternion, Vector

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'output/creature-fast-motion/blender-final'

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    selection=json.loads((ROOT/'tools/creature_remodel/fast_motion_review.json').read_text())
    ids=selection['baseline']+selection['additional']
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    if args:ids=[id for id in ids if id in args]
    evidence=json.loads((OUT/'evidence.json').read_text()) if args and (OUT/'evidence.json').exists() else []
    evidence=[r for r in evidence if r['species_id'] not in ids]
    for id in ids:
        meta=json.loads((ROOT/'우주-비즈니스/data/creature_fast_motion'/f'{id}.json').read_text())
        pack=json.loads(gzip.decompress((ROOT/meta['asset']).read_bytes()))
        original=ROOT/meta['original_source'];library=ROOT/meta['source']
        before=hashlib.sha256(original.read_bytes()).hexdigest()
        library_sha=hashlib.sha256(library.read_bytes()).hexdigest()
        bpy.ops.wm.open_mainfile(filepath=str(original))
        scene=bpy.context.scene;arm=bpy.data.objects['StudySkeleton'];arm.animation_data_clear()
        with bpy.data.libraries.load(str(library),link=False) as (available,loaded):
            assert set(meta['clips']).issubset(available.actions),id
            loaded.actions=meta['clips'];loaded.objects=['StudySkeleton']
        saved_arm=loaded.objects[0]
        assert len(saved_arm.data.bones)==len(arm.data.bones),id
        for b in arm.data.bones:
            assert max(abs(b.matrix_local[i][j]-saved_arm.data.bones[b.name].matrix_local[i][j]) for i in range(4) for j in range(4))<.00001,id
        action=next(a for a in loaded.actions if a.name.startswith('sprint_loop'))
        arm.animation_data_create();arm.animation_data.action=action
        meshes=[o for o in scene.objects if o.type=='MESH']
        points=[]
        for sample in [8,20]:
            time=1+sample/32*float(pack['profile']['period'])*30
            scene.frame_set(int(time),subframe=time-int(time));bpy.context.view_layer.update()
            graph=bpy.context.evaluated_depsgraph_get()
            for obj in meshes:
                evaluated=obj.evaluated_get(graph)
                points.extend(evaluated.matrix_world@Vector(p) for p in evaluated.bound_box)
        lo=Vector([min(p[i] for p in points) for i in range(3)]);hi=Vector([max(p[i] for p in points) for i in range(3)])
        center=(lo+hi)*.5;size=max(hi-lo)
        bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.04))
        bpy.ops.object.camera_add(location=center+Vector((1.2,-1.7,.95)).normalized()*size*3)
        cam=bpy.context.object;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=size*1.5;scene.camera=cam
        scene.world=bpy.data.worlds.new('Fast motion review');scene.world.use_nodes=True
        scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.24,.28,.26,1)
        for offset,energy in [((1,-1.5,2),140),((-1,.5,.8),75)]:
            bpy.ops.object.light_add(type='AREA',location=center+Vector(offset)*size)
            lamp=bpy.context.object;lamp.data.energy=energy*size*size;lamp.data.size=size
            lamp.rotation_euler=(center-lamp.location).to_track_quat('-Z','Y').to_euler()
        scene.render.engine='CYCLES';scene.cycles.samples=16;scene.cycles.use_denoising=True
        scene.render.resolution_x=640;scene.render.resolution_y=480;scene.render.resolution_percentage=100
        pose_error=0.
        for sample in [8,20]:
            time=1+sample/32*float(pack['profile']['period'])*30
            scene.frame_set(int(time),subframe=time-int(time));bpy.context.view_layer.update()
            for name,frames in pack['clips']['sprint_loop']['tracks'].items():
                v=frames[sample];expected=Matrix.LocRotScale(Vector(v[:3]),Quaternion((v[6],v[3],v[4],v[5])),Vector(v[7:]))
                actual=arm.pose.bones[name].matrix_basis
                pose_error=max(pose_error,max(abs(expected[i][j]-actual[i][j]) for i in range(4) for j in range(4)))
            assert pose_error<.001,(id,pose_error)
            scene.render.filepath=str(OUT/f'{id}-{sample}.png');bpy.ops.render.render(write_still=True)
        assert before==hashlib.sha256(original.read_bytes()).hexdigest()
        assert library_sha==hashlib.sha256(library.read_bytes()).hexdigest()
        evidence.append(dict(species_id=id,mode=pack['profile']['mode'],source=meta['source'],original_source=meta['original_source'],
                             library_sha256=library_sha,pose_delta_error=pose_error,renderer='Cycles',samples=[8,20]))
        print('FAST_SAVED_SOURCE_RENDER',id,pose_error,flush=True)
    (OUT/'evidence.json').write_text(json.dumps(evidence,ensure_ascii=False,indent=2)+'\n')

if __name__=='__main__':main()
