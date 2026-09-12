"""Import complete enabled GLBs in an isolated Godot project, then install its validated cache.

Relative res:// paths and importer settings are identical. This avoids scanning GLBs
while Blender is still writing unrelated species. No gameplay or source settings change.
"""
from pathlib import Path
import hashlib,json,re,shutil,subprocess,os
ROOT=Path(__file__).resolve().parents[2];GAME=ROOT/'우주-비즈니스'
STAGE=ROOT/'output/creature-remodel/import-project'
GODOT=next((Path(p) for p in [os.environ.get('GAME_GODOT_BIN'),shutil.which('godot'),shutil.which('godot4'),'/Applications/Godot.app/Contents/MacOS/Godot',str(Path.home()/'Downloads/Godot.app/Contents/MacOS/Godot')] if p and Path(p).is_file()),None)

DIGEST_PATH=ROOT/'output/creature-remodel/production/import-digests.json'
DIGESTS=json.loads(DIGEST_PATH.read_text()) if DIGEST_PATH.exists() else {}
def digest(path,algorithm='sha256',force=False):
    info=path.stat();signature=[info.st_size,info.st_mtime_ns,info.st_ctime_ns,info.st_ino]
    key=str(path);cached=DIGESTS.get(key,{})
    if force or cached.get('signature')!=signature:
        data=path.read_bytes();after=path.stat()
        assert signature==[after.st_size,after.st_mtime_ns,after.st_ctime_ns,after.st_ino],str(path)+' changed while hashing'
        cached={'signature':signature,'sha256':hashlib.sha256(data).hexdigest(),'md5':hashlib.md5(data).hexdigest()}
        DIGESTS[key]=cached
    return cached[algorithm]
def save_digests():
    DIGEST_PATH.parent.mkdir(parents=True,exist_ok=True)
    temp=DIGEST_PATH.with_suffix('.tmp');temp.write_text(json.dumps(DIGESTS));os.replace(temp,DIGEST_PATH)
def destinations(text):
    line=next(line for line in text.splitlines() if line.startswith('dest_files='))
    return [p.removeprefix('res://') for p in re.findall(r'"(res://[^\"]+)"',line)]

def seed_completed_cache(row,stage):
    """Retain completed serial imports when dividing the remaining finite batch."""
    if stage==STAGE:return False
    source=STAGE/row['relative'];sidecar=source.with_suffix('.glb.import')
    if not source.is_file() or not sidecar.is_file() or digest(source)!=row['sha256']:return False
    dest=destinations(sidecar.read_text())
    if not dest or not all((STAGE/p).is_file() for p in dest):return False
    md5=STAGE/(dest[0].rsplit('.',1)[0]+'.md5')
    if not md5.is_file() or 'source_md5="'+digest(source,'md5')+'"' not in md5.read_text():return False
    for relative in dest+[str(md5.relative_to(STAGE))]:
        target=stage/relative;target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(STAGE/relative,target)
    shutil.copy2(sidecar,(stage/row['relative']).with_suffix('.glb.import'))
    return True

