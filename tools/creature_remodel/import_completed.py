"""Import complete enabled GLBs in an isolated Godot project, then install its validated cache.

Relative res:// paths and importer settings are identical. This avoids scanning GLBs
while Blender is still writing unrelated species. No gameplay or source settings change.
"""
from pathlib import Path
import hashlib,json,re,shutil,subprocess,os
ROOT=Path(__file__).resolve().parents[2];GAME=ROOT/'우주-비즈니스'
STAGE=ROOT/'output/creature-remodel/import-project'
GODOT=next((Path(p) for p in [os.environ.get('GAME_GODOT_BIN'),shutil.which('godot'),shutil.which('godot4'),'/Applications/Godot.app/Contents/MacOS/Godot',str(Path.home()/'Downloads/Godot.app/Contents/MacOS/Godot')] if p and Path(p).is_file()),None)

def digest(path,algorithm='sha256'):return hashlib.new(algorithm,path.read_bytes()).hexdigest()
def destinations(text):
    line=next(line for line in text.splitlines() if line.startswith('dest_files='))
    return [p.removeprefix('res://') for p in re.findall(r'"(res://[^\"]+)"',line)]
def main():
    assert GODOT is not None,'Godot executable was not found using tools/godot.sh locations'
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
    if not selected:print('IMPORT_CURRENT all enabled assets already match their engine cache',flush=True);return
    STAGE.mkdir(parents=True,exist_ok=True)
    (STAGE/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Completed fauna import"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
    for r in selected:
        source=GAME/r['relative'];target=STAGE/r['relative'];target.parent.mkdir(parents=True,exist_ok=True)
        if target.exists() and digest(target)==r['sha256']:
            continue  # Preserve completed imports when resuming an interrupted batch.
        shutil.copy2(source,target)
        sidecar=source.with_suffix('.glb.import')
        if sidecar.exists():shutil.copy2(sidecar,target.with_suffix('.glb.import'))
    (STAGE/'selected.json').write_text(json.dumps(selected))
    (STAGE/'check_import.gd').write_text('''extends SceneTree
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
    print('IMPORT_SELECTED',len(selected),'GLBs',flush=True)
    for command,logname in [([str(GODOT),'--headless','--path',str(STAGE),'--editor','--import'],'editor-import.log'),([str(GODOT),'--headless','--path',str(STAGE),'--script','res://check_import.gd'],'check-import.log')]:
        with (STAGE/logname).open('w') as log:result=subprocess.run(command,stdout=log,stderr=subprocess.STDOUT,timeout=1800)
        text=(STAGE/logname).read_text();assert result.returncode==0 and 'SCRIPT ERROR' not in text,(logname,text[-2000:])
    assert 'COMPLETED_FAUNA_IMPORT_VALIDATED' in (STAGE/'check-import.log').read_text()
    def install(source,dest):
        dest.parent.mkdir(parents=True,exist_ok=True);temp=dest.with_name(dest.name+'.remodel-tmp');shutil.copy2(source,temp);os.replace(temp,dest)
    for r in selected:
        source=GAME/r['relative'];assert digest(source)==r['sha256'],'Asset changed during import'
        sidecar=(STAGE/r['relative']).with_suffix('.glb.import');text=sidecar.read_text()
        for destination in destinations(text):
            install(STAGE/destination,GAME/destination)
            md5=destination.rsplit('.',1)[0]+'.md5'
            if (STAGE/md5).exists():install(STAGE/md5,GAME/md5)
        install(sidecar,source.with_suffix('.glb.import'))
    (STAGE/'installed.json').write_text(json.dumps({'validated_glbs':len(selected),'assets':selected},indent=2)+'\n')
    print('IMPORT_INSTALLED',len(selected),'validated GLBs; source settings unchanged',flush=True)
if __name__=='__main__':main()
