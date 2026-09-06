#!/usr/bin/env python3
"""Shared terrain/ecology using actual game scenes and independent ENet processes."""
import argparse
import json
import math
from pathlib import Path
import socket
import subprocess
import tempfile
import time
ROOT = Path(__file__).resolve().parents[1]

def run(players, render_guests=False):
    work = Path(tempfile.mkdtemp(prefix='locus-crew-surface-'))
    procs, logs = {}, {}
    checks = 0
    names = ['host'] + [f'guest{i}' for i in range(players-1)]
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.bind(('127.0.0.1', 0));port = sock.getsockname()[1]
    def launch(name):
        folder = work/name;folder.mkdir(exist_ok=True)
        (folder/'status.json').unlink(missing_ok=True)
        logs[name] = (folder/'godot.log').open('a')
        cmd = [str(ROOT/'tools/godot.sh')]
        if name != 'host' and not render_guests:cmd.append('--headless')
        cmd += ['--script','res://tests/test_crew_surface_peer.gd','--','--crew-ui-test',f'--crew-folder={folder}',f'--crew-role={name}',f'--crew-port={port}']
        procs[name] = subprocess.Popen(cmd, stdout=logs[name], stderr=subprocess.STDOUT)
    def state(name):
        try:return json.loads((work/name/'status.json').read_text())
        except (FileNotFoundError, json.JSONDecodeError):return {}
    def member(name):
        snap=state(name).get('snapshot',{})
        return snap.get('crew',{}).get('members',{}).get(snap.get('self_id'),{})
    def wait(predicate, label, timeout=45):
        nonlocal checks
        deadline=time.monotonic()+timeout
        while time.monotonic()<deadline:
            if predicate():checks+=1;print('PASS',label,flush=True);return
            for name, proc in procs.items():
                if proc.poll() is not None and proc.returncode != 0:raise AssertionError(f'{name} exited: {label}')
            time.sleep(.07)
        raise AssertionError(label)
    def command(peer_name, **value):
        folder=work/peer_name;deadline=time.monotonic()+5
        while (folder/'command.json').exists():
            if time.monotonic()>deadline:raise AssertionError('command not consumed: '+peer_name)
            time.sleep(.02)
        (folder/'command.tmp').write_text(json.dumps(value));(folder/'command.tmp').replace(folder/'command.json')
    def request(name, action, **args):command(name, kind='request',action=action,args=args)
    def success(name, action, **args):
        for attempt in range(8):
            count=len(state(name).get('responses',[]));request(name,action,**args)
            wait(lambda:len(state(name).get('responses',[]))>count, name+' response '+action)
            result=state(name)['responses'][-1]['result']
            if result.get('ok'):return
            if '세계 상태가 바뀌' not in result.get('error',''):raise AssertionError((action,result))
            time.sleep(.2)
        raise AssertionError('unresolved stale revision: '+action)
    def ready_all():
        for name in names:
            success(name,'ready',value=True)
            wait(lambda n=name:member(n).get('ready'),name+' ready')
    def arrive(ordinal):
        success('host','navigate',ordinal=ordinal);ready_all();success('host','depart')
        wait(lambda:state('host').get('snapshot',{}).get('crew',{}).get('navigation',{}).get('mode')=='idle' and state('host')['snapshot']['location'].endswith(f':planet:{ordinal}'),f'arrive at {ordinal+1}',90)
        ready_all();success('host','land')
        wait(lambda:all(state(n).get('surface_ready') for n in names),'all peers have terrain collision',90)
        wait(lambda:all(state(n).get('body_id')==state('host').get('body_id') for n in names),'every peer has same planet ID')
    def place(name, point):
        command('host',kind='place',character_id=state(name)['snapshot']['self_id'],point=point)
        wait(lambda:math.dist(member(name).get('position',[999]*3),point)<1.2,'authoritative test position '+name)
    try:
        for name in names:
            launch(name);wait(lambda n=name:state(n).get('active'),name+' joined')
        arrive(15)
        wait(lambda:all(state(n).get('lineages')==state('host').get('lineages') for n in names),'identical authored seed lineages')
        wait(lambda:len(state('host').get('ecology_actors',[]))>0,'real shared surface renders authored creatures')
        initial=member('guest0')['position']
        command('guest0',kind='move_world',direction=[0,-1])
        wait(lambda:member('guest0')['position'][2]<initial[2]-4,'guest walks on host terrain collision')
        command('guest0',kind='move_world',direction=[0,0])
        command('host',kind='surface_frame',name='landing')
        wait(lambda:(work/'host/landing.png').exists(),'shared landing captured')
        command('host',kind='choose_specimen')
        wait(lambda:bool(state('host').get('chosen')),'server selects a physically visible native specimen')
        chosen=state('host')['chosen']
        for name in ['host','guest0']:
            place(name,chosen['observer']);command(name,kind='look',point=chosen['center'])
        wait(lambda:state('guest0').get('target')==chosen['id'],'guest sees and aims at same rendered creature')
        command('guest0',kind='scan',pressed=True)
        wait(lambda:len(state('guest0').get('observations',{}))>0,'host accepts sustained remote scan')
        command('guest0',kind='scan',pressed=False)
        wait(lambda:all(len(state(n).get('observations',{}))>0 for n in names),'all crew share scan knowledge')
        command('host',kind='surface_frame',name='shared-scan')
        for name in ['guest0','host']:request(name,'surface_collect',encounter_id=chosen['id'],aim=chosen['aim'])
        wait(lambda:all(len(state(n).get('specimens',{}))==1 for n in names),'simultaneous collectors produce one shared specimen')
        specimen=next(iter(state('host')['specimens']))
        wait(lambda:all(chosen['id'] not in state(n).get('ecology_actors',[]) for n in names),'collected individual disappears for all peers')
        place('host',[0,2,0]);place('guest0',[0,2,-4])
        success('host','surface_analyze',form_id=chosen['form_id'])
        before=state('host').get('edit_count',0)
        success('guest0','surface_dig',aim=[.9,-math.sqrt(.19),0])
        wait(lambda:all(state(n).get('edit_count')==before+1 and state(n).get('surface_ready') for n in names),'one host-confirmed carve rebuilds every peer collision')
        wait(lambda:len({state(n).get('terrain_hash') for n in names})==1,'all peers have identical terrain delta history')
        wait(lambda:member('guest0').get('carried')==1,'mining reward belongs to actual remote miner')
        command('guest0',kind='close');procs['guest0'].wait(timeout=10);logs['guest0'].close()
        wait(lambda:state('host').get('recovery_models')==1,'surface disconnect leaves a visible planet-owned cargo crate')
        crate_id=next(iter(state('host')['snapshot']['crew']['recovery']))
        launch('guest0');wait(lambda:state('guest0').get('active') and state('guest0').get('surface_ready'),'mid-surface reconnect restores terrain and ship spawn',90)
        assert member('guest0')['carried']==0;checks+=1
        crate=state('host')['snapshot']['crew']['recovery'][crate_id]
        assert crate['body_id']==state('host')['body_id'];checks+=1
        place('guest0',crate['position'])
        success('guest0','recover',crate_id=crate_id)
        wait(lambda:member('guest0').get('carried')==1 and state('host').get('recovery_models')==0,'recovery consumes one real crate without duplication')
        place('guest0',[0,2,4]);success('guest0','deposit',amount=1)
        for name in names:place(name,[0,2,4])
        ready_all();success('host','launch')
        wait(lambda:all(not state(n).get('surface_loaded') for n in names),'whole crew return to original 3D cabin')
        arrive(21)
        success('host','surface_restore',environment='basalt')
        success('host','surface_introduce',sample_id=specimen,aim=[0,0,-1])
        wait(lambda:all(specimen in state(n).get('introductions',{}) and specimen in state(n).get('ecology_actors',[]) for n in names),'same transported creature renders for every player on B')
        command('host',kind='surface_frame',name='shared-transplant')
        wait(lambda:(work/'host/shared-transplant.png').exists(),'shared transplant captured')
        (work/'metrics.json').write_text(json.dumps({n:{k:state(n).get(k) for k in ['surface_bytes_sent','edit_count','body_id','ecology_actors']} for n in names},indent=2))
        command('host',kind='close');procs['host'].wait(timeout=10);logs['host'].close()
        launch('host');wait(lambda:state('host').get('active') and state('host').get('surface_ready'),'landed host world resumes with persistent ecology',90)
        wait(lambda:specimen in state('host').get('introductions',{}),'host restart preserves introduced specimen identity')
        print(f'CREW_SURFACE_PLAY_CHECKS {checks} FAILURES 0 players={players}\nEvidence: {work}',flush=True)
    finally:
        for proc in procs.values():
            if proc.poll() is None:proc.terminate()
        for proc in procs.values():
            try:proc.wait(timeout=8)
            except subprocess.TimeoutExpired:proc.kill();proc.wait()
        for log in logs.values():log.close()
        errors=[]
        for path in work.glob('*/godot.log'):
            text=path.read_text()
            if 'SCRIPT ERROR' in text or 'ERROR:' in text:errors.append(path);print(path,text[-5000:])
        print('Surface artifacts:',work,flush=True)
        if errors:raise AssertionError('Godot runtime errors')
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--players',type=int,choices=[2,6],default=6)
    parser.add_argument('--render-guests',action='store_true')
    args=parser.parse_args();run(args.players,args.render_guests)
