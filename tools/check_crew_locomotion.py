"""Focused two-player locomotion smoke: actual scenes, ENet, Metal and isolated saves."""
from pathlib import Path
import json, socket, subprocess, tempfile, time, shutil
ROOT=Path(__file__).resolve().parents[1]
workspace=Path(tempfile.mkdtemp(prefix='crew-locomotion-'))
print('EVIDENCE',workspace,flush=True)
processes={};logs={};observed={};checks=[]
with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as sock:
 sock.bind(('127.0.0.1',0));port=sock.getsockname()[1]
def launch(name):
 folder=workspace/name;folder.mkdir(exist_ok=True);logs[name]=open(folder/'godot.log','w')
 cmd=[str(ROOT/'tools/godot.sh'),'--resolution','1100x760','--position','20,60' if name=='host' else '1120,60','--script','res://tests/check_crew_locomotion_peer.gd','--','--crew-ui-test',f'--crew-folder={folder}',f'--crew-role={name}',f'--crew-port={port}']
 processes[name]=subprocess.Popen(cmd,stdout=logs[name],stderr=subprocess.STDOUT)
def state(name):
 try:return json.loads((workspace/name/'status.json').read_text())
 except (FileNotFoundError,json.JSONDecodeError):return {}
def command(peer_name,**value):
 path=workspace/peer_name/'command.json'
 deadline=time.monotonic()+5
 while path.exists():
  if time.monotonic()>deadline:raise RuntimeError('command not consumed')
  time.sleep(.02)
 path.with_suffix('.tmp').write_text(json.dumps(value));path.with_suffix('.tmp').replace(path)
def wait(predicate,label,seconds=30):
 end=time.monotonic()+seconds
 while time.monotonic()<end:
  for name in processes:
   s=state(name)
   for id,p in s.get('poses',{}).items():
    if p.get('sound_playing'):observed.setdefault(name,set()).add(p.get('motion',{}).get('state',''))
  if predicate():checks.append(label);print('PASS',label,flush=True);return
  time.sleep(.025)
 raise AssertionError(label)
