"""One finite production run: capture completed assets as Blender finishes them.

This is not a scheduler. It exits after the current production run and remaining
captures finish. It never enables unreviewed models or modifies world data.
"""
from pathlib import Path
import sys,json,time,subprocess,os
ROOT=Path(__file__).resolve().parents[2]
def pending():
    manifest=ROOT/'우주-비즈니스/data/creature_remodel_r03.json'
    rows=json.loads(manifest.read_text())['forms'];result=[]
    for row in rows:
        path=ROOT/'output/creature-remodel/r03'/(row['id']+'_evidence.json')
        old=json.loads(path.read_text()) if path.exists() else {}
        evidence=old.get('species',{})
        if evidence.get('id')!=row['id'] or evidence.get('asset_sha256')!={key:value['sha256'] for key,value in row['lods'].items()}:result.append(row['id'])
    return result
def main():
    destination=ROOT/'output/creature-remodel/production';sequence=1+max([int(p.stem.rsplit('-',1)[1]) for p in destination.glob('game-review-*.log')],default=-1)
    while True:
        state=json.loads((destination/'active.json').read_text());running=state['status']=='running'
        with open(destination/'publish.log','w') as log:
            subprocess.run([sys.executable,'tools/creature_remodel/publish_manifest.py','r03'],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
        todo=pending()
        if len(todo)>=32 or todo and not running:
            selection=todo[:96];logpath=destination/f'game-review-{sequence:03d}.log';sequence+=1
            print('RENDER_READY',len(selection),'of',len(todo),'waiting; log',logpath.name,flush=True)
            with logpath.open('w') as log:
                result=subprocess.run([str(ROOT/'tools/godot.sh'),'--script','res://scripts/showcase/creature_batch_review.gd','--','--batch=r03','--direct','--unreviewed',*selection],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
            text=logpath.read_text(errors='replace')
            if result.returncode or 'SCRIPT ERROR' in text or 'REMODEL_BATCH_DONE' not in text:raise RuntimeError('Game render requires attention: '+str(logpath))
            continue
        if not running and not todo:
            from production_recipes import recipes
            built={r['id'] for r in json.loads((ROOT/'우주-비즈니스/data/creature_remodel_r03.json').read_text())['forms']}
            missing={r['id'] for r in recipes()}-built
            if missing:raise RuntimeError('Production ended with missing species: '+', '.join(sorted(missing)))
            print('RENDER_READY_COMPLETE; per-species captures await final audit and visual selection',flush=True);return
        time.sleep(30)
if __name__=='__main__':main()
