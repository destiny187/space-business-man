extends SceneTree
class Chambers extends FrontierTerrainField:
 var breached:=false
 func height(_x: float,_z: float) -> float:return 8.0
 func density(p: Vector3) -> float:
  var left:=AABB(Vector3(0,0,0),Vector3(3,5,3)).has_point(p)
  var right:=AABB(Vector3(4,-3,0),Vector3(3,5,3)).has_point(p)
  var tunnel:=breached and AABB(Vector3(2,0,1),Vector3(3,1,1)).has_point(p)
  return -1.0 if left or right or tunnel else 1.0
var failures:=0
var checks:=0
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok:failures+=1;printerr("FAIL ",label)
 else:print("PASS ",label)
func mass(record: Dictionary) -> float:
 var total:=0.0
 for row in record.cells.values():total+=float(row[0])
 return total
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var field:=Chambers.new();field.configure(42)
 var solver:=FrontierSurfaceWater.new();solver.configure(field);solver.original=field;solver.native=false
 var state:=FrontierSurfaceWater.create()
 for x in 3:
  for y in 4:
   for z in 3:state.cells[FrontierSurfaceWater.key(Vector3i(x,y,z))]=[1.0,0.0]
 var centers: Array[Vector3]=[Vector3(3,1,1)]
 solver.bind(state,field,[],centers)
 for i in 120:solver.step(.1)
 var dry:=true
 for k in state.cells:
  if FrontierSurfaceWater.point(k).x>=4 and state.cells[k][0]>.001:dry=false
 check(dry,"sealed adjacent cave stays dry")
 check(absf(mass(state)-36)<.00001,"closed water conserves volume")
 field.breached=true;solver.cache.clear();solver.faces.clear()
 for i in 1000:solver.step(.1)
 var below:=0.0;var raised:=0.0
 for k in state.cells:
  var p:=FrontierSurfaceWater.point(k)
  if p.x>=4 and p.y<0:below+=state.cells[k][0]
  if p.x>=4 and p.y==0:raised+=state.cells[k][0]
 check(below>10,"breach admits downward flow into cave")
 check(raised>0.05,"connected basin fills upward after lower cells fill")
 check(absf(mass(state)-36)<.00001,"downward and pressure flow conserve volume")
 var saved: Dictionary=JSON.parse_string(JSON.stringify(state))
 check(FrontierSurfaceWater.valid(saved) and absf(mass(saved)-36)<.00001,"JSON save/load preserves physical volume")
 var packet:=FrontierSurfaceWater.packet(saved,centers[0])
 check(FrontierSurfaceWater.valid(packet,4096) and packet.cells==saved.cells,"nearby replica carries actual cells")
 var frozen:=mass(state);var copy:=state.duplicate(true);solver.interests.clear()
 for i in 5:solver.step(.1)
 check(copy.cells==state.cells and mass(state)==frozen,"inactive water freezes without losing volume")
 var bad:=saved.duplicate(true);bad.cells["bad"]=[1,0];check(not FrontierSurfaceWater.valid(bad),"malformed cell keys rejected")
 bad=saved.duplicate(true);bad.cells["1:0:0"]=[7,0];check(not FrontierSurfaceWater.valid(bad),"out of range mass rejected")
 var body:=CharacterBody3D.new();root.add_child(body);body.position=Vector3(100,100,100)
 var motion:=FrontierCrewLocomotion.create()
 FrontierCrewLocomotion.step(body,motion,Vector2.RIGHT,6,14,0,.1,true,1.6)
 check(body.velocity.y>0 and body.velocity.x<2.9,"immersion applies buoyancy and horizontal drag")
 body.velocity=Vector3.ZERO;motion.grounded=true
 FrontierCrewLocomotion.step(body,motion,Vector2.ZERO,6,14,0,1.0/60.0,true,1.6)
 check(body.velocity.y>0,"full immersion can lift a grounded character at 60 Hz")
 body.queue_free()
 print("WATER_CHECKS ",checks," FAILURES ",failures," cells ",state.cells.size()," peak_us ",solver.maximum_usec," below ",below," raised ",raised)
 quit(1 if failures else 0)
