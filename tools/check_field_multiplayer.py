#!/usr/bin/env python3
"""Three rendered ENet processes; camera-local culling, late join and excavation."""
import argparse
import json
import math
from pathlib import Path
import shutil
import socket
import subprocess
import time

parser = argparse.ArgumentParser()
parser.add_argument('--runtime', type=Path, required=True, help='Isolated committed runtime, including host save fixture')
parser.add_argument('--revision', default='unspecified', help='Commit checked out in the isolated runtime')
args = parser.parse_args()
runtime = args.runtime.resolve()
repo = Path(__file__).resolve().parents[1]
shutil.copy2(repo/'우주-비즈니스/tests/check_field_visibility_peer.gd', runtime/'우주-비즈니스/tests/check_field_visibility_peer.gd')
processes, logs, checks, evidence = {}, {}, [], {}
with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
    sock.bind(('127.0.0.1', 0)); port = sock.getsockname()[1]

def state(name):
    try: return json.loads((runtime/name/'status.json').read_text())
    except (FileNotFoundError, json.JSONDecodeError): return {}

def command(peer_name, **value):
    path = runtime/peer_name/'command.json'
    end = time.monotonic()+10
    while path.exists():
        if time.monotonic()>end: raise AssertionError('command not consumed: '+peer_name)
        time.sleep(.05)
    path.with_suffix('.tmp').write_text(json.dumps(value))
    path.with_suffix('.tmp').replace(path)

def wait(predicate, label, timeout=60):
    end = time.monotonic()+timeout
    while time.monotonic()<end:
        if predicate(): checks.append(label); print('PASS',label,flush=True); return
        for name, proc in processes.items():
            if proc.poll() is not None: raise AssertionError(f'{name} exited before {label}: {proc.returncode}')
        time.sleep(.1)
    raise AssertionError(label)

def launch(name):
    folder = runtime/name; folder.mkdir(exist_ok=True)
    (folder/'status.json').unlink(missing_ok=True)
    (folder/'command.json').unlink(missing_ok=True)
    logs[name] = (folder/'godot.log').open('a')
    cmd = [str(runtime/'tools/godot.sh'), '--position', '20,60', '--script', 'res://tests/check_field_visibility_peer.gd', '--', '--crew-ui-test', f'--crew-folder={folder}',f'--crew-role={name}',f'--crew-port={port}']
    processes[name] = subprocess.Popen(cmd, stdout=logs[name], stderr=subprocess.STDOUT)

def request(name, action, **params):
    for attempt in range(8):
        before = len(state(name).get('responses', []))
        command(name, kind='request', action=action, args=params)
        wait(lambda:len(state(name).get('responses',[]))>before, name+' response '+action)
        result = state(name)['responses'][-1]['result']
        if result.get('ok'): return
        if '세계 상태가 바뀌' not in result.get('error',''): raise AssertionError((action,result))
        time.sleep(.3)
    raise AssertionError('stale revision: '+action)

def ready(name):
    s=state(name)
    return s.get('surface_ready') and not s.get('arrival',True) and s.get('snapshot',{}).get('phase')=='playing'

def observed(name): return state(name).get('watched',{})
def capture(name, label):
    (runtime/name/(label+'.png')).unlink(missing_ok=True)
    command(name,kind='capture_now',name=label)
    wait(lambda:(runtime/name/(label+'.png')).exists(), name+' capture '+label)
    evidence[name+'-'+label]=state(name)

