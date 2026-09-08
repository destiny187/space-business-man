"""Build editable, vertex-painted Solar System assets in Blender; no image textures.
Run: Blender --background --python tools/build_solar_system.py
Surface detail is stylized. Earth coastlines: Natural Earth public-domain land.
"""
from pathlib import Path
import bpy, numpy as np, math, json, zipfile, struct, hashlib, sys
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'art/blender/solar-system';OUTPUT=ROOT/'우주-비즈니스/assets/models/solar-system';RENDER=ROOT/'docs/production/media/solar-system/blender'
for p in (SOURCE,OUTPUT,RENDER):p.mkdir(parents=True,exist_ok=True)
NAMES=['mercury','venus','earth','mars','jupiter','saturn','uranus','neptune']
TITLES=['수성','금성','지구','화성','목성','토성','천왕성','해왕성']
def rgb(hexval):
 a=np.array([int(hexval[i:i+2],16)/255 for i in (0,2,4)])
 return np.where(a<=.04045,a/12.92,((a+.055)/1.055)**2.4)
def mix(a,b,t):return np.asarray(a)*(1-np.asarray(t)[...,None])+np.asarray(b)*np.asarray(t)[...,None]
def noise(v,f=1):
 x,y,z=(v*f).T
 return (np.sin(x*3.1+y*1.7+np.sin(z*3.3))+.5*np.sin(y*6.2-z*4.1+x)+.25*np.cos(z*13.1+x*8.7))/1.75
# Shapefile polygons, kept locally with source hash and license.
def coast_rings():
 archive=zipfile.ZipFile(ROOT/'art/reference/solar-system/ne_110m_land.zip')
 data=archive.read(next(n for n in archive.namelist() if n.endswith('.shp')));pos=100;rings=[]
 while pos<len(data):
  length=struct.unpack_from('>i',data,pos+4)[0]*2;rec=data[pos+8:pos+8+length];pos+=8+length
  if struct.unpack_from('<i',rec)[0]!=5:continue
  parts,points=struct.unpack_from('<ii',rec,36);starts=list(struct.unpack_from('<'+'i'*parts,rec,44))+[points]
  xy=np.frombuffer(rec,dtype='<f8',count=points*2,offset=44+parts*4).reshape(-1,2)
  rings.extend(xy[starts[i]:starts[i+1]].copy() for i in range(parts))
 return rings
COAST=coast_rings()
def land_mask(lon,lat):
 x=np.degrees(lon);y=np.degrees(lat);land=np.zeros(len(x),dtype=bool)
 for ring in COAST:
  lo=ring.min(axis=0);hi=ring.max(axis=0);inds=np.where((x>=lo[0])&(x<=hi[0])&(y>=lo[1])&(y<=hi[1]))[0]
  if not len(inds):continue
  xx=x[inds];yy=y[inds];inside=np.zeros(len(inds),dtype=bool)
  for a,b in zip(ring,np.roll(ring,-1,axis=0)):
   if abs(b[1]-a[1])<1e-9:continue
   inside^=((a[1]>yy)!=(b[1]>yy)) & (xx<(b[0]-a[0])*(yy-a[1])/(b[1]-a[1])+a[0])
  land[inds]^=inside
 return land

