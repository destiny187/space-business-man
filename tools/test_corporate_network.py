#!/usr/bin/env python3
"""Bounded corporate ENet flows; isolated profiles/worlds, no production saves."""
import json
import pathlib
import socket
import subprocess
import tempfile
import time
import argparse
import shutil

ROOT = pathlib.Path(__file__).resolve().parents[1]

def run():
    parser=argparse.ArgumentParser()
    parser.add_argument("--resume-ground", type=pathlib.Path, help="Copy a prior isolated run and check only the unfinished ground/reload flow")
    resume=parser.parse_args().resume_ground
    checks = 0
    processes = {}
    logs = {}
    workspace = pathlib.Path(tempfile.mkdtemp(prefix='locus-corporate-'))
    if resume:
        for name in ['host','guest0','guest1']:
            (workspace/name).mkdir()
            for file in ['world.json','profile.json']:
                if (resume/name/file).exists():shutil.copy2(resume/name/file,workspace/name/file)
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
        probe.bind(('127.0.0.1', 0))
        port = probe.getsockname()[1]

    def launch(name):
        folder = workspace / name
        folder.mkdir(exist_ok=True)
        (folder / 'status.json').unlink(missing_ok=True)
        logs[name] = open(folder / 'godot.log', 'a')
        processes[name] = subprocess.Popen([
            str(ROOT / 'tools/godot.sh'), '--headless', '--script',
            'res://tests/test_corporate_network_peer.gd', '--', f'--crew-folder={folder}',
            f'--crew-role={name}', f'--crew-port={port}'
        ], stdout=logs[name], stderr=subprocess.STDOUT)

    def state(name):
        try:
            return json.loads((workspace / name / 'status.json').read_text())
        except (FileNotFoundError, json.JSONDecodeError):
            return {}

    def wait(predicate, label, timeout=15):
        nonlocal checks
        end = time.monotonic() + timeout
        while time.monotonic() < end:
            if predicate():
                checks += 1
                print('PASS', label, flush=True)
                return
            time.sleep(.05)
        raise AssertionError(label)

    def command(name, payload):
        folder = workspace / name
        end = time.monotonic()+5
        while (folder/'command.json').exists():
            if time.monotonic()>end:raise AssertionError('previous network command was not consumed')
            time.sleep(.02)
        temporary = folder / 'command.tmp'
        temporary.write_text(json.dumps(payload))
        temporary.replace(folder / 'command.json')

    def request(name, action, args):
        command(name, dict(kind='request', action=action, args=args))

    def member(name):
        s = state(name).get('snapshot', {})
        return s.get('crew', {}).get('members', {}).get(s.get('self_id'), {})

    def snapshot(name):
        return state(name).get('snapshot', {})

    def stage(name, event):
        return snapshot(name).get('crew', {}).get('freight_records', {}).get(event, {}).get('stage', 0)

    def hold(name, event, value=True):
        command(name, dict(kind='hold', id=event, value=value))

    def fixture(event, distance, pilot):
        old = state('host').get('fixture_serial', 0)
        command('host', dict(kind='fixture', id=event, distance=distance, pilot=pilot))
        wait(lambda: state('host').get('fixture_serial', 0)>old, 'approach '+event)

    def complete(event, value, actor='guest0', timeout=15):
        hold(actor, event)
        wait(lambda: all(stage(n,event)==value for n in ['host','guest0','guest1']), f'{event} shared stage {value}', timeout)
        hold(actor,event,False)

    try:
        launch('host')
        wait(lambda: state('host').get('active'), 'host opens durable corporate world')
        for name in ['guest0','guest1']:
            launch(name)
            wait(lambda n=name: state(n).get('active'), name+' token handshake')
            request(name,'lobby_ready',{'value': True})
            wait(lambda n=name: snapshot(n).get('lobby_ready',{}).get(snapshot(n).get('self_id')), name+' ready')
        request('host','start_game',{})
        wait(lambda: snapshot('guest1').get('phase')=='playing', 'three ENet processes enter expedition')
        pilot=state('guest0')['character']['character_id']
        if not resume:
            freight='freight-v1:0'
            fixture(freight,1800,pilot)
            hold('guest1',freight)
            complete(freight,1)
            hold('guest1',freight,False)
            fixture(freight,180,pilot)
            hold('guest1',freight)
            wait(lambda: '조종사' in snapshot('guest1').get('scan',{}).get('reason',''), 'remote passenger cannot operate cargo rig')
            hold('guest1',freight,False)
            hold('guest0',freight)
            wait(lambda: any(a.get('progress',0)>.15 for a in snapshot('guest1').get('freight_activity',[])), 'another client sees actual held transfer progress')
            processes['guest0'].kill();processes['guest0'].wait();logs['guest0'].close()
            wait(lambda: not snapshot('host').get('freight_activity'), 'expired remote input cancels transfer before completion')
            assert stage('host',freight)==1
            wait(lambda: pilot not in snapshot('host').get('crew',{}).get('members',{}), 'abrupt disconnect detected', 40)
            launch('guest0');wait(lambda: state('guest0').get('active'), 'token reconnect after interrupted transfer')
            assert state('guest0')['character']['character_id']==pilot and stage('guest0',freight)==1
            fixture(freight,180,pilot);complete(freight,2)
            wait(lambda: all(snapshot(n)['crew']['freight_records'][freight]['carrier']=='crew' for n in ['host','guest0','guest1']), 'one shared pod belongs to actual vessel on all clients')
            command('guest0',{'kind':'close'});processes['guest0'].wait(timeout=10);logs['guest0'].close()
            launch('guest0');wait(lambda: state('guest0').get('active') and stage('guest0',freight)==2, 'loaded cargo survives reconnect')
            fixture(freight,350,pilot);complete(freight,3)
            starting=snapshot('host')['shared_credits']-350
            wait(lambda: all(snapshot(n).get('shared_credits')==starting+350 for n in ['host','guest0','guest1']), 'one delivery payment replicated')
            service='service-v1:702'
            fixture(service,500,pilot);complete(service,1)
            fixture(service,180,pilot);complete(service,2)
            fixture(service,300,pilot);complete(service,3)
            assert snapshot('host')['shared_credits']==starting+350
            complete(service,4)
            wait(lambda: all(snapshot(n).get('shared_credits')==starting+850 for n in ['host','guest0','guest1']), 'repair pays only on saved restart')
            trace='trace:corp_2805_0'
            fixture(trace,350,pilot);hold('guest0',trace)
            wait(lambda: all(trace in snapshot(n).get('coopertech_clues',{}) for n in ['host','guest0','guest1']), 'orbital evidence publishes same ground clue to crew',25)
            hold('guest0',trace,False)
            clues=[snapshot(n)['coopertech_clues'][trace] for n in ['host','guest0','guest1']]
            assert len({c['incident'] for c in clues})==1
        else:
            freight='freight-v1:0';service='service-v1:702';trace='trace:corp_2805_0'
            starting=snapshot('host')['shared_credits']-850
            wait(lambda: all(trace in snapshot(n).get('coopertech_clues',{}) for n in ['host','guest0','guest1']), 'resume persisted orbital clue on all clients')
            clues=[snapshot(n)['coopertech_clues'][trace] for n in ['host','guest0','guest1']]
        old=state('host')['fixture_serial']
        command('host',dict(kind='ground',id=trace,actor=pilot))
        wait(lambda: state('host').get('fixture_serial',0)>old and clues[0]['incident'] in snapshot('guest0').get('incidents',{}).get('records',{}), 'actual linked ground robot reaches remote actor')
        wait(lambda: snapshot('guest1')['coopertech_clues'][trace]['stage']==1, 'remote ground approach updates shared discovery')
        for _ in range(12):
            row=snapshot('guest0')['incidents']['records'][clues[0]['incident']]
            if row['hp']<=0:break
            old_count=len(state('guest0').get('responses',[]))
            command('guest0',dict(kind='attack'))
            wait(lambda: len(state('guest0').get('responses',[]))>old_count, 'remote weapon request processed')
            result=state('guest0')['responses'][-1]['result']
            assert result.get('ok'), result
            time.sleep(.7)
        assert snapshot('guest0')['incidents']['records'][clues[0]['incident']]['hp']<=0
        command('guest0',dict(kind='attack',cargo=True))
        wait(lambda: all(snapshot(n)['coopertech_clues'][trace]['stage']==2 for n in ['host','guest0','guest1']), 'real remote recovery closes same clue for everyone')
        command('host',{'kind':'close'});processes['host'].wait(timeout=12);logs['host'].close()
        saved=json.loads((workspace/'host/world.json').read_text())
        assert saved['crew']['freight_records'][freight]['stage']==3 and saved['crew']['freight_records'][service]['stage']==4
        assert saved['incidents']['records'][clues[0]['incident']]['claimed'] and saved['business']['credits']==starting+850
        launch('host');wait(lambda: state('host').get('active'), 'host reloads completed world')
        assert snapshot('host')['coopertech_clues'][trace]['stage']==2 and stage('host',service)==4 and stage('host',freight)==3
        checks+=6
        print(f'CORPORATE_NETWORK_CHECKS {checks} FAILURES 0\nEvidence: {workspace}',flush=True)
    finally:
        for process in processes.values():
            if process.poll() is None:
                process.terminate()
        for process in processes.values():
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
        for handle in logs.values():
            if not handle.closed:
                handle.close()
        engine_errors = False
        for path in workspace.glob('*/godot.log'):
            text = path.read_text()
            if 'SCRIPT ERROR' in text or 'ERROR:' in text:
                engine_errors = True
                print(path, text[-4000:])
        print('Network artifacts:', workspace)
        if engine_errors:
            raise AssertionError('Godot reported runtime errors')

if __name__ == '__main__':
    run()