def import_stage(selected,stage):
    stage.mkdir(parents=True,exist_ok=True)
    (stage/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Completed fauna import"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    seeded=0
    for r in selected:
        source=GAME/r['relative'];target=stage/r['relative'];target.parent.mkdir(parents=True,exist_ok=True)
        if not target.exists() or digest(target)!=r['sha256']:
            shutil.copy2(source,target)
            sidecar=source.with_suffix('.glb.import')
            if sidecar.exists():shutil.copy2(sidecar,target.with_suffix('.glb.import'))
        if seed_completed_cache(r,stage):seeded+=1
    (stage/'selected.json').write_text(json.dumps(selected))
    (stage/'check_import.gd').write_text('''extends SceneTree
func _initialize() -> void:
 var rows: Array=JSON.parse_string(FileAccess.get_file_as_string("res://selected.json"))
 for row in rows:
  var scene=load("res://"+str(row.relative));assert(scene is PackedScene)
  var model=scene.instantiate();root.add_child(model)
  var skeletons=model.find_children("*","Skeleton3D",true,false);assert(skeletons.size()==1)
  var skeleton: Skeleton3D=skeletons[0];assert(skeleton.get_bone_count()==int(row.bone_count))
  var players=model.find_children("*","AnimationPlayer",true,false);assert(players.size()==1)
  for clip in row.clips:assert(players[0].has_animation(clip) or players[0].has_animation(str(clip).trim_suffix("_loop")))
  for i in skeleton.get_bone_count():assert(skeleton.get_bone_rest(i).is_finite())
  model.free()
 print("COMPLETED_FAUNA_IMPORT_VALIDATED ",rows.size());quit()
''')
    print('IMPORT_WORKER',stage.name,len(selected),'GLBs; reused completed imports',seeded,flush=True)
    for command,logname in [([str(GODOT),'--headless','--path',str(stage),'--editor','--import'],'editor-import.log'),([str(GODOT),'--headless','--path',str(stage),'--script','res://check_import.gd'],'check-import.log')]:
        # Large, valid animation batches share the machine with Blender. Keep the
        # finite deadline generous enough for that work; logs expose live progress.
        with (stage/logname).open('w') as log:result=subprocess.run(command,stdout=log,stderr=subprocess.STDOUT,timeout=7200)
        text=(stage/logname).read_text();assert result.returncode==0 and 'SCRIPT ERROR' not in text,(logname,text[-2000:])
    assert 'COMPLETED_FAUNA_IMPORT_VALIDATED' in (stage/'check-import.log').read_text()
    return stage

def select_enabled():
    runtime=json.loads((GAME/'data/creature_remodel_runtime.json').read_text());forms={}
    enabled=set(runtime['enabled_ground_species']+runtime.get('enabled_air_species',[]))
    for source in runtime['sources']:
        for f in json.loads((GAME/source.removeprefix('res://')).read_text())['forms']:
            if f['source_id'] in enabled:forms[f['source_id']]=f
    for id,path in runtime.get('entry_paths',{}).items():forms[id]=json.loads((GAME/path.removeprefix('res://')).read_text())
    selected=[]
    for f in forms.values():
        for lod,asset in f['lods'].items():
            source=ROOT/asset['path'];assert digest(source)==asset['sha256'],source
            relative=source.relative_to(GAME);sidecar=source.with_suffix('.glb.import');current=sidecar.read_text() if sidecar.exists() else ''
            dest=destinations(current) if current else []
            md5=GAME/(dest[0].rsplit('.',1)[0]+'.md5') if dest else None
            if md5 and md5.exists() and all((GAME/p).exists() for p in dest) and 'source_md5="'+digest(source,'md5')+'"' in md5.read_text():continue
            selected.append(dict(id=f['id'],lod=lod,relative=str(relative),sha256=asset['sha256'],bone_count=f['bone_count'],clips=f['clips']))
    return selected

def main():
    assert GODOT is not None,'Godot executable was not found using tools/godot.sh locations'
    selection_path=os.environ.get('CREATURE_IMPORT_SELECTION')
    if selection_path:
        selected=json.loads(Path(selection_path).read_text())
        assert len({r['relative'] for r in selected})==len(selected)
        for r in selected:
            source=GAME/r['relative'];assert source.resolve().is_relative_to(GAME.resolve())
            assert digest(source)==r['sha256'],source
    else:selected=select_enabled()
    save_digests()
    if not selected:print('IMPORT_CURRENT all enabled assets already match their engine cache',flush=True);return
    workers=int(os.environ.get('CREATURE_IMPORT_WORKERS','1'));assert 1<=workers<=4
    print('IMPORT_SELECTED',len(selected),'GLBs; workers',workers,flush=True)
    if workers==1:
        stages=[(selected,import_stage(selected,STAGE))]
    else:
        from concurrent.futures import ThreadPoolExecutor
        # Keep each species' near/far pair together so every worker receives both
        # mesh budgets, rather than assigning all larger near meshes to half of them.
        species={}
        for row in selected:species.setdefault(row['id'],[]).append(row)
        parts=[[] for _ in range(workers)]
        for i,rows in enumerate(species.values()):parts[i%workers].extend(rows)
        parts=[rows for rows in parts if rows]
        with ThreadPoolExecutor(max_workers=workers) as pool:
            jobs=[(rows,pool.submit(import_stage,rows,STAGE.parent/'import-workers'/str(i))) for i,rows in enumerate(parts)]
            stages=[(rows,job.result()) for rows,job in jobs]
    imported={row['relative']:stage for rows,stage in stages for row in rows}
    assert len(imported)==len(selected)
    def install(source,dest):
        dest.parent.mkdir(parents=True,exist_ok=True);temp=dest.with_name(dest.name+'.remodel-tmp');shutil.copy2(source,temp);os.replace(temp,dest)
    for r in selected:
        source=GAME/r['relative'];assert digest(source,force=True)==r['sha256'],'Asset changed during import'
        stage=imported[r['relative']]
        sidecar=(stage/r['relative']).with_suffix('.glb.import');text=sidecar.read_text()
        for destination in destinations(text):
            install(stage/destination,GAME/destination)
            md5=destination.rsplit('.',1)[0]+'.md5'
            if (stage/md5).exists():install(stage/md5,GAME/md5)
        install(sidecar,source.with_suffix('.glb.import'))
    STAGE.mkdir(parents=True,exist_ok=True)
    (STAGE/'installed.json').write_text(json.dumps({'validated_glbs':len(selected),'assets':selected},indent=2)+'\n')
    save_digests()
    print('IMPORT_INSTALLED',len(selected),'validated GLBs; source settings unchanged',flush=True)
if __name__=='__main__':main()