def surface(kind,v):
 lon=np.arctan2(v[:,1],v[:,0]);lat=np.arcsin(np.clip(v[:,2],-1,1));n=noise(v,1.3);radius=np.ones(len(v));cloud=np.zeros(len(v),bool)
 if kind=='mercury':
  color=mix(rgb('716b64'),rgb('b9afa0'),np.clip(.5+n*.23,0,1));radius+=n*.0015
  rng=np.random.default_rng(431)
  for i in range(68):
   axis=rng.normal(size=3);axis/=np.linalg.norm(axis);width=rng.uniform(.035,.14)
   d=np.arccos(np.clip(v@axis,-1,1))/width
   pit=np.exp(-((d/.67)**4));rim=np.exp(-((d-1)/.16)**2)
   radius+=.007*rim-.006*pit
   color=mix(color,rgb('514b47'),pit*.35);color=mix(color,rgb('dbcfba'),rim*.32)
 elif kind=='venus':
  bands=np.sin(lat*19+noise(v,2)*2.3+np.sin(lon*2+lat*9))
  color=mix(rgb('bd914c'),rgb('f0d5a0'),np.clip(.52+bands*.32+n*.12,0,1));radius+=n*.0008
 elif kind=='earth':
  land=land_mask(lon,lat)
  color=mix(rgb('14517c'),rgb('287da0'),np.clip(.5+n*.25,0,1))
  earth=mix(rgb('397354'),rgb('739567'),np.clip(.5+n*.3,0,1))
  dry=np.exp(-((np.abs(np.degrees(lat))-25)/13)**2)*np.clip(.7+noise(v,2)*.7,0,1)
  earth=mix(earth,rgb('c9b379'),dry*.85);color[land]=earth[land];radius[land]+=0.002
  ice=(np.abs(lat)>math.radians(74))|((np.degrees(lat)>60)&(np.degrees(lon)>-58)&(np.degrees(lon)<-24)&land)
  color[ice]=rgb('e0ecdf')
  wind=v.copy();wind[:,0]+=np.sin(lat*8)*.15
  cloud=noise(wind,3)+.25*np.sin(lon*7+lat*12)-.52
  cloud[np.abs(lat)>=1.3]=-1
 elif kind=='mars':
  color=mix(rgb('934d36'),rgb('ce875a'),np.clip(.5+n*.28,0,1));radius+=n*.002
  dark=np.clip((noise(v,2)+.05)*1.3,0,.6);color=mix(color,rgb('684238'),dark)
  # Deliberately stylized canyon system on the hemisphere seen from -Y.
  canyon=np.exp(-((lat+.12+.045*np.sin(lon*8))/.035)**2)*np.exp(-((lon+1.5)/.65)**6)
  radius-=canyon*.009;color=mix(color,rgb('58382e'),canyon*.8)
  pole=np.clip((np.abs(lat)-1.34)*13,0,1);color=mix(color,rgb('e9dfc8'),pole)
  rng=np.random.default_rng(773)
  for i in range(24):
   axis=rng.normal(size=3);axis/=np.linalg.norm(axis);d=np.arccos(np.clip(v@axis,-1,1))/rng.uniform(.025,.085)
   radius+=.003*np.exp(-((d-1)/.22)**2)-.003*np.exp(-((d/.6)**4))
 elif kind in ['jupiter','saturn']:
  warp=lat+noise(v,2)*.026+np.sin(lon*7+lat*16)*.006
  band=(np.sin(warp*36)+.4*np.sin(warp*77)+.15*np.cos(lon*17+warp*12))
  if kind=='jupiter':
   color=mix(rgb('b08260'),rgb('eddec0'),np.clip(.55+band*.38,0,1));radius*=1-.035*np.sin(lat)**2
   dx=np.arctan2(np.sin(lon+1.25),np.cos(lon+1.25));dy=lat+.32
   angle=np.arctan2(dy/.105,dx/.24);d=np.sqrt((dx/.24)**2+(dy/.105)**2)
   mask=np.clip((1.12-d)*6,0,1);storm=mix(rgb('9b4e3b'),rgb('d49970'),.5+.35*np.sin(d*16+angle*1.8))
   color=mix(color,storm,mask)
  else:color=mix(rgb('b4a075'),rgb('e8d7a7'),np.clip(.62+band*.20,0,1));radius*=1-.065*np.sin(lat)**2
 elif kind=='uranus':
  band=np.sin(lat*22+noise(v,1.5)*.4);color=mix(rgb('73b7bc'),rgb('badbd5'),np.clip(.62+band*.09+n*.06,0,1));radius*=1-.023*np.sin(lat)**2
 else:
  color=mix(rgb('4d89b0'),rgb('81b8c8'),np.clip(.50+np.sin(lat*25+noise(v,2))*.12+n*.09,0,1));radius*=1-.02*np.sin(lat)**2
  d=np.sqrt(((lon+1.4)/.16)**2+((lat+.26)/.07)**2);color=mix(color,rgb('385e81'),np.clip((1-d)*4,0,1)*.75)
 return radius,np.clip(color,0,1),cloud

