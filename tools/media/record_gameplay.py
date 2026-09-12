"""Record the unchanged PC game viewport in an isolated project and save folder."""
from pathlib import Path
import os
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / '우주-비즈니스'
WORK = ROOT / 'output/gameplay-reel/work'
PROJECT = WORK / 'capture-project'


def main():
    PROJECT.mkdir(parents=True, exist_ok=True)
    for name in ['assets', 'data', 'scripts', 'scenes', 'icon.svg', 'icon.svg.import']:
        link = PROJECT / name
        if not link.exists():
            link.symlink_to(SOURCE / name)
    cache = PROJECT / '.godot'
    cache.mkdir(exist_ok=True)
    for name in ['global_script_class_cache.cfg', 'uid_cache.bin']:
        shutil.copy2(SOURCE / '.godot' / name, cache / name)
    imported = cache / 'imported'
    if not imported.exists():
        imported.symlink_to(SOURCE / '.godot/imported')
    config = (SOURCE / 'project.godot').read_text()
    (PROJECT / 'project.godot').write_text(config)
    engine = os.environ.get('GAMEPLAY_GODOT', '/Users/jskim/Downloads/Godot.app/Contents/MacOS/Godot')
    with (WORK / 'capture.log').open('w') as log:
        subprocess.run([
            engine, '--path', str(PROJECT), '--write-movie', str(WORK / 'gameplay-raw.avi'),
            '--fixed-fps', '30', '--disable-vsync',
            '--script', str(ROOT / 'tools/media/capture_gameplay.gd'), '--',
            '--crew-ui-test', '--crew-folder=/tmp/gameplay-reel-session', '--dest=' + str(WORK),
        ], stdout=log, stderr=subprocess.STDOUT, check=True)


if __name__ == '__main__':
    main()
