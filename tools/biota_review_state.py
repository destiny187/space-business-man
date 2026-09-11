"""Keep capture provenance intact when another task changes actor loading.
Older images count only with a COMPLETE pose/material/install equivalence census
for the exact old/new source hashes and each unchanged pair of model assets.
"""
import hashlib
import json
from functools import lru_cache
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
@lru_cache(maxsize=1)
def state():
    current=hashlib.sha256((ROOT/'우주-비즈니스/scripts/actors/creatures/bestiary_actor.gd').read_bytes()).hexdigest()
    path=ROOT/'docs/production/media/biota/runtime/equivalence.json'
    try:proof=json.loads(path.read_text())
    except (OSError,json.JSONDecodeError):proof={}
    excluded=proof.get('excluded',[])
    if (not proof.get('complete') or proof.get('checked',0)+len(set(excluded))!=7000
        or len(proof.get('models',{}))!=proof.get('checked')
        or set(excluded)&proof.get('models',{}).keys()
        or proof.get('failures')!=[] or proof.get('target_sha256')!=current):proof={}
    for key in ['source','target'] if proof else []:
        path=ROOT/'우주-비즈니스'/proof[key+'_snapshot'].removeprefix('res://')
        if not path.exists() or hashlib.sha256(path.read_bytes()).hexdigest()!=proof[key+'_sha256']:
            proof={};break
    return current,proof

def motion_matches(record,form):
    current,proof=state()
    if record.get('motion_sha256')==current:return True
    if not proof or record.get('motion_sha256')!=proof.get('source_sha256'):return False
    return proof.get('models',{}).get(form['id'])=={lod:form['lods'][lod]['sha256'] for lod in ['near','far']}
