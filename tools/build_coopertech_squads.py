"""Two distinct CooperTech chassis, rigid skinned mechanical joints, INK v1.
Blender --background --python tools/build_coopertech_squads.py -- [bastion|raptor]
"""
from pathlib import Path
import sys,math,json,struct
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
import ink_blender as ink
import build_ink_industry as k
import corporate_marks
import coopertech_biped_pose as biped
OUT=ROOT/'art/blender/incidents';GAME=ROOT/'우주-비즈니스/assets/models/incidents';REVIEW=ROOT/'docs/production/media/coopertech-squads'
for path in [OUT,GAME,REVIEW]:path.mkdir(parents=True,exist_ok=True)
def p(v):return Vector((v[0],-v[2],v[1]))
def box(name,at,size,role='armor',bevel=.04):return k.box(name,p(at),(size[0],size[2],size[1]),role,bevel)
def rod(name,a,b,r,role='steel'):return k.rod(name,p(a),p(b),r,role)
def orb(name,at,size,role='armor'):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,location=p(at));o=bpy.context.object;o.scale=(size[0],size[2],size[1]);k.finish(o,name,role,0);return o
def plate(name,points,front,back,role='armor'):
 verts=[p((x,y,z)) for z in [front,back] for x,y in points];n=len(points)
 faces=[tuple(reversed(range(n))),tuple(range(n,n*2))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
 import bmesh
 bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
 o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);bpy.context.view_layer.objects.active=o;o.select_set(True);return k.finish(o,name,role,.035)
def palette():
 k.reset()
 for name,color in [('armor',(.11,.145,.165)),('red',(.42,.045,.016)),('optic',(.95,.13,.015))]:
  m=bpy.data.materials.new('CooperTech '+name);m.use_nodes=True;m.diffuse_color=(*color,1);b=m.node_tree.nodes['Principled BSDF'];b.inputs['Base Color'].default_value=m.diffuse_color;b.inputs['Metallic'].default_value=.45;b.inputs['Roughness'].default_value=.38
  if name=='optic':b.inputs['Emission Color'].default_value=(*color,1);b.inputs['Emission Strength'].default_value=.9
  k.P[name]=m
bones=[];group='';parts={}
def joint(name,at,end,parent='root'):
 global group
 bones.append((name,p(at),p(end),parent));group=name;parts[name]=[]
def capture(fn):
 before=set(bpy.context.scene.objects);fn();parts[group]+=[o for o in bpy.context.scene.objects if o not in before and o.type=='MESH']
