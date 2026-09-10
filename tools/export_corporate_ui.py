"""Copy the compact corporate vector masters into the Godot resource tree."""
from pathlib import Path
import json

ROOT=Path(__file__).resolve().parents[1]
source=ROOT/'art/branding/corporations'
destination=ROOT/'우주-비즈니스/assets/ui/corporations'
destination.mkdir(parents=True,exist_ok=True)
for company in json.loads((source/'identity.json').read_text())['companies']:
    (destination/(company['id']+'.svg')).write_bytes((source/'exports'/company['id']/'compact.svg').read_bytes())
print('Corporate HUD vectors exported')
