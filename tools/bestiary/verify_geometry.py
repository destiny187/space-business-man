"""Read GLB geometry directly: ignore colors/names when checking unique forms."""
import json,struct,hashlib,math
from pathlib import Path
def mul(a,b):
 return [[sum(a[r][k]*b[k][c] for k in range(4)) for c in range(4)] for r in range(4)]
IDENTITY=[[1.,0,0,0],[0,1.,0,0],[0,0,1.,0],[0,0,0,1.]]
def transform(node):
 if 'matrix' in node:
  m=node['matrix'];return [[m[c*4+r] for c in range(4)] for r in range(4)]
 x,y,z,w=node.get('rotation',[0,0,0,1]);s=node.get('scale',[1,1,1]);t=node.get('translation',[0,0,0])
 a=[[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w),t[0]],
 [2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w),t[1]],
 [2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y),t[2]],[0,0,0,1]]
 for r in range(3):
  for c in range(3):a[r][c]*=s[c]
 return a
def geometry(path):
 b=path.read_bytes();assert b[:4]==b'glTF';pos=12;doc=None;binary=None
 while pos<len(b):
  n,kind=struct.unpack_from('<II',b,pos);payload=b[pos+8:pos+8+n];pos+=8+n
  if kind==0x4e4f534a:doc=json.loads(payload)
  if kind==0x004e4942:binary=payload
 points=[]
 def walk(idx,parent):
  node=doc['nodes'][idx];matrix=mul(parent,transform(node))
  if 'mesh' in node:
   for prim in doc['meshes'][node['mesh']]['primitives']:
    acc=doc['accessors'][prim['attributes']['POSITION']];view=doc['bufferViews'][acc['bufferView']]
    assert acc['componentType']==5126 and acc['type']=='VEC3'
    start=view.get('byteOffset',0)+acc.get('byteOffset',0);stride=view.get('byteStride',12)
    for i in range(acc['count']):
     v=struct.unpack_from('<fff',binary,start+i*stride)
     p=tuple(round(sum(matrix[r][c]*v[c] for c in range(3))+matrix[r][3],4) for r in range(3))
     points.append(p)
  for child in node.get('children',[]):walk(child,matrix)
 for idx in doc['scenes'][doc.get('scene',0)]['nodes']:walk(idx,IDENTITY)
 unique=sorted(set(points));h=hashlib.sha256()
 for p in unique:h.update(struct.pack('<fff',*p))
 return {'geometry_hash':h.hexdigest(),'vertices':len(unique),'floor_y':min(p[1] for p in unique),'ceiling_y':max(p[1] for p in unique),'min':[min(p[j] for p in unique) for j in range(3)],'max':[max(p[j] for p in unique) for j in range(3)]}
if __name__=='__main__':
 import sys
 root=Path(__file__).resolve().parents[2]
 for case in sys.argv[1:]:
  print(case,json.dumps(geometry(root/'우주-비즈니스/assets/models/bestiary'/f'{case}_near.glb')))
