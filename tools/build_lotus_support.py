"""Lotus HERON cargo carrier and reusable drop crate: editable Blender + GLB + Cycles review."""
from pathlib import Path
exec((Path(__file__).parent/'build_scout_rover.py').read_text().split("root=empty('SCOUT_Rover'")[0])
OUT=ROOT/'art/blender/lotus'; GAME=ROOT/'우주-비즈니스/assets/models/lotus'; REVIEW=ROOT/'docs/production/media/lotus'
for p in (OUT,GAME,REVIEW):p.mkdir(parents=True,exist_ok=True)

def export(name):
 bpy.context.scene.unit_settings.system='METRIC'
 bpy.ops.wm.save_as_mainfile(filepath=str(OUT/(name+'.blend')))
 ink.consolidate_static_surfaces()
 bpy.ops.export_scene.gltf(filepath=str(GAME/(name+'.glb')),export_format='GLB',export_cameras=False,export_lights=False)

def review(name,look,size):
 bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.05));bpy.context.object.data.materials.append(mat('Studio floor',(.13,.18,.20),0,.8))
 bpy.ops.object.camera_add(location=(size*.85,size, size*.72));cam=bpy.context.object;cam.rotation_euler=(Vector(look)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=size;bpy.context.scene.camera=cam
 bpy.ops.object.light_add(type='AREA',location=(2,4,10));bpy.context.object.data.energy=1900;bpy.context.object.data.size=8
 scene=bpy.context.scene;scene.world.color=(.25,.25,.25);scene.render.engine='CYCLES';scene.cycles.samples=20;scene.render.resolution_x=1100;scene.render.resolution_y=850;scene.render.resolution_percentage=100;scene.render.filepath=str(REVIEW/(name+'-blender.png'));bpy.ops.render.render(write_still=True)

def stamp(p,loc,scale):
 # Three simple petals, original Lotus cargo mark; geometry, no external logo.
 for i in [-1,0,1]:
  ob=box('Lotus petal',(loc[0]+i*.17*scale,loc[1],loc[2]+(.10 if i==0 else 0)*scale),(.17*scale,.035*scale,.38*scale),orange,p,.06*scale,rot=(0,i*.42,0))

root=empty('LOTUS_HERON',(0,0,0))
box('Freight spine',(0,0,3.0),(2.0,5.6,.7),dark,root,.20)
box('Avionics shell',(0,.75,3.42),(2.3,3.7,.8),cream,root,.30)
box('Nose sensor armour',(0,2.56,3.12),(1.8,.8,.65),teal,root,.22)
box('Sensor glass',(0,2.97,3.18),(1.3,.06,.24),glass,root,.03)
for x in [-.48,.48]:box('Navigation slit',(x,3.005,3.15),(.2,.03,.09),screen,root,.018)
box('Service battery',(0,-2.0,3.22),(1.8,1.7,.72),teal,root,.14)
for y in [-1.7,1.7]:
 box('Load crossbeam',(0,y,2.8),(6.5,.5,.4),steel,root,.10)
 for x in [-3,3]:
  cylinder('Lift duct',(x,y,2.63),(x,y,3.46),.91,cream,root,48)
  cylinder('Intake lining',(x,y,3.46),(x,y,3.49),.72,dark,root,48)
  rotor=empty('Anim_Rotor_'+str(x)+'_'+str(y),(x,y,3.51),root)
  for angle in [0,math.pi/2]:box('Fan blades',(x,y,3.52),(1.29,.14,.055),steel,rotor,.02,rot=(0,0,angle))
  cylinder('Fan hub',(x,y,3.50),(x,y,3.62),.18,teal,root,32)
  cylinder('Thrust nozzle',(x,y,2.5),(x,y,2.65),.57,dark,root,40)
  cylinder('Nozzle glow',(x,y,2.49),(x,y,2.51),.39,screen,root,32)
  empty('Socket_Thrust_'+str(x)+'_'+str(y),(x,y,2.46),root)
for x in [-1.1,1.1]:
 box('Cargo rail',(x,-.05,2.27),(.16,3.0,.23),steel,root,.05)
 clamp=empty('Anim_Clamp_'+str(x),(x,0,2.4),root)
 for y in [-.85,.85]:
  box('Clamp arm',(x,y,1.99),(.16,.28,.68),teal,clamp,.05)
  box('Lock jaw',(x*.85,y,1.7),(.5,.29,.17),orange,clamp,.04)
 box('Rear stabilizer',(x,-2.44,3.89),(.14,1.05,1.05),teal,root,.08,rot=(0,x*.22,0))
stamp(root,(0,2.995,3.74),1.1)
empty('Socket_Crate',(0,0,.18),root)
export('heron');review('heron',(0,0,2.2),11)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
root=empty('LOTUS_SupplyCrate',(0,0,0))
box('Impact pallet',(0,0,.14),(1.9,1.6,.28),dark,root,.09)
box('Sealed cargo tub',(0,0,.72),(1.72,1.43,1.02),teal,root,.14)
for x in [-.79,.79]:
 for y in [-.64,.64]:
  box('Corner crash guard',(x,y,.77),(.20,.19,1.11),cream,root,.06)
  box('Impact foot',(x,y,.10),(.33,.33,.20),rubber,root,.05)
  cylinder('Compression piston',(x,y,.25),(x,y,.52),.047,steel,root)
lid=empty('Anim_Lid',(0,-.65,1.27),root)
box('Hinged pressure lid',(0,0,1.32),(1.82,1.53,.20),cream,lid,.07)
for x in [-.61,.61]:
 box('Cargo tie',(x,0,1.43),(.12,1.34,.045),dark,lid,.015)
 box('Release latch',(x,.755,1.17),(.19,.10,.25),orange,lid,.03)
 cylinder('Grab rail',(x,-.3,1.48),(x,.3,1.48),.038,orange,lid)
box('Recessed label',(0,.724,.79),(.83,.035,.53),dark,root,.035)
stamp(root,(0,.751,.77),.78)
box('Status lamp',(.60,.744,.77),(.07,.04,.32),screen,root,.02)
export('supply_crate');review('supply_crate',(0,0,.7),3.6)
print('LOTUS_ASSETS_COMPLETE')
