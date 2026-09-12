"""Reuse verified, unchanged file digests across finite review batches."""
from pathlib import Path
import atexit,hashlib,json,os

ROOT=Path(__file__).resolve().parents[2]
PATH=ROOT/'output/creature-remodel/production/review-digests.json'
IMPORTED=PATH.with_name('import-digests.json')
cache=json.loads(IMPORTED.read_text()) if IMPORTED.exists() else {}
if PATH.exists():cache.update(json.loads(PATH.read_text()))
changed={}

def signature(path):
    stat=path.stat()
    return [stat.st_size,stat.st_mtime_ns,stat.st_ctime_ns,stat.st_ino]

def sha(path):
    key=str(path);before=signature(path);entry=cache.get(key,{})
    if entry.get('signature')!=before:
        digest=hashlib.sha256(path.read_bytes()).hexdigest()
        assert signature(path)==before,str(path)+' changed during review'
        entry={'signature':before,'sha256':digest};cache[key]=entry;changed[key]=entry
    return entry['sha256']

@atexit.register
def save():
    if not changed:return
    latest=json.loads(PATH.read_text()) if PATH.exists() else {}
    latest.update(changed);PATH.parent.mkdir(parents=True,exist_ok=True)
    temporary=PATH.with_name(PATH.name+'.'+str(os.getpid())+'.tmp')
    temporary.write_text(json.dumps(latest));os.replace(temporary,PATH)