def material(name,vertex=False,color='ffffff'):
 m=bpy.data.materials.new(name);m.diffuse_color=(*rgb(color),1);m.use_nodes=True
 nodes=m.node_tree.nodes;p=nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*rgb(color),1);p.inputs['Roughness'].default_value=.94
 if vertex:
  attr=nodes.new('ShaderNodeVertexColor');attr.layer_name='Color';m.node_tree.links.new(attr.outputs['Color'],p.inputs['Base Color'])
 return m

def body_mesh(kind,segments,rings,parent):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,radius=1)
 o=bpy.context.object;o.name='Anim_Surface';o.parent=parent
 coords=np.array([v.co[:] for v in o.data.vertices]);v=coords/np.linalg.norm(coords,axis=1)[:,None]
 radius,color,cloud=surface(kind,v);o.data.vertices.foreach_set('co',(v*radius[:,None]).astype(np.float32).ravel())
 colors=o.data.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='POINT')
 colors.data.foreach_set('color',np.column_stack([color,np.ones(len(color))]).astype(np.float32).ravel())
 o.data.materials.append(material(kind+'_vertex_paint',True))
 for face in o.data.polygons:face.use_smooth=True
 o.data.update()
 if kind=='earth':
  # Clip triangles to the cloud scalar field so silhouettes never follow square cells.
  vertices=[];faces=[]
  for face in o.data.polygons:
   indices=list(face.vertices)
   for k in range(1,len(indices)-1):
    triangle=[indices[0],indices[k],indices[k+1]]
    if not any(cloud[i]>0 for i in triangle):continue
    polygon=[]
    for j,ia in enumerate(triangle):
     ib=triangle[(j+1)%3];a=v[ia];b=v[ib];fa=cloud[ia];fb=cloud[ib]
     if fa>0:polygon.append(a)
     if (fa>0)!=(fb>0):polygon.append(a+(b-a)*fa/(fa-fb))
    if len(polygon)>=3:
     start=len(vertices);vertices.extend((point/np.linalg.norm(point)*1.006).tolist() for point in polygon);faces.append(tuple(range(start,start+len(polygon))))
  mesh=bpy.data.meshes.new('Earth cloud patches');mesh.from_pydata(vertices,[],faces);mesh.update()
  clouds=bpy.data.objects.new('Anim_Clouds',mesh);bpy.context.collection.objects.link(clouds);clouds.parent=parent;clouds.data.materials.append(material('Cloud ivory',False,'e3ecdf'))
  for face in clouds.data.polygons:face.use_smooth=True
 return o

def ring(name,inner,outer,color,parent):
 vertices=[];faces=[];n=256
 for z in [-.001,.001]:
  for radius in [inner,outer]:
   vertices.extend((math.cos(i*math.tau/n)*radius,math.sin(i*math.tau/n)*radius,z) for i in range(n))
 for i in range(n):
  j=(i+1)%n
  faces.extend([(i,j,n+j,n+i),(2*n+i,3*n+i,3*n+j,2*n+j),(i,2*n+i,2*n+j,j),(n+i,n+j,3*n+j,3*n+i)])
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update();o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);o.parent=parent;o.data.materials.append(material(name,False,color))
 return o

