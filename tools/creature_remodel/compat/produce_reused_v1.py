"""The same anatomy and pose capture, exporting unchanged animation only once per LOD pair.

Blender --background --python tools/creature_remodel/produce_reused.py -- r03 <selection>
Completed checkpoints from the original backend remain valid. New checkpoints
record both the anatomical source and capture implementation fingerprints.
"""
from pathlib import Path
import hashlib, importlib, json, os, sys
ROOT = Path(__file__).resolve().parents[2]
sys.path[:0] = [str(Path(__file__).parent), str(ROOT/'tools'), str(ROOT/'tools/bestiary')]
import animation_capture
import produce_captured
import lod_animation


def fingerprint(base):
    return hashlib.sha256(produce_captured.fingerprint(base).encode()+Path(lod_animation.__file__).read_bytes()+Path(__file__).read_bytes()).hexdigest()


def main():
    args = sys.argv[sys.argv.index('--')+1:]
    batch, selection = args[0], args[1:]
    entry_name, motion_name = {
        'r03': ('produce', 'production_motion'),
        'r04': ('produce_midpoints', 'midpoint_motion'),
        'r05': ('produce_air', 'air_motion'),
        'r06': ('produce_legacy', 'legacy_motion'),
    }[batch]
    entry, motion = importlib.import_module(entry_name), importlib.import_module(motion_name)
    base_fingerprint = entry.fingerprint
    entry.fingerprint = lambda spec: fingerprint(base_fingerprint(spec))
    motion.animate = animation_capture.compile_animation(motion)
    if batch == 'r03':
        entry.animate = motion.animate
    pipeline = importlib.import_module('build_batch' if batch == 'r03' else 'production_core')
    original_build = lod_animation.compile_build(pipeline)
    source = ROOT/'art/blender/creature_remodel'/batch
    cache_path = ROOT/'output/creature-remodel/production'/('verified-assets-'+batch+'.json')
    cache = json.loads(cache_path.read_text()) if cache_path.exists() else {}

    def asset_matches(asset):
        path = ROOT/asset['path']
        if not path.exists():
            return False
        info = path.stat()
        return cache.get(asset['path']) == [info.st_size, info.st_mtime_ns, asset['sha256']] or hashlib.sha256(path.read_bytes()).hexdigest() == asset['sha256']

    def build(spec, *build_args):
        metadata = source/(spec['id']+'.json')
        base = base_fingerprint(spec)
        if metadata.exists():
            row = json.loads(metadata.read_text())
            if (row.get('build_fingerprint') in [base, produce_captured.fingerprint(base), fingerprint(base)]
                and (ROOT/row['source']).is_file()
                and (ROOT/'docs/production/media/creature-remodel'/batch/'blender'/(spec['id']+'.png')).is_file()
                and all(asset_matches(asset) for asset in row['lods'].values())):
                print('BATCH_SKIP', spec['id'], flush=True)
                return row
        row = original_build(spec, *build_args)
        row['animation_capture'] = {'version': 1, 'base_fingerprint': base}
        row['lod_animation_reuse'] = {'version': 1, 'source': 'near'}
        temporary = metadata.with_suffix('.json.tmp')
        temporary.write_text(json.dumps(row, ensure_ascii=False, indent=2)+'\n')
        os.replace(temporary, metadata)
        return row

    pipeline.build = build
    sys.argv = sys.argv[:sys.argv.index('--')+1]+selection
    entry.main()


if __name__ == '__main__':
    main()
