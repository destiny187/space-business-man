"""Focused asset census and geometry identity audit; never uses names/colors as evidence."""
import json,struct,hashlib,sys
from pathlib import Path
from collections import Counter,defaultdict
import numpy as np
ROOT=Path(__file__).resolve().parents[1]
DTYPE={5120:np.int8,5121:np.uint8,5122:np.int16,5123:np.uint16,5125:np.uint32,5126:np.float32}
WIDTH={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}
def read_glb(path):
    raw=path.read_bytes();offset=12;doc=None;binary=None
    while offset<len(raw):
        length,kind=struct.unpack_from('<II',raw,offset);chunk=raw[offset+8:offset+8+length];offset+=8+length
        if kind==0x4E4F534A:doc=json.loads(chunk)
        elif kind==0x004E4942:binary=chunk
    return doc,binary

def accessor(doc,binary,index):
    a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']];d=np.dtype(DTYPE[a['componentType']]);w=WIDTH[a['type']]
    data=np.ndarray((a['count'],w),dtype=d,buffer=binary,offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',w*d.itemsize),d.itemsize)).copy()
    if a.get('normalized') and np.issubdtype(d,np.integer):data=data.astype(np.float64)/np.iinfo(d).max
    return data

def positions(doc,binary):
    out=[]
    for mesh in doc['meshes']:
        for primitive in mesh['primitives']:
            out.append(accessor(doc,binary,primitive['attributes']['POSITION']))
    return np.vstack(out)

def skin_errors(doc,binary):
    errors=[]
    for node in doc['nodes']:
        if 'mesh' not in node or 'skin' not in node:continue
        count=len(doc['skins'][node['skin']]['joints'])
        for primitive in doc['meshes'][node['mesh']]['primitives']:
            weights=[]
            for key,index in primitive['attributes'].items():
                if key.startswith('WEIGHTS_'):weights.append(accessor(doc,binary,index))
                if key.startswith('JOINTS_'):
                    joints=accessor(doc,binary,index)
                    if joints.min()<0 or joints.max()>=count:errors.append('joint index outside bound skeleton')
            if not weights:errors.append('unweighted skinned primitive');continue
            joined=np.concatenate(weights,axis=1)
            if not np.isfinite(joined).all() or joined.min()<0 or joined.max()>1:errors.append('invalid exported skin weight')
            if not np.allclose(joined.sum(axis=1),1,atol=1e-4):errors.append('exported skin weights do not sum to one')
    return sorted(set(errors))

def main():
    preview='--preview' in sys.argv;folder=ROOT/'우주-비즈니스/data/bestiary';filename='biota_preview_forms.json' if preview else 'biota_forms.json'
    forms=json.loads((folder/filename).read_text())['forms'];failures=[];seen={};totals=Counter();groups=Counter();types=Counter();bounds={};digest_rows=[];asset_bytes=Counter();peak_triangles=Counter()
    for row in forms:
        groups[row['family']]+=1;types[(row['category'],row['construction'])]+=1;totals[row['category']]+=1
        if not (ROOT/row['source']).exists():failures.append(row['id']+' missing Blender source')
        if not row.get('rig',{}).get('skinned'):failures.append(row['id']+' missing type rig')
        for lod in ['near','far']:
            path=ROOT/row['lods'][lod]['path']
            if not path.exists():failures.append(row['id']+' missing '+lod);continue
            asset_bytes[lod]+=path.stat().st_size;peak_triangles[lod]=max(peak_triangles[lod],int(row['lods'][lod]['triangles']))
            digest=hashlib.sha256(path.read_bytes()).hexdigest()
            if digest!=row['lods'][lod]['sha256']:failures.append(row['id']+' stale '+lod+' hash')
            doc,binary=read_glb(path)
            if not doc.get('skins'):failures.append(row['id']+' unbound '+lod+' skin')
            if any('JOINTS_0' not in primitive['attributes'] or 'WEIGHTS_0' not in primitive['attributes'] for mesh in doc['meshes'] for primitive in mesh['primitives']):failures.append(row['id']+' missing vertex skin data '+lod)
            failures.extend(row['id']+' '+lod+' '+error for error in skin_errors(doc,binary))
            if lod=='far':continue
            points=positions(doc,binary)
            if not np.isfinite(points).all():failures.append(row['id']+' nonfinite geometry');continue
            low=points.min(axis=0);high=points.max(axis=0);span=high-low
            if span.min()<.03:failures.append(row['id']+' degenerate geometry')
            # New skin export uses baked armature coordinates. Normalize translation
            # and overall scale; retain component proportions and topology.
            normalized=np.round((points-(low+high)*.5)/span.max(),5);order=np.lexsort(normalized.T[::-1]);h=hashlib.sha256(normalized[order].astype('<f4').tobytes()).hexdigest()
            if h in seen:failures.append(row['id']+' duplicate normalized geometry of '+seen[h])
            seen[h]=row['id'];digest_rows.append({'id':row['id'],'geometry':h,'rig':row['rig']['template'],'bones':row['rig']['bone_count']})
            bounds[row['id']]=span.tolist()
    complete=len(forms)==7000 and len(groups)==140 and set(groups.values())=={50}
    if (not preview or '--complete' in sys.argv) and not complete:failures.append('incomplete 140 × 50 asset census')
    result={'forms':len(forms),'categories':dict(totals),'construction_types':len(types),'rig_templates':len({r['rig']['template'] for r in forms}),'structural_groups':len(groups),'unique_normalized_geometry':len(seen),'model_bytes':dict(asset_bytes),'peak_triangles':dict(peak_triangles),'preview':preview,'complete_census':complete,'failures':failures,'identities':digest_rows}
    destination=ROOT/'docs/production/media/biota';destination.mkdir(parents=True,exist_ok=True);(destination/'asset-audit.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k!='identities'},ensure_ascii=False));return bool(failures)
if __name__=='__main__':sys.exit(main())