def request(name,action,**args):command(name,kind='request',action=action,args=args)
def snapshot(name):return state(name).get('snapshot',{})
def motion(name,id):return snapshot(name).get('motion',{}).get(id,{})
def position(name,id):return state(name).get('positions',{}).get(id,[0,0,0])
try:
 launch('host');wait(lambda:state('host').get('active'),'host opens')
 launch('guest0');wait(lambda:state('guest0').get('active'),'guest joins')
 request('guest0','lobby_ready',value=True)
 wait(lambda:any(snapshot('host').get('lobby_ready',{}).values()),'guest ready')
 request('host','start_game');wait(lambda:snapshot('guest0').get('phase')=='playing','shared scene starts')
 host_id=snapshot('host')['self_id'];guest_id=snapshot('guest0')['self_id']
 for name in processes:command(name,kind='prepare')
 wait(lambda:motion('host',guest_id).get('grounded'),'cabin contact')
 command('host',kind='place',character_id=guest_id,point=[0,.10,1])
 command('host',kind='view_actor',character_id=guest_id)
 wait(lambda:state('host').get('poses',{}).get(guest_id,{}).get('bones')==13,'13 imported bones on remote actor')
 command('host',kind='capture_now',name='idle')
 origin=position('host',guest_id)
 command('guest0',kind='move_world',direction=[0,-1])
 wait(lambda:position('host',guest_id)[2]<origin[2]-1,'guest input moves host collision body')
 command('host',kind='capture_now',name='walk')
 command('guest0',kind='move_world',direction=[0,0])
 wait(lambda:motion('host',guest_id).get('state')=='idle','walk stops')
 wait(lambda:abs(position('host',guest_id)[2]-position('guest0',guest_id)[2])<.25,'prediction reconciles with host')
 base=position('host',guest_id)[1];serial=motion('host',guest_id)['jump_serial']
 command('host',kind='view_actor',character_id=guest_id)
 command('guest0',kind='jump',pressed=True)
 wait(lambda:position('host',guest_id)[1]>base+.5,'guest jumps on host')
 command('host',kind='capture_now',name='jump')
 wait(lambda:motion('host',guest_id).get('grounded') and motion('host',guest_id).get('land_serial',0)>0,'jump lands with contact')
 command('host',kind='capture_now',name='land')
 time.sleep(.35)
 assert motion('host',guest_id)['jump_serial']==serial+1,'held space repeated jump'
 checks.append('held space jumps only once')
 command('guest0',kind='jump',pressed=False)
 command('guest0',kind='menu',visible=True);time.sleep(.1)
 command('guest0',kind='jump',pressed=True);time.sleep(.25)
 assert motion('host',guest_id)['jump_serial']==serial+1,'menu accepted jump'
 command('guest0',kind='menu',visible=False);time.sleep(.2)
 assert motion('host',guest_id)['jump_serial']==serial+1,'menu buffered jump'
 command('guest0',kind='jump',pressed=False)
 checks.append('menu blocks jump without deferred launch')
 # Land via the real host request, then test the same jump on streamed terrain.
 command('host',kind='land_fixture');time.sleep(.2)
 for name in processes:
  request(name,'ready',value=True)
  wait(lambda n=name:snapshot('host').get('crew',{}).get('members',{}).get(host_id if n=='host' else guest_id,{}).get('ready'),name+' ready to land')
 request('host','land')
 wait(lambda:state('guest0').get('surface_loaded') and not state('host').get('arrival',True) and not state('guest0').get('arrival',True),'landed terrain and input ready',90)
 for name in processes:command(name,kind='prepare')
 wait(lambda:motion('host',guest_id).get('grounded'),'terrain contact')
 serial=motion('host',guest_id)['jump_serial'];base=position('host',guest_id)[1]
 command('host',kind='view_actor',character_id=guest_id)
 command('guest0',kind='jump',pressed=True)
 wait(lambda:position('host',guest_id)[1]>base+.45,'terrain jump rises')
 command('host',kind='capture_now',name='surface-jump')
 command('guest0',kind='jump',pressed=False)
 wait(lambda:motion('host',guest_id).get('grounded') and motion('host',guest_id)['jump_serial']==serial+1,'terrain jump lands')
 wait(lambda:motion('guest0',guest_id).get('jump_serial')==serial+1,'approved jump serial reaches guest')
 command('guest0',kind='sprint',pressed=True);command('guest0',kind='move_world',direction=[.5,-.5])
 wait(lambda:motion('host',guest_id).get('state')=='run','surface running pose')
 command('host',kind='capture_now',name='surface-run')
 command('guest0',kind='move_world',direction=[0,0])
 wait(lambda:motion('host',guest_id).get('state')=='idle','surface comes to rest')
 command('host',kind='capture_now',name='surface-idle')
 time.sleep(.2)
 command('guest0',kind='close');processes['guest0'].wait(timeout=10)
 command('host',kind='close');processes['host'].wait(timeout=10)
 out=ROOT/'docs/production/media/crew-locomotion';out.mkdir(parents=True,exist_ok=True)
 for p in (workspace/'host').glob('*.png'):shutil.copyfile(p,out/p.name)
 report={'runtime_errors':[], 'checks':checks,'audio_playback_states':{k:sorted(v) for k,v in observed.items()},'workspace':str(workspace),'scope':'two local ENet clients, actual Forward+ windows; isolated saves; no internet or Windows test'}
 (out/'verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
finally:
 for name,p in processes.items():
  if p.poll() is None:p.terminate()
  try:p.wait(timeout=5)
  except subprocess.TimeoutExpired:p.kill()
  logs[name].close()
 for p in workspace.glob('*/godot.log'):
  text=p.read_text()
  if 'SCRIPT ERROR' in text or 'ERROR:' in text:
   report_path=ROOT/'docs/production/media/crew-locomotion/verification.json'
   if report_path.exists():
    report=json.loads(report_path.read_text());report['runtime_errors']=[line for line in text.splitlines() if 'SCRIPT ERROR' in line or 'ERROR:' in line][:10];report_path.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
   print(p,text[-6000:]);raise RuntimeError('Godot runtime error')

print('LOCOMOTION PASS',len(checks),flush=True)
