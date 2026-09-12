from pathlib import Path
import os, shutil, subprocess, sys
ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'우주-비즈니스'
mode=sys.argv[1]
Path(f'/tmp/game-overview-{mode}').mkdir(parents=True,exist_ok=True)
WORK=ROOT/'output/game-overview/work'/mode
PROJECT=WORK/'capture-project'
PROJECT.mkdir(parents=True,exist_ok=True)
for name in ['assets','data','scripts','scenes','icon.svg','icon.svg.import']:
    link=PROJECT/name
    if not link.exists():link.symlink_to(SOURCE/name)
cache=PROJECT/'.godot';cache.mkdir(exist_ok=True)
for name in ['global_script_class_cache.cfg','uid_cache.bin']:shutil.copy2(SOURCE/'.godot'/name,cache/name)
if not (cache/'imported').exists():(cache/'imported').symlink_to(SOURCE/'.godot/imported')
shutil.copy2(SOURCE/'project.godot',PROJECT/'project.godot')
with (WORK/'capture.log').open('w') as log:
    result=subprocess.run([os.environ.get('GAMEPLAY_GODOT','/Users/jskim/Downloads/Godot.app/Contents/MacOS/Godot'),'--path',str(PROJECT),'--write-movie',str(WORK/'raw.avi'),'--fixed-fps','30','--disable-vsync','--script',str(ROOT/f'tools/media/capture_overview_{mode}.gd'),'--','--crew-ui-test',f'--crew-folder=/tmp/game-overview-{mode}','--dest='+str(WORK)],stdout=log,stderr=subprocess.STDOUT)
print('CAPTURE',mode,result.returncode,flush=True)
raise SystemExit(result.returncode)
