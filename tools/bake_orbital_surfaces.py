"""Bake continuous Blender planet fields without interpolating vertex paint.
Blender --background --python tools/bake_orbital_surfaces.py
No mesh, coastline source, seed or saved world is modified.
"""
from pathlib import Path
import sys, json, hashlib, zlib, struct
import bpy
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import build_ink_planets as P
from build_restored_mars import restored_surface
OUT=ROOT/'우주-비즈니스/assets/textures/orbital'
OUT.mkdir(parents=True,exist_ok=True)
W,H=2048,1024

def png(path, pixels):
    # Explicit byte encoding: data masks stay linear, solar colour is encoded sRGB.
    def chunk(tag,data):return struct.pack('>I',len(data))+tag+data+struct.pack('>I',zlib.crc32(tag+data)&0xffffffff)
    raw=b''.join(b'\0'+row.tobytes() for row in pixels)
    path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',W,H,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(raw,6))+chunk(b'IEND',b''))

def main():
    selected=next((a.split("=",1)[1].split(",") for a in sys.argv if a.startswith("--only=")),[])
    entries=json.loads((OUT/"manifest.json").read_text())["entries"] if selected else []
    families=list(P.RULES['archetypes'])
    for name in families+P.S.NAMES+['mars_restored']:
        if selected and name not in selected:continue
        solar=name not in families
        result=np.empty((H,W,3),dtype=np.uint8)
        for y in range(0,H,32):
            offsets=[(.25,.25),(.75,.25),(.25,.75),(.75,.75)] if name in ["earth","mars_restored"] else [(.5,.5)]
            accumulated=0.
            for ox,oy in offsets:
                lon=(np.arange(W)+ox)/W*2*np.pi-np.pi
                lat=np.pi*.5-(np.arange(y,y+32)+oy)/H*np.pi
                lo,la=np.meshgrid(lon,lat)
                # Godot direction (cos lon cos lat, sin lat, sin lon cos lat), converted to Blender.
                v=np.column_stack([(np.cos(lo)*np.cos(la)).ravel(),(-np.sin(lo)*np.cos(la)).ravel(),np.sin(la).ravel()])
                if solar:
                    _,data,_=restored_surface(name,v) if name=='mars_restored' else P.solar_surface(name,v)
                else:
                    idx=families.index(name)
                    # Undo the generated giant's authored polar flattening before evaluating masks.
                    kind=P.RULES['archetypes'][name]['kind']
                    if kind in ['gas_giant','ice_giant']:
                        v[:,2]/=1-(.035 if kind=='gas_giant' else .02)
                        v/=np.linalg.norm(v,axis=1)[:,None]
                    _,data=P.variant_fields(v,idx,name,P.RULES['archetypes'][name])
                accumulated=accumulated+data
            data=accumulated/len(offsets)
            if solar:data=np.where(data<=.0031308,data*12.92,1.055*np.maximum(data,0)**(1/2.4)-.055)
            result[y:y+32]=np.rint(np.clip(data,0,1).reshape(32,W,3)*255).astype(np.uint8)
        path=OUT/(name+'.png');png(path,result)
        entries=[r for r in entries if r['id']!=name]
        entries.append({'id':name,'kind':'solar_color' if solar else 'relief_mask','texture':'res://assets/textures/orbital/'+path.name,'size':[W,H],'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
        print('ORBITAL_MAP',name,flush=True)
    (OUT/'manifest.json').write_text(json.dumps({'generator':'tools/bake_orbital_surfaces.py','mapping':'Godot local direction; U atan(z,x)/TAU+.5; V acos(y)/PI','entries':entries},indent=2)+'\n')

if __name__=='__main__':main()
