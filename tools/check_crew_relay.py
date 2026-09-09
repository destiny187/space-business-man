#!/usr/bin/env python3
"""Focused two-process smoke check for the running native or Docker relay."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile
import time

parser = argparse.ArgumentParser()
parser.add_argument('--url', default='ws://127.0.0.1:24680/relay')
parser.add_argument('--output', type=Path)
args = parser.parse_args()
repo = Path(__file__).resolve().parents[1]
checks = []
processes = {}
logs = []

with tempfile.TemporaryDirectory(prefix='locus-relay-') as temporary:
    root = Path(temporary)

    def state(name):
        try:
            return json.loads((root/name/'status.json').read_text())
        except (FileNotFoundError, json.JSONDecodeError):
            return {}

    def command(name, **value):
        path = root/name/'command.json'
        path.with_suffix('.tmp').write_text(json.dumps(value))
        path.with_suffix('.tmp').replace(path)

    def wait(predicate, label):
        end = time.monotonic() + 20
        while time.monotonic() < end:
            if predicate():
                checks.append(label)
                print('PASS', label, flush=True)
                return
            time.sleep(.05)
        raise AssertionError(label)

    def launch(name, code=''):
        folder = root/name
        folder.mkdir(exist_ok=True)
        (folder/'status.json').unlink(missing_ok=True)
        log = (root/(name+'.log')).open('a')
        logs.append(log)
        processes[name] = subprocess.Popen([
            str(repo/'tools/godot.sh'), '--headless', '--script',
            'res://tests/test_crew_peer.gd', '--', f'--crew-folder={folder}',
            f'--crew-role={name}', f'--crew-relay={args.url}', f'--crew-code={code}'
        ], stdout=log, stderr=subprocess.STDOUT)

    try:
        launch('host')
        wait(lambda: state('host').get('active'), 'host creates invitation')
        code = state('host')['invite_code']
        launch('guest', code)
        wait(lambda: state('guest').get('active'), 'guest receives authoritative world')
        character = state('guest')['character']['character_id']
        command('guest', kind='request', action='lobby_ready', args={'value': True})
        wait(lambda: state('host').get('snapshot', {}).get('lobby_ready', {}).get(character), 'host confirms guest ready')
        command('host', kind='request', action='start_game')
        wait(lambda: state('guest').get('snapshot', {}).get('phase') == 'playing', 'host starts shared game')
        command('guest', kind='close')
        processes['guest'].wait(timeout=10)
        launch('guest', code)
        wait(lambda: state('guest').get('active'), 'same character rejoins running world')
        assert state('guest')['character']['character_id'] == character
        assert len(state('guest')['snapshot']['crew']['members']) == 2
        command('host', kind='close')
        processes['host'].wait(timeout=10)
        wait(lambda: not state('guest').get('active', True), 'host close ends guest session')
        command('guest', kind='close')
        processes['guest'].wait(timeout=10)
        for log in logs:
            log.flush()
        for path in root.glob('*.log'):
            text = path.read_text()
            if 'SCRIPT ERROR' in text or '\nERROR:' in text:
                raise AssertionError(text)
        if args.output:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(json.dumps({'checks': checks, 'result': 'passed', 'scope': 'localhost two Godot processes; no internet/6-player performance claim'}, ensure_ascii=False, indent=2)+'\n')
    except Exception:
        for path in root.glob('*.log'):
            print(path.name, path.read_text()[-6000:])
        raise
    finally:
        for process in processes.values():
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
        for log in logs:
            log.close()
