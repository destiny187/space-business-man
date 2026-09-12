"""One finite production run: capture completed assets as Blender finishes them.

This is not a scheduler. It exits after the current production run and remaining
captures finish. It never enables unreviewed models or modifies world data.
"""
from pathlib import Path
import sys,json,time,subprocess,os,argparse
from with_renderer import renderer_slot
ROOT=Path(__file__).resolve().parents[2]
def pending(batch):
    manifest=ROOT/f'우주-비즈니스/data/creature_remodel_{batch}.json'
    rows=json.loads(manifest.read_text())['forms'];result=[]
    for row in rows:
        path=ROOT/'output/creature-remodel'/batch/(row['id']+'_evidence.json')
        old=json.loads(path.read_text()) if path.exists() else {}
        evidence=old.get('species',old)
        if (evidence.get('id')!=row['id'] or evidence.get('asset_sha256')!={key:value['sha256'] for key,value in row['lods'].items()}
            or batch!='r05' and evidence.get('authored_pose_capture_version',0)<2
            or evidence.get('body_support_version',0)!=row.get('body_support_version',0)
            or evidence.get('contact_metadata_version',0)!=row.get('contact_metadata_version',0)):result.append(row['id'])
    return result
def main():
    parser=argparse.ArgumentParser();parser.add_argument('--batch',default='r03',choices=['r03','r04','r05','r06']);parser.add_argument('--pid',type=int);parser.add_argument('--state');args=parser.parse_args();batch=args.batch
    assert batch=='r03' or args.pid or args.state,'Non-R03 runs require a finite worker PID or production state'
    destination=ROOT/'output/creature-remodel/production';prefix='game-review' if batch=='r03' else batch+'-game-review'
    sequence=1+max([int(p.stem.rsplit('-',1)[1]) for p in destination.glob(prefix+'-*.log')],default=-1)
    while True:
        state={}
        if batch=='r03' or args.state:
            state=json.loads((Path(args.state) if args.state else destination/'active.json').read_text());running=state['status']=='running'
        else:
            try:os.kill(args.pid,0);running=True
            except ProcessLookupError:running=False
        with open(destination/(batch+'-publish.log'),'w') as log:
            subprocess.run([sys.executable,'tools/creature_remodel/publish_manifest.py',batch],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
        todo=pending(batch)
        if len(todo)>=32 or todo and not running:
            selection=todo[:96];logpath=destination/f'{prefix}-{sequence:03d}.log';sequence+=1
            print('RENDER_READY',len(selection),'of',len(todo),'waiting; log',logpath.name,flush=True)
            with renderer_slot(),logpath.open('w') as log:
                scene='creature_air_review' if batch=='r05' else 'creature_batch_review'
                result=subprocess.run([str(ROOT/'tools/godot.sh'),'--script','res://scripts/showcase/'+scene+'.gd','--','--batch='+batch,'--direct','--unreviewed',*selection],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
            text=logpath.read_text(errors='replace')
            done='REMODEL_AIR_DONE' if batch=='r05' else 'REMODEL_BATCH_DONE'
            if result.returncode or 'SCRIPT ERROR' in text or done not in text:raise RuntimeError('Game render requires attention: '+str(logpath))
            continue
        if not running and not todo:
            from importlib import import_module
            recipes=import_module({'r03':'production_recipes','r04':'midpoint_recipes','r05':'air_recipes','r06':'legacy_recipes'}[batch]).recipes
            built={r['id'] for r in json.loads((ROOT/f'우주-비즈니스/data/creature_remodel_{batch}.json').read_text())['forms']}
            selected=set(state.get('selected_ids',[])) or {r['id'] for r in recipes()}
            missing=selected-built
            if missing:raise RuntimeError('Production ended with missing species: '+', '.join(sorted(missing)))
            print('RENDER_READY_COMPLETE; per-species captures await final audit and visual selection',flush=True);return
        time.sleep(30)
if __name__=='__main__':main()
