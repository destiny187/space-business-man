#!/usr/bin/env python3
"""Six real game scenes over ENet: visible host, five headless participants."""
import json
import pathlib
import socket
import subprocess
import tempfile
import time
ROOT = pathlib.Path(__file__).resolve().parents[1]

def run():
    workspace = pathlib.Path(tempfile.mkdtemp(prefix='locus-crew-play-'))
    processes, logs = {}, {}
    checks = 0
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.bind(('127.0.0.1', 0))
        port = sock.getsockname()[1]
    def launch(name):
        folder = workspace / name
        folder.mkdir(exist_ok=True)
        (folder/'status.json').unlink(missing_ok=True)
        logs[name] = open(folder / 'godot.log', 'w')
        cmd = [str(ROOT/'tools/godot.sh')]
        if name != 'host':
            cmd.append('--headless')
        cmd += ['--script', 'res://tests/test_crew_play_peer.gd', '--', '--crew-ui-test',
                f'--crew-folder={folder}', f'--crew-role={name}', f'--crew-port={port}']
        processes[name] = subprocess.Popen(cmd, stdout=logs[name], stderr=subprocess.STDOUT)
    def state(name):
        try:
            return json.loads((workspace/name/'status.json').read_text())
        except (FileNotFoundError, json.JSONDecodeError):
            return {}
    def wait(predicate, label, timeout=35):
        nonlocal checks
        end = time.monotonic()+timeout
        while time.monotonic()<end:
            if predicate():
                checks += 1
                print('PASS', label, flush=True)
                return
            time.sleep(.05)
        raise AssertionError(label)
    def command(name, **value):
        folder=workspace/name
        end = time.monotonic()+5
        while (folder/'command.json').exists():
            if time.monotonic()>end:raise AssertionError('previous game command was not consumed')
            time.sleep(.02)
        (folder/'command.tmp').write_text(json.dumps(value))
        (folder/'command.tmp').replace(folder/'command.json')
    def request(name, action, **args):
        command(name, kind='request', action=action, args=args)
    def member(name):
        snapshot=state(name).get('snapshot',{})
        return snapshot.get('crew',{}).get('members',{}).get(snapshot.get('self_id'),{})
    try:
        launch('host')
        wait(lambda: state('host').get('active'), 'visible host game starts')
        for i in range(5):
            name=f'guest{i}'
            launch(name)
            wait(lambda n=name: state(n).get('active'), f'{name} joins actual scene')
        wait(lambda: state('host').get('actors') == 6 and state('guest4').get('actors') == 6,
             'six actual rendered actor instances match')
        origin=member('guest0')['position']
        command('guest0', kind='move', direction=[0,-1])
        wait(lambda: member('guest0')['position'][2] < origin[2]-4, 'remote walking advances host collision body')
        command('guest0', kind='move', direction=[0,0])
        command('guest1', kind='move', direction=[1,0])
        wait(lambda: member('guest1')['position'][0] > 3, 'second player independently moves')
        time.sleep(1)
        assert member('guest1')['position'][0] < 3.6
        checks += 1
        command('guest1', kind='move', direction=[0,0])
        command('host', kind='capture', outside=False)
        wait(lambda: (workspace/'host/cabin.png').exists(), 'actual cabin frame captured')
        request('guest4', 'withdraw', amount=1)
        wait(lambda: member('guest4').get('carried')==1, 'actual crew takes shared cargo before leaving')
        departing_id=state('guest4')['snapshot']['self_id']
        command('host', kind='kick', character_id=departing_id)
        wait(lambda: state('host').get('actors')==5 and state('host').get('recovery_models')==1,
             'disconnected cargo becomes a visible crate')
        command('host', kind='move', direction=[0,1])
        wait(lambda: member('host')['position'][2]>7.0,'host walks around the locker to inspect recovered cargo')
        command('host', kind='move', direction=[0,0])
        command('host', kind='move', direction=[1,0])
        wait(lambda: member('host')['position'][0]>1.4,'host reaches an unobstructed view of the recovery crate')
        command('host', kind='move', direction=[0,0])
        command('host', kind='capture', outside=False, view='recovery')
        wait(lambda: (workspace/'host/recovery.png').exists(), 'physical recovery crate captured')
        processes['guest4'].terminate();processes['guest4'].wait(timeout=5);logs['guest4'].close()
        launch('guest4')
        wait(lambda: state('guest4').get('active'), 'kicked character can rejoin an available seat')
        assert member('guest4')['carried']==0
        checks += 1
        crate_id=next(iter(state('guest4')['snapshot']['crew']['recovery']))
        request('guest4','recover',crate_id=crate_id)
        wait(lambda: member('guest4').get('carried')==1 and state('host').get('recovery_models')==0,
             'physical crate disappears only after durable recovery')
        request('guest4','deposit',amount=1)
        wait(lambda: state('host')['snapshot']['crew']['rock']==24,'recovered cargo conserves shared total')
        request('host', 'navigate', ordinal=999999)
        wait(lambda: state('guest4')['snapshot']['crew']['navigation']['target'] == 999999, 'millionth destination shared')
        request('host', 'depart')
        wait(lambda: any('모두 승선' in r['result'].get('error','') for r in state('host')['responses']), 'departure blocked until everyone ready')
        for name in processes:
            request(name, 'ready', value=True)
            wait(lambda n=name: member(n).get('ready'), f'{name} confirms departure')
        request('host', 'depart')
        wait(lambda: state('guest4')['snapshot']['crew']['navigation']['mode'] == 'jump', 'all six enter same jump')
        wait(lambda: state('guest4')['snapshot']['crew']['navigation']['system'] == 249999, 'all six reach final star system')
        command('host', kind='capture', outside=True)
        wait(lambda: (workspace/'host/exterior.png').exists(), 'moving shared vessel captured')
        wait(lambda: state('host')['snapshot']['crew']['navigation']['mode'] == 'idle', 'shared ship physically approaches chosen planet', timeout=65)
        target=state('host')['snapshot']['location']
        wait(lambda: all(state(n)['snapshot']['location']==target for n in processes), 'arrival location identical for every participant')
        command('host', kind='close')
        processes['host'].wait(timeout=10)
        print(f'CREW_PLAY_CHECKS {checks} FAILURES 0\nEvidence: {workspace}',flush=True)
    finally:
        for process in processes.values():
            if process.poll() is None:process.terminate()
        for process in processes.values():
            try:process.wait(timeout=5)
            except subprocess.TimeoutExpired:process.kill();process.wait()
        for handle in logs.values():handle.close()
        engine_errors = False
        for path in workspace.glob('*/godot.log'):
            text=path.read_text()
            if 'SCRIPT ERROR' in text or 'ERROR:' in text:
                engine_errors = True
                print(path,text[-5000:])
        print('Play artifacts:',workspace)
        if engine_errors:
            raise AssertionError('Godot reported runtime errors')
if __name__=='__main__':run()
