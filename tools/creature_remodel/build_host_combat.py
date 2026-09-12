"""Preserve approved meshes; add host-compatible charging and one-landing leap clips."""
from pathlib import Path
import sys,json,hashlib,math
import bpy
from mathutils import Vector as V,Matrix
ROOT=Path(__file__).resolve().parents[2];sys.path[:0]=[str(ROOT/'tools'),str(Path(__file__).parent)]
from refine_creature_motion import from_source,mesh_digest
from build_creature_studies import smooth,biota_rig
import build_batch as pipeline
SRC=ROOT/'art/blender/creature_remodel/combat';OUT=ROOT/'우주-비즈니스/assets/models/creature_remodel/combat';MEDIA=ROOT/'docs/production/media/creature-remodel/combat'
for p in [SRC,OUT,MEDIA/'blender']:p.mkdir(parents=True,exist_ok=True)

def keyframe(s,frame):
    for b in s.arm.pose.bones:
        for prop in ['location','rotation_euler','scale']:b.keyframe_insert(data_path=prop,frame=frame,group=b.name)

def build(row):
    s=from_source(row);before=mesh_digest();scene=bpy.context.scene;scene.render.fps=30;rig=s.arm
    if row['id']=='sailhorn':
        attack=bpy.data.actions['attack'];rig.animation_data.action=attack;scene.frame_set(round(row['motion_profile']['prepare']*30)+1)
        lowered={name:rig.pose.bones[name].matrix_basis.copy() for name in ['neck','head']}
        run=bpy.data.actions['run_loop'];duration=float(row['motion_profile']['run']['period'])*2;poses=[]
        for frame in range(round(duration*30)+1):
            rig.animation_data.action=run;scene.frame_set(frame+1);poses.append({b.name:b.matrix_basis.copy() for b in rig.pose.bones})
        action=bpy.data.actions.new('charge_loop');action.use_fake_user=True;rig.animation_data.action=action;scene.frame_start=1;scene.frame_end=len(poses)
        for frame,pose in enumerate(poses):
            scene.frame_set(frame+1)
            for name,matrix in pose.items():rig.pose.bones[name].matrix_basis=lowered.get(name,matrix)
            keyframe(s,frame+1)
        extra=['charge_loop']
    else:
        extra=['leap_prepare','leap_air','leap_land']
        for state,duration in [('leap_prepare',.8),('leap_air',1.0),('leap_land',.7)]:
            action=bpy.data.actions.new(state);action.use_fake_user=True;rig.animation_data.action=action;scene.frame_start=1;scene.frame_end=round(duration*30)+1
            for frame in range(scene.frame_end):
                scene.frame_set(frame+1);t=frame/30;f=min(1,t/duration)
                for b in rig.pose.bones:b.rotation_mode='XYZ';b.matrix_basis=Matrix.Identity(4)
                crouch=.14*smooth(0,1,f) if state=='leap_prepare' else (.14*(1-smooth(0,.22,f)) if state=='leap_air' else .17*math.sin(f*math.pi))
                s.local('root',location=s.binds['root'].to_3x3().inverted()@V((0,0,-crouch)))
                s.local('chest',(-.08 if state!='leap_land' else .12*math.sin(f*math.pi),0,0));s.local('neck',(.07,0,0));s.local('head',(-.06,0,0))
                for i,name in enumerate(s.flex):s.local(name,(0,0,.10*math.sin(f*math.pi-i*.4)*(1 if state=='leap_air' else .3)))
                bpy.context.view_layer.update()
                for leg in s.legs:
                    foot=V(leg['foot']);front=leg['name'].startswith('leg0')
                    if state=='leap_air':
                        fold=smooth(0,.20,f)*(1-smooth(.60 if front else .73,1,f));foot+=V((0,.17 if front else -.08,.34))*fold
                        if front:foot.y-=.22*smooth(.64,1,f)
                    elif state=='leap_land' and front:foot.y-=.22*(1-smooth(0,1,f))
                    s.solve_leg(leg,foot)
                keyframe(s,frame+1)
    action=bpy.data.actions.new('down');action.use_fake_user=True;rig.animation_data.action=action;scene.frame_start=1;scene.frame_end=37
    for frame in range(37):
        scene.frame_set(frame+1);settle=smooth(0,1.1,frame/30)
        for b in rig.pose.bones:b.rotation_mode='XYZ';b.matrix_basis=Matrix.Identity(4)
        drop=float(s.bones['pelvis']['a'].z)*.42*settle
        s.local('root',location=s.binds['root'].to_3x3().inverted()@V((0,0,-drop)))
        s.local('chest',(.16*settle,0,.12*settle));s.local('neck',(.35*settle,0,.08*settle));s.local('head',(.10*settle,0,0))
        bpy.context.view_layer.update()
        for leg in s.legs:s.solve_leg(leg,V(leg['foot']))
        keyframe(s,frame+1)
    extra.append('down')
    assert mesh_digest()==before==row['approved_mesh_digest'],'Approved shape must remain identical'
    rig.animation_data.action=bpy.data.actions['idle_loop'];scene.frame_set(1);source=SRC/(row['id']+'.blend');bpy.ops.wm.save_as_mainfile(filepath=str(source))
    result={**row,'source':str(source.relative_to(ROOT)),'clips':row['clips']+extra,'status':'host-clips-built-awaiting-render','host_motion':'charge' if row['id']=='sailhorn' else 'leap','lods':{}}
    biota_rig.consolidate()
    for lod in ['near','far']:
        if lod=='far':
            rig.data.pose_position='REST'
            for ob in list(bpy.context.scene.objects):
                if ob.type!='MESH' or len(ob.data.polygons)<160:continue
                bpy.context.view_layer.objects.active=ob;mod=ob.modifiers.new('Approved far budget','DECIMATE');mod.ratio=.43;bpy.ops.object.modifier_apply(modifier=mod.name)
            rig.data.pose_position='POSE'
        path=OUT/(row['id']+'_'+lod+'.glb');bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',export_yup=True,export_animations=True,export_animation_mode='ACTIONS',export_merge_animation='ACTION',export_force_sampling=True,export_frame_range=False,export_cameras=False,export_lights=False)
        result['lods'][lod]={**row['lods'][lod],'path':str(path.relative_to(ROOT)),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
    bpy.ops.wm.open_mainfile(filepath=str(source));s.arm=bpy.data.objects['StudySkeleton'];pipeline.MEDIA=MEDIA;pipeline.source_render(s)
    (SRC/(row['id']+'.json')).write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print('HOST_CLIPS_BUILT',row['id'],extra,flush=True)

if __name__=='__main__':
    rows=json.loads((ROOT/'우주-비즈니스/data/creature_remodel_r01.json').read_text())['forms']
    for row in rows:
        if row['id'] in ['sailhorn','shearprowler']:build(row)
    rows=[json.loads(p.read_text()) for p in sorted(SRC.glob('*.json'))]
    (ROOT/'우주-비즈니스/data/creature_remodel_combat.json').write_text(json.dumps({'version':1,'forms':rows},ensure_ascii=False,indent=2)+'\n')
