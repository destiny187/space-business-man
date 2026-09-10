"""Original Space Y WARDEN orbital guard. Shared industrial materials and original insignia."""
import bpy,sys,math,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
import build_space_y_freighter as F
import corporate_marks as marks

def wing(side):
 shape=[(side*5,7),(side*11,5),(side*25,-12),(side*24,-17),(side*8,-11)]
 verts=[(x,y,z) for z in [-1,1] for x,y in shape];faces=[tuple(reversed(range(5))),tuple(range(5,10))]
 for i in range(5):faces.append((i,(i+1)%5,(i+1)%5+5,i+5))
 mesh=bpy.data.meshes.new('Swept pressure wing');mesh.from_pydata(verts,[],faces);mesh.update();o=bpy.data.objects.new('Swept pressure wing',mesh);bpy.context.collection.objects.link(o);F.finish(o,'Swept pressure wing','enamel_cream',bevel=.35)

def build():
 F.hull('Armored lifting body',[(-20,3,2,0),(-12,7,3,0),(5,6,3,0),(18,2.5,2,0),(25,.8,.8,0)])
 F.hull('Recessed canopy',[(0,3.5,1.3,3),(6,3.3,1.5,3),(12,1.9,.6,2.5)],'structural_dark')
 F.box('Cockpit dorsal armor',(0,-2,4),(5,5,1))
 for side in [-1,1]:
  wing(side)
  pod=F.empty('Anim_Engine_'+str(side),(side*10,-13,0))
  F.hull('Separate armored nacelle',[(-7,3.6,3.4,0),(4,3.4,3,0),(8,1.7,2,0)],'enamel_cream',pod)
  F.cylinder('Nozzle collar',(0,-8,0),3.4,3,'edge_steel',pod,'Y');F.cylinder('Dark exhaust throat',(0,-10,0),2.7,1.5,'structural_dark',pod,'Y')
  F.empty('Socket_Exhaust_'+str(side),(side*10,-21,0))
  fin=F.box('Canted stabilizer',(side*9,-13,5),(1.1,9,8),'structural_dark');fin.rotation_euler.y=-side*.24
  F.box('Tail white armor',(side*9.6,-13,6),(1,7,5))
  gun=F.empty('Socket_Weapon_'+str(side),(side*8,4,-2.7))
  F.cylinder('Stowed pulse emitter',(0,0,0),.75,9,'structural_dark',gun,'Y');F.cylinder('Emitter sleeve',(0,-2,0),1.2,4,'edge_steel',gun,'Y')
  if not F.LOD:
   for y in [-12,-9,-6]:F.box('Nacelle radiator',(side*10,y,3.2),(4,1,1),'structural_dark')
   marks.mount('Wing identity '+str(side),'space_y',(side*15,-10,1.5),(side,0,0),(0,side,0),5)
 sensor=F.empty('Anim_Sensor',(0,18,-1.2));F.cylinder('Independent sensor turret',(0,0,0),1.8,2.2,'edge_steel',sensor,'Y');F.box('Optical sensor slit',(0,1.4,0),(2.6,.6,.8),'enamel_teal',sensor)
 if not F.LOD:marks.mount('Dorsal identity','space_y',(0,-7,3.4),(1,0,0),(0,1,0),5.5)

records=[]
for distant in [False,True]:
 F.LOD=distant;bpy.ops.wm.read_factory_settings(use_empty=True);build()
 # Same exporter, scaled studio framing for the fighter's 50 m span.
 old=F.CAP;id='space_y_fighter'+('_lod1' if distant else '')
 # The exporter sets the camera; use a temporary frame-change-independent render handler.
 def frame(scene):scene.camera.data.ortho_scale=72
 bpy.app.handlers.render_pre.append(frame)
 records.append(F.export(id));bpy.app.handlers.render_pre.remove(frame)
 # Store the fighter camera setting in the original too.
 # Source was saved before rendering; reopen it to preserve corrected framing, without changing exports.
 bpy.ops.wm.open_mainfile(filepath=str(F.SRC/(id+'.blend')));bpy.context.scene.camera.data.ortho_scale=72;bpy.ops.wm.save_as_mainfile(filepath=str(F.SRC/(id+'.blend')))
(F.SRC/'space_y_fighter.json').write_text(json.dumps(records,indent=2)+'\n')
