"""Run disjoint Blender workers and keep progress on disk. No background scheduler."""
from pathlib import Path
import sys,json,subprocess,time,os
from production_recipes import recipes
ROOT=Path(__file__).resolve().parents[2]
BLENDER='/Applications/Blender.app/Contents/MacOS/Blender'
def main():
    mode=sys.argv[1] if len(sys.argv)>1 else 'representatives'
    rows=recipes()
    if mode=='representatives':
        selected=[]
        for index,family in enumerate(dict.fromkeys(r['family'] for r in rows)):
            group=[r for r in rows if r['family']==family];preferred=index%5
            choices=[r for r in group if r['morphology']['mode']==preferred]
            selected.append((choices or group)[0])
        rows=selected
    elif mode=='extremes':
        selected=[]
        for index,family in enumerate(dict.fromkeys(r['family'] for r in rows)):
            group=[r for r in rows if r['family']==family];preferred=2+index%3
            choices=[r for r in group if r['morphology']['mode']==preferred]
            selected.append(max(choices or group,key=lambda r:r['morphology']['radial_count']))
        rows=selected
    elif mode!='all':rows=[r for r in rows if r['construction']==mode or r['family']==mode or r['id']==mode]
    assert rows
    dest=ROOT/'output/creature-remodel/production';dest.mkdir(parents=True,exist_ok=True)
    jobs=[];workers=int(os.environ.get("CREATURE_WORKERS","4"));threads=max(1,8//workers)
    assert 1<=workers<=8
    for worker in range(workers):
        ids=[r['id'] for r in rows[worker::workers]];log=open(dest/f'{mode}-{worker}.log','w')
        process=subprocess.Popen([BLENDER,'--background','--threads',str(threads),'--python',str(ROOT/'tools/creature_remodel/produce.py'),'--',*ids],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
        jobs.append((process,log,ids))
    state={'mode':mode,'species_count':len(rows),'pids':[p.pid for p,_,_ in jobs],'status':'running'}
    path=dest/'active.json';path.write_text(json.dumps(state,indent=2))
    print('PRODUCTION_STARTED',len(rows),'species; workers',state['pids'],flush=True)
    while any(p.poll() is None for p,_,_ in jobs):time.sleep(2)
    codes=[p.returncode for p,_,_ in jobs]
    for _,log,_ in jobs:log.close()
    state.update(status='complete' if all(code==0 for code in codes) else 'failed',exit_codes=codes);path.write_text(json.dumps(state,indent=2))
    print('PRODUCTION_FINISHED',state,flush=True)
    if any(codes):raise SystemExit(1)
if __name__=='__main__':main()
