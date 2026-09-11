"""Record pages only AFTER a person/agent actually inspects the displayed images.
The ledger identifies the exact model and motion revision that was seen.
"""
import argparse
import hashlib
import json
from collections import Counter
from pathlib import Path
from biota_review_state import motion_matches

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'docs/production/media/biota'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--kind', choices=['blender', 'game', 'motion', 'face-blender', 'face-game'], required=True)
    parser.add_argument('--pages', type=int, nargs='+', required=True)
    parser.add_argument('--midpoints', action='store_true', help='Use the 196 replacement contact boards that were actually inspected.')
    parser.add_argument('--prototypes', action='store_true', help='Record the twelve enlarged face prototypes that were inspected.')
    parser.add_argument('--note', required=True)
    args = parser.parse_args()
    forms = {r['id']: r for r in json.loads((ROOT / '우주-비즈니스/data/bestiary/biota_preview_forms.json').read_text())['forms']}
    motion_hash = hashlib.sha256((ROOT / '우주-비즈니스/scripts/actors/creatures/bestiary_actor.gd').read_bytes()).hexdigest()
    face=args.kind.startswith('face-')
    source=args.kind in ('blender','face-blender')
    if args.prototypes and not face:parser.error('Prototype pages are enlarged face boards.')
    if args.midpoints and (args.kind == 'motion' or face):
        parser.error('Motion uses the anatomical-type review index.')
    index_name=('faces-'+args.kind.removeprefix('face-')) if face else args.kind
    if args.prototypes:index_name+='-prototypes'
    index = json.loads((BASE / ('midpoints' if args.midpoints or face else 'review') / (index_name + '-index.json')).read_text())
    path = BASE / 'visual-review.json'
    ledger = json.loads(path.read_text()) if path.exists() else {'version': 1, 'records': {}}
    for item in index:
        if item['page'] not in args.pages:
            continue
        ids = [item['id']] if args.kind == 'motion' or args.midpoints or face else [item['family'] + '_%02d' % (a + 1) for a in item['anatomies']]
        for identity in ids:
            row = forms[identity]
            if args.midpoints and (not item['current'] or item['near_sha256'] != row['lods']['near']['sha256']):
                raise RuntimeError('Midpoint board includes an outdated or missing model: ' + identity)
            if face and (not item['current'] or item['model_sha256'] != row['lods']['near']['sha256']):
                raise RuntimeError('Face board includes an outdated or missing model: ' + identity)
            record = {'id': identity, 'kind': args.kind, 'model_sha256': row['lods']['near']['sha256'], 'note': args.note}
            if not source:
                rendered = json.loads((BASE / 'render-records' / (identity + '.json')).read_text())
                if rendered['model_sha256'] != record['model_sha256'] or not motion_matches(rendered,row) or rendered['failures']:
                    raise RuntimeError('Page includes a stale or failed render: ' + identity)
                record['motion_sha256'] = rendered['motion_sha256']
            ledger['records'][args.kind + ':' + identity] = record
    path.write_text(json.dumps(ledger, ensure_ascii=False, indent=2) + '\n')
    current = [r for r in ledger['records'].values() if r['id'] in forms and r['model_sha256'] == forms[r['id']]['lods']['near']['sha256'] and (r['kind'] in ('blender','face-blender') or motion_matches(r,forms[r['id']]))]
    print('CURRENT_VISUAL_REVIEW', dict(Counter(r['kind'] for r in current)))


if __name__ == '__main__':
    main()