def setup_render(kind):
 scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
 scene.render.resolution_x=700;scene.render.resolution_y=700;scene.render.resolution_percentage=100
 scene.world.color=(.025,.035,.055)
 scene.view_settings.view_transform='AgX'
 bpy.ops.object.camera_add(location=(3,-6,2.1));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,0))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=5.5 if kind=='saturn' else (3.9 if kind=='uranus' else 2.8);scene.camera=cam
 for loc,power,size in [((-3,-4,5),750,5),((4,-1,2),220,4),((1,3,4),450,3)]:
  bpy.ops.object.light_add(type='AREA',location=loc);lamp=bpy.context.object;lamp.data.energy=power;lamp.data.shape='DISK';lamp.data.size=size;lamp.rotation_euler=(-lamp.location).to_track_quat('-Z','Y').to_euler()
 scene.render.image_settings.file_format='PNG';scene.render.filepath=str(RENDER/(kind+'.png'))

def main():
 only=next((arg.split("=",1)[1] for arg in sys.argv if arg.startswith("--planet=")),None)
 records=json.loads((SOURCE/"manifest.json").read_text()) if only else []
 records=[record for record in records if record["id"]!="solar_"+str(only)]
 for index,kind in enumerate(NAMES):
  if only and kind!=only:continue
  for lod in [0,1]:
   bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
   bpy.ops.object.empty_add();root=bpy.context.object;root.name='Solar_'+kind
   # Obliquity is a visual orientation; orbital/spin periods stay game-scaled.
   root.rotation_euler.y=math.radians([.03,3,23.4,25.2,3.1,26.7,97.8,28.3][index])
   body_mesh(kind,(512 if kind=="earth" else 256) if lod==0 else 96,(256 if kind=="earth" else 128) if lod==0 else 48,root)
   if kind=='saturn':
    for a,b,c in [(1.24,1.48,'796f5c'),(1.50,1.72,'b2a489'),(1.73,1.91,'d1c3a1'),(1.96,2.11,'b3a584'),(2.12,2.26,'c4b69a')]:ring('Saturn ring %.2f'%a,a,b,c,root)
   if kind=='uranus':
    for a,b in [(1.46,1.477),(1.61,1.632),(1.77,1.805)]:ring('Uranus narrow ring %.2f'%a,a,b,'6d8990',root)
   geometry=[o for o in bpy.context.scene.objects if o.type in ['MESH','EMPTY']]
   triangles=sum(sum(len(f.vertices)-2 for f in o.data.polygons) for o in geometry if o.type=='MESH')
   if lod==0:
    setup_render(kind)
    bpy.context.scene.unit_settings.system='METRIC'
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/(kind+'.blend')))
   bpy.ops.object.select_all(action='DESELECT')
   for o in geometry:o.select_set(True)
   path=OUTPUT/(kind+('_lod1' if lod else '')+'.glb')
   bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_apply=True,export_yup=True,export_animations=False)
   if lod==0:
    bpy.ops.render.render(write_still=True)
    records.append({'id':'solar_'+kind,'name':TITLES[index],'reference_id':'solar:'+str(index),'source':str((SOURCE/(kind+'.blend')).relative_to(ROOT)),'model':'res://assets/models/solar-system/'+kind+'.glb','lod_model':'res://assets/models/solar-system/'+kind+'_lod1.glb','triangles':triangles,'outer_radius':2.26 if kind=='saturn' else (1.805 if kind=='uranus' else 1.02),'status':'blender-created-game-render-pending'})
   else:records[-1]['lod_triangles']=triangles
   print('SOLAR DONE',kind,lod,triangles,flush=True)
 records.sort(key=lambda record:NAMES.index(record['id'].removeprefix('solar_')))
 (SOURCE/'manifest.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n')
 (OUTPUT/'manifest.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n')

if __name__=="__main__":
 manifest=SOURCE/'manifest.json'
 if manifest.exists() and any(r.get('art_revision')=='ink-life-1' for r in json.loads(manifest.read_text())):
  sys.path.insert(0,str(ROOT/'tools'))
  import build_ink_planets
  build_ink_planets.solar()
 else:main()
