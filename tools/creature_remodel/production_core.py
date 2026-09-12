"""Per-species editable source, skin, two LODs and actual Blender source render."""
from pathlib import Path
import hashlib,json,time
import bpy,numpy as np
from build_batch import AnatomicalStudy,biota_rig
from refine_creature_motion import socket
ROOT=Path(__file__).resolve().parents[2]

def build(spec,batch,fingerprint,constructor,motion,render_source):
    src=ROOT/'art/blender/creature_remodel'/batch;out=ROOT/'우주-비즈니스/assets/models/creature_remodel'/batch;media=ROOT/'docs/production/media/creature-remodel'/batch
    for path in [src,out,media/'blender']:path.mkdir(parents=True,exist_ok=True)
    stamp=fingerprint(spec);metadata=src/(spec['id']+'.json')
    if metadata.exists():
        row=json.loads(metadata.read_text())
        if row.get('build_fingerprint')==stamp and (ROOT/row['source']).exists() and (media/'blender'/(spec['id']+'.png')).exists() and all(hashlib.sha256((ROOT/l['path']).read_bytes()).hexdigest()==l['sha256'] for l in row['lods'].values()):
            print('BATCH_SKIP',spec['id'],flush=True);return row
    start=time.monotonic();s=AnatomicalStudy(spec);s.organs=[];s.muzzles={};constructor(s)
    s.fuse_skin();s.rig();s.socket_bindings={}
    for name,point in s.muzzles.items():socket(s,'Socket_'+name,name,point)
    primary=next(iter(s.muzzles));socket(s,'Socket_Muzzle',primary,s.muzzles[primary]);socket(s,'Socket_Strike',primary,s.muzzles[primary])
    for leg in s.legs:socket(s,'Socket_'+leg['name'],leg['name']+'_foot',leg['foot'])
    average=sum(l['upper']+l['lower'] for l in s.legs)/len(s.legs) if s.legs else .9
    stride=min(.40,average*.32)
    s.profile=dict(duration=2.8,prepare=.78,release=[1.08],active_end=1.36,settle=2.64,travel=0,stride=stride,stance=.73,period=1.,run=dict(stride=stride*1.55,stance=.70,period=.60),limb_phases={l['name']:l['phase'] for l in s.legs})
    motion(s);bpy.context.view_layer.update()
    source=src/(spec['id']+'.blend');bpy.ops.wm.save_as_mainfile(filepath=str(source))
    points=np.array([tuple(ob.matrix_world@v.co) for ob in bpy.context.scene.objects if ob.type=='MESH' for v in ob.data.vertices]);points=(points-points.min(axis=0))/max(np.ptp(points,axis=0))
    row={**spec,'version':batch+'-1','build_fingerprint':stamp,'normalized_geometry_sha256':hashlib.sha256(np.round(points,5).tobytes()).hexdigest(),'source':str(source.relative_to(ROOT)),'status':'built-awaiting-game-render','bone_count':len(s.bones),'locomotion_chains':len(s.legs),'clips':list(s.actions),'sockets':s.socket_bindings,'motion_profile':s.profile,'muzzle':[s.muzzle.x,s.muzzle.z,-s.muzzle.y],'lods':{},'skeleton_topology':{n:d['parent'] for n,d in s.bones.items()}}
    biota_rig.consolidate()
    for lod in ['near','far']:
        if lod=='far':
            s.arm.data.pose_position='REST'
            for ob in list(bpy.context.scene.objects):
                if ob.type!='MESH' or len(ob.data.polygons)<160:continue
                bpy.context.view_layer.objects.active=ob;mod=ob.modifiers.new('Approved far budget','DECIMATE');mod.ratio=.43;bpy.ops.object.modifier_apply(modifier=mod.name)
            s.arm.data.pose_position='POSE'
        path=out/(spec['id']+'_'+lod+'.glb');bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',export_yup=True,export_animations=True,export_animation_mode='ACTIONS',export_merge_animation='ACTION',export_force_sampling=True,export_frame_range=False,export_cameras=False,export_lights=False)
        points=[];triangles=0
        for ob in bpy.context.scene.objects:
            if ob.type=='MESH':ob.data.calc_loop_triangles();triangles+=len(ob.data.loop_triangles);points.extend(ob.matrix_world@v.co for v in ob.data.vertices)
        points=[(p.x,p.z,-p.y) for p in points]
        row['lods'][lod]=dict(path=str(path.relative_to(ROOT)),sha256=hashlib.sha256(path.read_bytes()).hexdigest(),triangles=triangles,min=[min(p[i] for p in points) for i in range(3)],max=[max(p[i] for p in points) for i in range(3)])
    row['build_seconds']=round(time.monotonic()-start,3)
    bpy.ops.wm.open_mainfile(filepath=str(source));s.arm=bpy.data.objects['StudySkeleton'];render_source(s)
    row['source_render_seconds']=round(time.monotonic()-start-row['build_seconds'],3)
    metadata.write_text(json.dumps(row,ensure_ascii=False,indent=2)+'\n');print('BATCH_BUILT',spec['id'],row['bone_count'],row['build_seconds'],row['source_render_seconds'],flush=True)
    return row
