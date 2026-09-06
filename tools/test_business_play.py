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
    work = Path(tempfile.mkdtemp(prefix='locus-business-play-'))
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
        cmd += ['--script','res://tests/test_business_peer.gd','--','--crew-ui-test',f'--crew-folder={folder}',f'--crew-role={name}',f'--crew-port={port}']
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
    def build(kind):
        token=time.monotonic_ns()
        command('host',kind='prepare_build',building=kind,token=token)
        wait(lambda:state('host').get('build_spot',{}).get('token')==token,'find safe construction '+kind)
        spot=state('host')['build_spot'];place('host',spot['stand'])
        command('host',kind='look',point=[spot['position'][0],spot['position'][1]-.3,spot['position'][2]])
        command('host',kind='begin_build',building=kind)
        wait(lambda:state('host').get('placement_valid'),'actual 3D placement ghost valid: '+kind)
        before=len(site().get('buildings',{}));command('host',kind='click_build')
        wait(lambda:len(site().get('buildings',{}))==before+1,'click confirms '+kind)
        wait(lambda:all(len(site(n).get('buildings',{}))==before+1 for n in names),'remote sees same '+kind)
        return list(site()['buildings'])[-1]
    def advance(count=100):
        old=site().get('time',0);command('host',kind='industry_ticks',count=count)
        wait(lambda:site().get('time',0)>=old+count,'host advances industry '+str(count))
    try:
        for name in names:
            launch(name);wait(lambda n=name:state(n).get('active'),name+' joined')
        arrive(15)
        success('host','business_register')
        wait(lambda:all(site(n).get('state')=='active' for n in names),'free development registration shared')
        assert sum(site()['inventory'].values())==0;checks+=1
        command('host',kind='business_menu');wait(lambda:state('host')['business_menu'],'business menu opens')
        command('host',kind='surface_frame',name='business-menu')
        wait(lambda:(work/'host/business-menu.png').exists(),'business menu captured')
        command('host',kind='business_menu')
        wait(lambda:'vein:0' in state('guest0').get('business_models',[]),'authored vein model exists on guest')
        point=state('guest0')['business_model_positions']['vein:0'];observer=[point[0],point[1],point[2]+3]
        place('guest0',observer);command('guest0',kind='look',point=[point[0],point[1]+1,point[2]])
        wait(lambda:state('guest0').get('business_target',{}).get('id')=='vein:0','guest aims at physical ore')
        command('guest0',kind='interact')
        wait(lambda:sum(business('guest0').get('bags',{}).get(state('guest0')['snapshot']['self_id'],{}).values())==16,'F mines into actual player bag')
        before=site()['remaining']['vein:0']
        command('guest0',kind='close');procs['guest0'].wait(timeout=10);logs['guest0'].close()
        wait(lambda:len(business().get('crates',{}))==1,'disconnect preserves business cargo in real crate')
        launch('guest0');wait(lambda:state('guest0').get('surface_ready') and len(business('guest0').get('crates',{}))==1,'rejoin receives same business crate',90)
        crate_id=next(iter(business()['crates']));place('guest0',business()['crates'][crate_id]['position'])
        success('guest0','business_recover_crate',crate_id=crate_id)
        near_base('guest0');success('guest0','business_deposit')
        wait(lambda:site()['inventory']['iron']==16 and site()['remaining']['vein:0']==before,'recovery and deposit conserve ore')
        # Material purchases use the real finite startup budget; domain suite mines the complete route.
        near_base('host')
        for resource,count in {'copper':8,'stone':7,'ice':9}.items():
            for _ in range(count):success('host','business_supply',resource=resource)
        for vein_id in ['vein:0','vein:4','vein:8','vein:12','vein:15','vein:17']:
            point=state('host').get('business_model_positions',{}).get(vein_id)
            if point is None:continue
            while site()['inventory']['iron']<430 and site()['remaining'][vein_id]>0:
                place('host',[point[0],point[1],point[2]+2])
                success('host','business_mine',vein_id=vein_id)
                near_base('host');success('host','business_deposit');time.sleep(.55)
            if site()['inventory']['iron']>=430:break
        assert site()['inventory']['iron']>=430;checks+=1
        for technology in ['robotics','atmosphere','thermal','water','biotech','recovery']:
            success('host','business_technology',technology=technology)
        solar=build('solar');charger=build('charger');factory=build('factory')
        place('host',[site()['buildings'][factory]['position'][0],site()['buildings'][factory]['position'][1],site()['buildings'][factory]['position'][2]+4])
        success('host','business_craft',building_id=factory)
        advance(20)
        wait(lambda:len(site().get('robots',{}))==1 and len(site('guest0').get('robots',{}))==1,'paid fabrication produces same robot')
        robot_id=next(iter(site()['robots']))
        target=next(key for key,count in site()['remaining'].items() if count>48 and key in state('host')['business_model_positions'])
        success('host','business_assign',robot_id=robot_id,vein_id=target)
        old=site()['delivered']
        for _ in range(3):
            advance(60)
            if site()['delivered']>old:break
        wait(lambda:site()['delivered']>old,'visible robot delivers finite ore')
        for kind in ['solar','solar','atmosphere','thermal','water','biolab']:build(kind)
        command('host',kind='business_overview');command('host',kind='surface_frame',name='industry-before')
        wait(lambda:(work/'host/industry-before.png').exists(),'active facility site captured')
        for _ in range(5):advance(100)
        wait(lambda:all(site(n).get('environment',{}).get('ecology',0)>=20 for n in names),'same environment improves for both peers')
        command('host',kind='surface_frame',name='industry-restored')
        wait(lambda:(work/'host/industry-restored.png').exists(),'managed soil improvement captured')
        command('host',kind='reset_camera');near_base('host')
        credits=business()['credits'];success('host','business_settle')
        wait(lambda:all(site(n).get('state')=='settled' and business(n)['credits']>credits for n in names),'one restoration payment shared')
        expected=business()['credits'];success('guest0','ready',value=True)
        command('host',kind='close');procs['host'].wait(timeout=10);logs['host'].close()
        launch('host');wait(lambda:state('host').get('surface_ready') and business().get('credits')==expected,'host restart preserves settlement and funds',90)
        assert site()['state']=='settled';checks+=1
        print(f'BUSINESS_PLAY_CHECKS {checks} FAILURES 0 players={players}\nEvidence: {work}',flush=True)
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