def build(kind):
 global bones,parts
 palette();bones=[];parts={}
 joint('root',(0,0,0),(0,.3,0),'')
 if kind=='bastion':joint('pelvis',(0,1.55,0),(0,1.85,0))
 joint('body',(0,1.55,0) if kind=='bastion' else (0,.85,0),(0,2.1,0) if kind=='bastion' else (0,1.1,0),'pelvis' if kind=='bastion' else 'root')
 if kind=='bastion':
  def body():
   box('Reactor cradle',(0,1.6,0),(1.3,.55,1.05),'dark',.1)
   plate('V shaped cuirass',[(-.5,1.6),(.5,1.6),(.95,2.5),(.78,2.91),(-.78,2.91),(-.95,2.5)],-.65,.48)
   for side in [-1,1]:
    plate('Shoulder citadel',[(side*.67,2.3),(side*1.5,2.3),(side*1.65,2.8),(side*1.2,3.04),(side*.67,2.89)],-.5,.6)
    plate('Oxide chevron',[(side*.75,2.58),(side*1.47,2.64),(side*1.40,2.79),(side*.8,2.75)],-.56,-.51,'red')
    rod('Reactor coolant',(side*.65,1.65,.53),(side*.65,2.72,.53),.095,'steel')
    box('Power cassette',(side*.52,2.32,.77),(.5,1,.52),'dark',.08)
    for y in [1.99,2.19,2.39,2.59]:box('Radiator vanes',(side*.52,y,1.05),(.4,.065,.07),'steel',.01)
   for side in [-1,1]:
    plate('Overlapping breast lamella',[(side*.06,2.73),(side*.60,2.80),(side*.79,2.55),(side*.40,2.35),(side*.12,2.49)],-.71,-.64,'armor')
    plate('Belly edge bevel',[(side*.10,1.65),(side*.45,1.69),(side*.65,2.03),(side*.45,1.95)],-.72,-.65,'steel')
    for y in [1.39,1.53]:box('Waist flexible seal',(0,y,-.52),(.8,.055,.09),'steel',.012)
   orb('Core receiver',(0,2.26,-.7),(.33,.33,.1),'dark')
   for s in [-1,1]:rod('Breach actuator',(s*.95,2.29,-.4),(s*.98,1.63,-.68),.18,'dark');box('Armored fist',(s*.98,1.5,-.66),(.52,.46,.62),'armor',.075)
   for side in [-1,1]:
    for dx in [-.15,0,.15]:
     box('Armored knuckle',(side*.98+dx,1.46,-1.0),(.115,.23,.16),'steel',.028)
   corporate_marks.mount('Bastion','coopertech',p((-.52,2.48,-.70)),(-1,0,0),(0,0,1),.36)
  capture(body)
  joint('head',(0,2.94,-.18),(0,3.35,-.18),'body')
  def head():
   plate('Recessed commander head',[(-.34,2.89),(.34,2.89),(.44,3.35),(.27,3.6),(-.27,3.6),(-.44,3.35)],-.56,.12)
   plate('Forward visor brow',[(-.41,3.31),(0,3.25),(.41,3.31),(.30,3.42),(-.30,3.42)],-.70,-.58,'steel')
   plate('Chiseled jaw',[(-.27,3.08),(0,2.92),(.27,3.08),(.20,3.14),(-.20,3.14)],-.64,-.55,'dark')
   box('Optic cavity',(0,3.19,-.59),(.63,.16,.10),'dark',.015)
   for x in [-.18,.18]:box('Angled threat optic',(x,3.2,-.65),(.21,.055,.035),'optic',.012)
  capture(head)
  joint('weapon',(.92,2.87,-.05),(.92,2.87,-.7),'body')
  def weapon():
   box('Artillery breech',(.92,2.88,-.16),(.55,.48,1.1),'dark',.06)
   rod('Accelerator barrel',(.92,2.88,-.6),(.92,2.88,-1.6),.18,'steel')
   for z in [-.65,-.85,-1.05]:box('Recoil collar',(.92,2.88,z),(.5,.42,.10),'armor',.035)
   box('Slotted muzzle brake',(.92,2.88,-1.55),(.5,.38,.27),'armor',.025)
   box('Muzzle aperture',(.92,2.88,-1.7),(.28,.16,.015),'dark',.005)
  capture(weapon)
  for side in [-1,1]:
   x=side*.83
   joint('hip_'+str(side),(x,1.55,0),(x, .85,.1),'pelvis')
   capture(lambda: (rod('Hip servo',(x-.22,1.45,0),(x+.22,1.45,0),.24),box('Thigh armor',(x,1.15,0),(.59,.6,.63),'armor',.08),rod('Hydraulic ram',(x+side*.28,1.45,.3),(x+side*.28,.83,.28),.075)))
   joint('knee_'+str(side),(x,.8,.1),(x,.28,-.04),'hip_'+str(side))
   capture(lambda: (rod('Knee axle',(x-.3,.8,.1),(x+.3,.8,.1),.21),plate('Tapered shin',[(x-.26,.2),(x+.26,.2),(x+.35,.83),(x+.2,1.02),(x-.2,1.02),(x-.35,.83)],-.37,.12),box('Shin insignia',(x,.62,-.41),(.34,.11,.06),'red',.012)))
   joint('foot_'+str(side),(x,.23,-.04),(x,.23,-.5),'knee_'+str(side))
   capture(lambda: (box('Load spreading heel',(x,.16,.0),(.73,.30,.96),'dark',.075),plate('Wedge tread',[(x-.36,.04),(x+.36,.04),(x+.31,.23),(x-.31,.34)],-.67,-.15),*[box('Traction split',(x+d,.07,-.4),(.10,.12,.6),'steel',.012) for d in [-.23,.23]]))
 else:
  def body():
   orb('Streamlined armored spine',(0,1.02,.13),(.54,.35,1.08))
   box('Underbody frame',(0,.8,.18),(.75,.26,1.8),'dark',.1)
   for side in [-1,1]:
    plate('Swept side armor',[(side*.28,.8),(side*.62,.95),(side*.58,1.20),(side*.27,1.34)],-.66,.87)
    rod('External flexible manifold',(side*.53,.95,-.7),(side*.53,.95,.9),.065,'steel')
    for z in [.15,.35,.55,.75]:box('Cooling gill',(side*.55,1.14,z),(.055,.11,.11),'steel',.015)
   for side in [-1,1]:
    rod('Swept sensor boom',(side*.36,1.17,.83),(side*.49,1.59,1.28),.028,'steel')
    box('Rear pulse capacitor',(side*.3,1.02,1.03),(.21,.23,.24),'red',.05)
   corporate_marks.mount('Raptor','coopertech',p((0,1.38,.2)),(1,0,0),(0,1,0),.34)
  capture(body)
  joint('head',(0,1,-.85),(0,1,-1.4),'body')
  def head():
   plate('Tracking snout',[(-.32,.84),(.32,.84),(.27,1.26),(0,1.40),(-.27,1.26)],-1.39,-.80)
   plate('Swept orbital guard',[(-.36,1.2),(0,1.24),(.36,1.2),(.26,1.36),(0,1.44),(-.26,1.36)],-1.46,-1.33,'steel')
   box('Recessed lateral optic',(0,1.11,-1.42),(.49,.14,.055),'dark',.025)
   for x in [-.16,.16]:orb('Hunter optic',(x,1.13,-1.46),(.07,.045,.032),'optic')
   for s in [-1,1]:rod('Jaw sensor prong',(s*.2,.91,-1.36),(s*.18,.87,-1.57),.035,'steel')
  capture(head)
  joint('weapon',(0,1.28,-.05),(0,1.3,-.55),'body')
  def weapon():
   box('Dorsal pulse turret',(0,1.38,-.2),(.53,.3,.74),'armor',.075)
   for s in [-1,1]:
    rod('Twin pulse tube',(s*.15,1.4,-.38),(s*.15,1.4,-.98),.075,'steel')
    rod('Ceramic muzzle',(s*.15,1.4,-.83),(s*.15,1.4,-1.01),.104,'dark')
   box('Weapon oxide stripe',(0,1.545,-.16),(.22,.026,.27),'red',.01)
  capture(weapon)
  for side in [-1,1]:
   for fore in [-1,1]:
    suffix=str(side)+'_'+str(fore);x=side*.53;z=fore*.71;kx=side*1.00;kz=z+fore*.2
    joint('hip_'+suffix,(x,1.03,z),(kx,.66,kz),'body')
    capture(lambda: (rod('Splayed hip bearing',(x-side*.12,1.02,z),(x+side*.13,1.02,z),.16),rod('Upper leg alloy',(x,1.02,z),(kx,.67,kz),.11,'dark'),box('Shoulder scute',((x+kx)*.5,.88,(z+kz)*.5),(.34,.26,.46),'armor',.065),rod('Exposed leg piston',(x,1.10,z+.1),(kx,.71,kz+.10),.044)))
    joint('knee_'+suffix,(kx,.66,kz),(kx,.18,z-.10),'hip_'+suffix)
    capture(lambda: (rod('Stifle axle',(kx-.16,.66,kz),(kx+.16,.66,kz),.13),rod('Reverse shin',(kx,.62,kz),(kx,.17,z-.10),.083,'steel'),box('Shin cowl',(kx,.45,(kz+z-.1)*.5),(.24,.40,.26),'armor',.055)))
    joint('foot_'+suffix,(kx,.16,z-.10),(kx,.16,z-.33),'knee_'+suffix)
    capture(lambda: (box('Clawed foot',(kx,.105,z-.15),(.3,.2,.47),'dark',.045),*[rod('Toe talon',(kx+d,.09,z-.27),(kx+d,.055,z-.46),.04,'steel') for d in [-.09,.09]]))
 joint('core',(0,2.26,-.74) if kind=='bastion' else (0,1.32,.65),(0,2.52,-.74) if kind=='bastion' else (0,1.53,.65),'body')
 capture(lambda:orb('Exposed cooling core',(0,2.26,-.76) if kind=='bastion' else (0,1.33,.65),(.23,.23,.07) if kind=='bastion' else (.2,.12,.23),'optic'))
 # Bake manufacture modifiers, assign rigid weights, then merge only skinned geometry.
 meshes=[]
 for name,objects in parts.items():
  for obj in objects:
   bpy.context.view_layer.objects.active=obj
   for mod in list(obj.modifiers):bpy.ops.object.modifier_apply(modifier=mod.name)
   group=obj.vertex_groups.new(name=name);group.add(list(range(len(obj.data.vertices))),1,'REPLACE');meshes.append(obj)
 bpy.ops.object.select_all(action='DESELECT')
 for obj in meshes:obj.select_set(True)
 bpy.context.view_layer.objects.active=meshes[0];bpy.ops.object.join();mesh=bpy.context.object;mesh.name='CooperTech_'+kind+'_skin';bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 arm=bpy.data.armatures.new(kind+'_joints');rig=bpy.data.objects.new('CooperTech_'+kind,arm);bpy.context.collection.objects.link(rig)
 mesh.select_set(False);rig.select_set(True);bpy.context.view_layer.objects.active=rig;bpy.ops.object.mode_set(mode='EDIT')
 for name,a,b,parent in bones:
  bone=arm.edit_bones.new(name);bone.head=a;bone.tail=b
  if parent:bone.parent=arm.edit_bones[parent]
 bpy.ops.object.mode_set(mode='OBJECT');mesh.parent=rig;mod=mesh.modifiers.new('Mechanical joint skin','ARMATURE');mod.object=rig
 if kind=='bastion':biped.set_planted_rest(rig,mesh,.17)
 for clip in ['idle','ready','walk','wake','fire','cool','destroyed']:
  rig.animation_data_create();action=bpy.data.actions.new(clip);rig.animation_data.action=action
  for frame in range(1,26,2):
   t=(frame-1)/24
   for name,a,b,parent in bones:
    bone=rig.pose.bones[name];bone.rotation_mode='XYZ';bone.rotation_euler=(0,0,0);bone.location=(0,0,0);bone.scale=(1,1,1)
    if clip in ['idle','wake','destroyed']:
     fold=1 if clip in ['idle','destroyed'] else 1-t
     if name=='body':bone.rotation_euler.x=.42*fold;bone.location.y=-.25*fold
     if name.startswith('hip_'):bone.rotation_euler.x=.35*fold
     if name.startswith('knee_'):bone.rotation_euler.x=-.5*fold
    if clip=='walk' and kind!='bastion':
     if name.startswith(('hip_','knee_','foot_')):
      side=-1 if name.split('_')[1]=='-1' else 1;fore=-1 if name.endswith('_-1') else 1
      phase=t*math.tau+(math.pi if (side*fore<0 if kind=='raptor' else side<0) else 0)
      v=math.sin(phase)*(.36 if kind=='raptor' else .28)
      bone.rotation_euler.x=v if name.startswith('hip') else (-max(0,v)*1.3 if name.startswith('knee') else -v*.35)
     if name=='body':bone.location.y=abs(math.sin(t*math.tau))*.035
    if name=='weapon' and clip=='fire':bone.location.y=-math.sin(t*math.pi)*.18
    if name=='core':bone.scale=(1,1,1) if clip=='cool' else (.18,.18,.18)
   if clip=='walk' and kind=='bastion':bpy.context.view_layer.update();biped.walk(rig,t)
   for name,a,b,parent in bones:
    bone=rig.pose.bones[name]
    for key in ['rotation_euler','location','scale']:bone.keyframe_insert(key,frame=frame,group=name)
  track=rig.animation_data.nla_tracks.new();track.name=clip;track.strips.new(clip,1,action);track.mute=True
 rig.animation_data.action=None
 for bone in rig.pose.bones:bone.rotation_euler=(0,0,0);bone.location=(0,0,0);bone.scale=(1,1,1)
 bpy.context.scene.frame_set(1);bpy.context.scene.unit_settings.system='METRIC'
 source=OUT/('coopertech_'+kind+'.blend');bpy.ops.wm.save_as_mainfile(filepath=str(source))
 target=GAME/('coopertech_'+kind+'.glb');bpy.ops.export_scene.gltf(filepath=str(target),export_format='GLB',export_animation_mode='ACTIONS',export_all_influences=False,export_cameras=False,export_lights=False)
 blob=target.read_bytes();length=struct.unpack_from('<I',blob,12)[0];gltf=json.loads(blob[20:20+length]);record={'source':str(source.relative_to(ROOT)),'model':str(target.relative_to(ROOT)),'bones':len(bones),'clips':[a['name'] for a in gltf.get('animations',[])],'triangles':sum(gltf['accessors'][pr['indices']]['count']//3 for me in gltf['meshes'] for pr in me['primitives']),'glb_bytes':len(blob)}
 # Real Blender studio review, after saving/exporting source with no studio props.
 scene=bpy.context.scene;scene.world=bpy.data.worlds.new('CooperTech studio');scene.world.color=(.24,.24,.24)
 center=Vector((0,0,1.75 if kind=='bastion' else .85));bpy.ops.object.camera_add(location=(5,8,5));cam=bpy.context.object;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=5.3 if kind=='bastion' else 4.1;scene.camera=cam
 bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.02));bpy.context.object.data.materials.append(k.P['dark'])
 for loc,power in [((2,4,7),1700),((-4,1,4),1000)]:
  bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=power;o.data.size=5;o.rotation_euler=(center-o.location).to_track_quat('-Z','Y').to_euler()
 scene.render.engine='CYCLES';scene.cycles.samples=24;scene.render.resolution_x=1100;scene.render.resolution_y=1100;scene.render.resolution_percentage=100;scene.render.filepath=str(REVIEW/(kind+'-blender.png'));bpy.ops.render.render(write_still=True)
 return record
requested=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else ['bastion','raptor'];records={}
for kind in requested:records[kind]=build(kind);print('COOPERTECH_EXPORTED',kind,records[kind],flush=True)
p=OUT/'coopertech-squads.json';old=json.loads(p.read_text()) if p.exists() else {};old.update(records);p.write_text(json.dumps(old,ensure_ascii=False,indent=2)+'\n')
