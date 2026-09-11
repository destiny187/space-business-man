extends RefCounted
const Rules=preload("res://scripts/domain/storm_archive.gd")
static func build(view: Node3D,row: Dictionary,nodes: Dictionary) -> void:
 var mesh:=ImmediateMesh.new();mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
 var radius: float=Rules.config().radius
 for i in 64:
  var corners: Array[Vector3]=[]
  for angle in [float(i)/64.0*TAU,float(i+1)/64.0*TAU]:
   for r in [radius-.14,radius+.14]:
    var at:=FrontierExplorationIncidents.point(row,Vector3(cos(angle)*r,0,sin(angle)*r))
    at.y=view.surface.terrain.field.height(at.x,at.z)+.10
    corners.append(nodes.root.to_local(at))
  for index in [0,1,2,1,3,2]:mesh.surface_set_normal(Vector3.UP);mesh.surface_add_vertex(corners[index])
 mesh.surface_end()
 var ring:=MeshInstance3D.new();ring.mesh=mesh;nodes.root.add_child(ring)
 var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.cull_mode=BaseMaterial3D.CULL_DISABLED;ring.material_override=material
 nodes.storm_ring=ring;nodes.storm_material=material;nodes.storm_phase="";nodes.storm_bolts=[];nodes.storm_strikes=int(row.get("storm_strikes",0));nodes.storm_flash_until=0
 for x in [-8.0,8.0]:
  var foot:=FrontierExplorationIncidents.point(row,Vector3(x,0,-1));foot.y=view.surface.terrain.field.height(foot.x,foot.z)+.15
  var chain: Array[Vector3]=[foot+Vector3(0,16,0),foot+Vector3(1.2,11,.8),foot+Vector3(-.9,6,-.5),foot]
  for i in 3:
   var bolt: MeshInstance3D=view.beam(chain[i],chain[i+1],Color("caffff"),.22,view)
   bolt.visible=false;nodes.storm_bolts.append(bolt)
static func update(view: Node3D,row: Dictionary,nodes: Dictionary,stopped: bool) -> String:
 var phase:=Rules.phase(row);var warning: bool=phase=="warning"
 var fresh: bool=int(row.get("storm_strikes",0))>int(nodes.storm_strikes)
 nodes.storm_strikes=int(row.get("storm_strikes",0))
 if fresh and not stopped:nodes.storm_flash_until=Time.get_ticks_msec()+int(float(Rules.config().strike_seconds)*1000)
 var strike: bool=phase=="strike" or (not stopped and Time.get_ticks_msec()<int(nodes.storm_flash_until))
 nodes.storm_material.albedo_color=Color("81dcba") if phase=="grounded" else (Color("ffe0a3") if strike else (Color("f3a144") if warning else Color("607888")))
 nodes.storm_ring.visible=not row.claimed
 for bolt in nodes.storm_bolts:bolt.visible=strike and not stopped
 var distance: float=view.surface.viewer.position.distance_to(FrontierCrewWorld.vector(row.position))
 if not stopped and distance<40:
  if nodes.storm_phase!=phase and warning:view.audio.play("sfx_incident_beacon",FrontierCrewWorld.vector(row.position))
  if fresh:
   view.audio.play("sfx_combat_pulse",FrontierCrewWorld.vector(row.position))
   view.app.feedback.effects.burst(FrontierCrewWorld.vector(row.position)+Vector3.UP,Color("a4e6ff"),12)
 nodes.storm_phase=phase
 if stopped or row.claimed or distance>float(Rules.config().radius)+6:return ""
 if phase=="grounded":return "접지 복구 완료  해치를 열고 연구 기록 회수"
 if warning:return "방전 예고  표시 범위 밖이나 선체 지붕 아래로"
 if strike:return "방전 중  범위 진입 주의"
 return "피뢰 회로 수리 → 배터리 운반 → 전원 소켓 연결"
static func dispose(nodes: Dictionary) -> void:
 for bolt in nodes.get("storm_bolts",[]):
  if is_instance_valid(bolt):bolt.queue_free()
