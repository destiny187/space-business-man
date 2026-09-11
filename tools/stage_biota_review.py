"""Snapshot only current Blender exports already imported by Godot for rendering."""
import json,hashlib,re
from pathlib import Path
from pack_biota import pack,ROOT

def imported(row):
    project=ROOT/'우주-비즈니스'
    for lod in ['near','far']:
        source=ROOT/row['lods'][lod]['path'];descriptor=Path(str(source)+'.import')
        if not descriptor.exists():return False
        match=re.search(r'^path="res://([^"]+)"',descriptor.read_text(),re.M)
        if not match:return False
        target=project/match.group(1);stamp=target.with_suffix('.md5')
        if not target.exists() or not stamp.exists():return False
        digest=re.search(r'source_md5="([^"]+)"',stamp.read_text())
        if not digest or hashlib.md5(source.read_bytes()).hexdigest()!=digest.group(1):return False
    return True

def main():
    all_forms=pack(True);forms=[r for r in all_forms if imported(r)]
    target=ROOT/'우주-비즈니스/data/bestiary/biota_review_forms.json';tmp=target.with_suffix('.json.tmp')
    tmp.write_text(json.dumps({'forms':forms},ensure_ascii=False,separators=(',',':'))+'\n');tmp.replace(target)
    print('BIOTA_RENDER_READY',len(forms),'of',len(all_forms),flush=True)
if __name__=='__main__':main()