error = None
try:
    launch('host');wait(lambda:state('host').get('active'),'host opens committed field save')
    launch('guest0');wait(lambda:state('guest0').get('active'),'first rendered guest joins ENet')
    request('guest0','lobby_ready',value=True)
    request('host','start_game')
    wait(lambda:all(ready(n) for n in processes),'both clients finish actual field loading',180)
    for n in processes:command(n,kind='prepare')
    wait(lambda:all(state(n).get('occlusion') and not state(n).get('disable_3d') and state(n).get('draw_calls',0)>0 for n in processes),'both clients render with local occlusion')
    wait(lambda:bool(set(state('host').get('articulated',[])) & set(state('guest0').get('creatures',{}))),'shared articulated creature exists')
    common=set(state('host')['articulated']) & set(state('guest0')['creatures'])
    target=min(common,key=lambda k:math.dist(state('host')['creatures'][k],[0,0,0]))
    for n in processes:command(n,kind='watch',id=target)
    wait(lambda:all(observed(n).get('visible') for n in processes),'same creature visible in both cameras')
    command('host',kind='turn')
    wait(lambda:not observed('host').get('visible',True) and observed('guest0').get('visible'),'host looking away does not hide guest creature')
    time.sleep(.4)
    old={n:observed(n) for n in processes}
    time.sleep(.8)
    assert observed('host')['pose']==old['host']['pose'] and observed('host')['clock']>old['host']['clock']
    assert observed('guest0')['pose']!=old['guest0']['pose']
    checks.append('hidden host pose sleeps while visible guest pose and both clocks advance')
    command('host',kind='turn')
    wait(lambda:observed('host').get('visible') and observed('host')['pose']!=old['host']['pose'],'host camera return restores current pose')
    for n in processes:command(n,kind='cover',enabled=True)
    command('guest0',kind='watch',id=target,back=True)
    wait(lambda:not observed('host').get('visible',True) and observed('guest0').get('visible'),'same local cover hides front camera but leaves back camera visible')
    capture('host','covered');capture('guest0','visible-behind-cover')
    launch('guest1');wait(lambda:state('guest1').get('active') and ready('guest1'),'third rendered client joins running field',180)
    command('guest1',kind='prepare');command('guest1',kind='watch',id=target)
    wait(lambda:observed('guest1').get('visible') and not observed('host').get('visible',True),'late client renders independently of hidden host')
    capture('guest1','late-join')
    guest_id=state('guest0')['snapshot']['self_id']
    initial=state('host')['positions'][guest_id]
    command('guest0',kind='move_world',direction=[.5,0])
    wait(lambda:math.dist(state('host')['positions'][guest_id],initial)>1,'remote input still moves host collision body')
    command('guest0',kind='move_world',direction=[0,0])
    wait(lambda:math.dist(state('host')['positions'][guest_id],state('guest0')['positions'][guest_id])<.6,'moving client reconciles to host while cameras differ')
    for n in ['host','guest0']:command(n,kind='cover',enabled=False)
    command('host',kind='watch',id=target)
    wait(lambda:observed('host').get('visible'),'removing cover restores rendering')
    command('host',kind='equip_dig_fixture',id=guest_id)
    wait(lambda:state('guest0')['snapshot']['crew']['members'][guest_id]['loadout']['selected']==1,'guest receives host-approved excavation fixture')
    before=state('host')['edit_count']
    request('guest0','surface_dig',aim=[.8,-.6,0])
    wait(lambda:all(state(n).get('edit_count')==before+1 and state(n).get('surface_ready') for n in processes),'guest excavation reaches all three render/collision worlds',90)
    wait(lambda:len({state(n).get('terrain_hash') for n in processes})==1 and all(state(n).get('occluders_paired') for n in processes),'all three peers have matching edits and current occluders')
    capture('host','after-dig');capture('guest0','after-dig');capture('guest1','after-dig')
    command('guest1',kind='close');processes['guest1'].wait(timeout=30);logs['guest1'].close();del processes['guest1']
    launch('guest1');wait(lambda:state('guest1').get('active') and ready('guest1'),'third client reconnects after excavation',180)
    wait(lambda:state('guest1').get('terrain_hash')==state('host').get('terrain_hash') and state('guest1').get('occluders_paired'),'reconnected client restores latest terrain and occlusion')
    command('guest1',kind='prepare');command('guest1',kind='watch',id=target)
    wait(lambda:observed('guest1').get('visible'),'reconnected camera restores creature animation')
    capture('guest1','reconnected')
except Exception as exc:
    error=repr(exc);evidence['failure']={n:state(n) for n in processes};print('FAIL',error,flush=True)
finally:
    for name in list(processes):
        proc=processes[name]
        if proc.poll() is None:
            try:command(name,kind='close');proc.wait(timeout=30)
            except Exception:proc.terminate()
        try:proc.wait(timeout=8)
        except subprocess.TimeoutExpired:proc.kill();proc.wait()
        if not logs[name].closed:logs[name].close()
    runtime_errors=[]
    for path in runtime.glob('*/godot.log'):
        runtime_errors.extend(str(path)+': '+line for line in path.read_text().splitlines() if 'SCRIPT ERROR' in line or 'ERROR:' in line)
    result={'revision':args.revision,'scope':'Three actual Metal Forward+ processes over local ENet, 1280x800 medium at 30 FPS cap. Synthetic opaque cover isolates occlusion; creatures, movement, excavation and session are real game paths. Not three independent devices, six players or internet latency.','checks':checks,'error':error,'runtime_errors':runtime_errors,'evidence':evidence,'workspace':str(runtime)}
    (runtime/'multiplayer-result.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print('MULTIPLAYER',len(checks),'checks',len(runtime_errors),'runtime errors','workspace',runtime,flush=True)
    if error or runtime_errors:raise SystemExit(1)
