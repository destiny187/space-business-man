#!/usr/bin/env python3
"""Real ENet processes; isolated profiles/worlds, no production saves."""
import json
import pathlib
import socket
import subprocess
import tempfile
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]

def run():
    checks = 0
    processes = {}
    logs = {}
    workspace = pathlib.Path(tempfile.mkdtemp(prefix='locus-crew-'))
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
            'res://tests/test_crew_peer.gd', '--', f'--crew-folder={folder}',
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

    try:
        launch('host')
        wait(lambda: state('host').get('active'), 'host opens durable world')
        originals = {}
        for i in range(5):
            name = f'guest{i}'
            launch(name)
            wait(lambda n=name: state(n).get('active'), f'{name} handshake and token ACK')
            originals[name] = state(name)['character']
        wait(lambda: len(state('host')['snapshot']['crew']['members']) == 6,
             'six separate processes share host world')
        launch('seventh')
        wait(lambda: any('최대 6명' in message for message in state('seventh').get('messages', [])),
             'seventh process explicitly rejected')
        assert not state('seventh').get('active')
        request('guest0', 'withdraw', {'amount': 1})
        wait(lambda: member('guest0').get('carried') == 1, 'guest withdraw commits on host')
        wait(lambda: state('guest4')['snapshot']['crew']['rock'] == 23, 'other clients observe same cargo')
        processes['guest0'].kill()
        processes['guest0'].wait()
        logs['guest0'].close()
        wait(lambda: len(state('host')['snapshot']['crew']['members']) == 5,
             'abrupt disconnect detected', timeout=35)
        wait(lambda: len(state('host')['saved']['recovery']) == 1 and state('host')['slots'] == 6,
             'cargo recovery and reserved slot persist')
        launch('guest0')
        wait(lambda: state('guest0').get('active'), 'capability reconnect reclaims full session slot')
        assert state('guest0')['character'] == originals['guest0']
        assert member('guest0')['carried'] == 0
        assert all('capability_hash' not in record for record in state('guest4')['snapshot']['crew']['members'].values())
        checks += 3
        request('guest0', 'ready', {'value': True})
        wait(lambda: member('guest0').get('ready'), 'reconnected guest can act')
        command('host', {'kind': 'kick', 'character_id': originals['guest4']['character_id']})
        wait(lambda: any('참가를 종료' in message for message in state('guest4').get('messages', [])),
             'host kick reaches the selected participant')
        wait(lambda: len(state('host')['snapshot']['crew']['members']) == 5 and state('host')['slots'] == 5,
             'kick releases the seat without a reconnect reservation')
        command('host', {'kind': 'close'})
        wait(lambda: any('저장하고 종료' in message for message in state('guest1').get('messages', [])),
             'normal host shutdown reaches clients')
        processes['host'].wait(timeout=10)
        for name, original in originals.items():
            assert json.loads((workspace / name / 'profile.json').read_text())['character'] == original
            checks += 1
        world = json.loads((workspace / 'host/world.json').read_text())
        assert world['crew']['rock'] == 23 and sum(c['rock'] for c in world['crew']['recovery'].values()) == 1
        checks += 1
        print(f'CREW_NETWORK_CHECKS {checks} FAILURES 0\nEvidence: {workspace}', flush=True)
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
