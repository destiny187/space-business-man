"""Normalize bundle-internal paths before native macOS signing.
Keep the Korean product name in Finder and in the game; use ASCII binary/PCK paths.
"""
from pathlib import Path
import plistlib, shutil
root=Path(__file__).resolve().parents[1]
source=root/'builds/macos/우주 비즈니스맨.app'
target=root/'builds/macos/Locus.app'
if not source.exists(): raise SystemExit('Godot export bundle is missing')
if target.exists(): shutil.rmtree(target)
source.rename(target)
contents=target/'Contents'
plist_path=contents/'Info.plist'
info=plistlib.loads(plist_path.read_bytes())
old=info['CFBundleExecutable']
(contents/'MacOS'/old).rename(contents/'MacOS/Locus')
(contents/'Resources'/(old+'.pck')).rename(contents/'Resources/Locus.pck')
info['CFBundleExecutable']='Locus'
info['CFBundleDisplayName']='우주 비즈니스맨'
info['CFBundleName']='우주 비즈니스맨'
plist_path.write_bytes(plistlib.dumps(info))
(contents/'PkgInfo').write_bytes(b'APPLLOCS')
