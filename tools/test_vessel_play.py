#!/usr/bin/env python3
"""Expedition industry using actual game scenes and independent ENet processes."""
import argparse
import json
import math
from pathlib import Path
import socket
import subprocess
import tempfile
import time
ROOT = Path(__file__).resolve().parents[1]

def run(players=2, render_guests=False):
    work = Path(tempfile.mkdtemp(prefix='locus-vessel-play-'))
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
        cmd += ['--script','res://tests/test_vessel_peer.gd','--','--crew-ui-test',f'--crew-folder={folder}',f'--crew-role={name}',f'--crew-port={port}']
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
    def business(name='host'):return state(name).get('business',{})
    def site(name='host'):return business(name).get('sites',{}).get(state(name).get('body_id'),{})
    def near_base(name):
        point=site()['center'];place(name,[point[0]+4,point[1],point[2]])
    try:
        for name in names:
            launch(name);wait(lambda n=name:state(n).get('active'),name+' joined')
        arrive(15)
        success('host','business_register')
        wait(lambda:all(site(n).get('state')=='active' for n in names),'shared active business')
        near_base('host')
        for resource,count in {'iron':5,'copper':3}.items():
            for _ in range(count):success('host','business_supply',resource=resource)
        def ship_action(button, **args):
            count=len(state('host').get('responses',[]))
            command('host',kind='ship_action',button=button,**args)
            wait(lambda:len(state('host').get('responses',[]))>count,'actual shipyard button '+str(button))
            result=state('host')['responses'][-1]['result']
            assert result.get('ok'),result
        def vessel(name='host'):return state(name).get('snapshot',{}).get('vessel',{})
        for kind in ['drive','lab']:
            ship_action(0,module_type=kind)
            wait(lambda:len(vessel().get('modules',{}))>= (1 if kind=='drive' else 2),'created module '+kind)
            mid=next(k for k,v in vessel()['modules'].items() if v['type']==kind)
            wait(lambda:mid in vessel('guest0').get('modules',{}),'guest inventory '+kind)
            ship_action(2,module_id=mid)
        wait(lambda:all(len(state(n).get('surface_modules',[]))==2 and len(state(n).get('flight_modules',[]))==2 for n in names),'all players render both modules on ground and flight ship')
        ship_action(1,module_type='cargo')
        wait(lambda:all(vessel(n).get('draws')==1 for n in names),'one paid draw shared by all peers')
        command('host',kind='resize',width=960,height=640)
        command('host',kind='surface_frame',name='shipyard-960')
        wait(lambda:(work/'host/shipyard-960.png').exists(),'960x640 shipyard capture')
        command('host',kind='resize',width=1280,height=800)
        command('host',kind='ship_surface_frame')
        command('host',kind='surface_frame',name='mounted-surface')
        wait(lambda:(work/'host/mounted-surface.png').exists(),'mounted ship on real terrain')
        for name in names:near_base(name)
        ready_all();success('host','launch')
        wait(lambda:all(not state(n).get('surface_loaded') for n in names),'full crew launch with refits')
        command('host',kind='capture',outside=True)
        wait(lambda:(work/'host/exterior.png').exists(),'refitted ship in actual 3D flight')
        expected=vessel()
        command('host',kind='close');procs['host'].wait(timeout=10);logs['host'].close()
        launch('host');wait(lambda:state('host').get('active'),'host restarts saved ship',90)
        wait(lambda:vessel()==expected,'saved modules draw and parts persist')
        print(f'VESSEL_PLAY_CHECKS {checks} FAILURES 0 players={players}\nEvidence: {work}',flush=True)
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
    parser=argparse.ArgumentParser();parser.add_argument('--players',type=int,choices=range(2,7),default=2);parser.add_argument('--render-guests',action='store_true')
    args=parser.parse_args();run(args.players,args.render_guests)
