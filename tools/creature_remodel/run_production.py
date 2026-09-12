"""Run disjoint Blender workers and keep progress on disk. No background scheduler."""
from pathlib import Path
import sys,json,subprocess,time,os,importlib
BATCH=os.environ.get('CREATURE_BATCH','r03')
recipes=importlib.import_module({'r03':'production_recipes','r04':'midpoint_recipes','r05':'air_recipes','r06':'legacy_recipes'}[BATCH]).recipes
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
    elif mode=='lineages':
        assert BATCH=='r06'
        rows=[next(r for r in rows if (r['construction'],r['morphology']['lineage'])==key) for key in dict.fromkeys((r['construction'],r['morphology']['lineage']) for r in rows)]
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
    workers=int(os.environ.get('CREATURE_WORKERS','4'));threads=int(os.environ.get('CREATURE_THREADS','2'));chunk_size=int(os.environ.get('CREATURE_CHUNK_SIZE','48'))
    assert 1<=workers<=8 and threads>=1 and chunk_size>0
    queues=[[r['id'] for r in rows[worker::workers]] for worker in range(workers)]
    prefix=mode if BATCH=='r03' else BATCH+'-'+mode
    logs=[open(dest/f'{prefix}-{worker}.log','w') for worker in range(workers)]
    jobs={};codes=[];completed_chunks=0
    capture=os.environ.get('CREATURE_CAPTURE_ANIMATION')=='1';script='produce_captured.py' if capture else {'r03':'produce.py','r04':'produce_midpoints.py','r05':'produce_air.py','r06':'produce_legacy.py'}[BATCH]
    state={'mode':mode,'species_count':len(rows),'status':'running','chunk_size':chunk_size,'batch':BATCH,'selected_ids':[r['id'] for r in rows]}
    path=dest/('active.json' if BATCH=='r03' else BATCH+'-active.json')
    def save_state():
        state.update(pids=[p.pid for p in jobs.values()],completed_chunks=completed_chunks)
        temp=path.with_suffix('.tmp');temp.write_text(json.dumps(state,indent=2));os.replace(temp,path)
    def launch(worker):
        ids=queues[worker][:chunk_size];del queues[worker][:chunk_size]
        jobs[worker]=subprocess.Popen([BLENDER,'--background','--threads',str(threads),'--python',str(ROOT/'tools/creature_remodel'/script),'--',*([BATCH] if capture else []),*ids],cwd=ROOT,stdout=logs[worker],stderr=subprocess.STDOUT)
    for worker in range(workers):
        if queues[worker]:launch(worker)
    save_state();print('PRODUCTION_STARTED',len(rows),'species; workers',state['pids'],'chunk',chunk_size,flush=True)
    while jobs:
        for worker,process in list(jobs.items()):
            code=process.poll()
            if code is None:continue
            codes.append(code);del jobs[worker]
            if code==0:
                completed_chunks+=1
                if queues[worker]:launch(worker)
            else:
                state['status']='failed';queues[worker]=[]
            save_state()
        if jobs:time.sleep(2)
    for log in logs:log.close()
    state.update(status='complete' if all(code==0 for code in codes) else 'failed',exit_codes=codes);save_state()
    print('PRODUCTION_FINISHED',state,flush=True)
    if any(codes):raise SystemExit(1)
if __name__=='__main__':main()
