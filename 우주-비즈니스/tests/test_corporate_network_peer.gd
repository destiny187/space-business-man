extends "res://tests/test_crew_peer.gd"
var held:=false
var target_id:=""
var m: Dictionary={}
var fixture_serial:=0
func run() -> void:
 var options: Dictionary={}
 for argument in OS.get_cmdline_user_args():
  if argument.contains("="):
   var pair:=argument.split("=",true,1);options[pair[0]]=pair[1]
 folder=options["--crew-folder"];role=options["--crew-role"]
 identity=FrontierPlayerProfile.new(folder+"/profile.json");identity.ensure(role)
 if role=="host" and not FileAccess.file_exists(folder+"/world.json"):
  var core:=FrontierCrewAuthority.new();core.start(FrontierUniverse.new_world(61739),identity.data.character,func(_w):return true)
  FrontierWorldStore.new(folder+"/world.json").write(core.world)
 m=FrontierUniverse.new_world(61739).manifest
 crew=FrontierCrewSession.new();crew.name="Coop";root.add_child(crew)
 crew.notice.connect(func(message: String):messages.append(message))
 crew.response_received.connect(func(sequence: int,result: Dictionary):responses.append({"sequence":sequence,"result":result}))
 if role=="host":crew.host(identity,FrontierWorldStore.new(folder+"/world.json"),int(options["--crew-port"]),"127.0.0.1")
 else:crew.join(identity,"127.0.0.1",int(options["--crew-port"]))
func _process(delta: float) -> bool:
 if crew==null:return false
 elapsed+=delta
 if elapsed<.08:return false
 elapsed=0
 var command_path:=folder+"/command.json"
 if FileAccess.file_exists(command_path):
  var command: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(command_path));DirAccess.remove_absolute(command_path)
  match command.kind:
   "request":crew.send_request(command.action,command.get("args",{}))
   "hold":held=command.value;target_id=command.get("id",target_id)
   "fixture":fixture(command)
   "ground":ground_fixture(command)
   "attack":ground_action(command.get("cargo",false))
   "close":held=false;close_peer()
 if crew.active and not target_id.is_empty() and not crew.latest.is_empty():
  var nav: Dictionary=crew.latest.crew.navigation;var point: Vector3
  if target_id.begins_with("trace:"):
   point=FrontierCrewWorld.vector(FrontierCorporateTraces.definition(m,target_id,float(nav.orbit_time)).position)
  else:
   var row:=FrontierFreightSalvage.definition(m,target_id,float(nav.orbit_time));var stage:=int(crew.latest.crew.get("freight_records",{}).get(target_id,{}).get("stage",0))
   point=FrontierCrewWorld.vector(FrontierFreightSalvage.endpoint(row,stage))
  crew.send_input(Vector2.ZERO,(point-FrontierCrewWorld.vector(nav.position)).normalized(),held)
 var state: Dictionary={"active":crew.active,"snapshot":crew.latest,"messages":messages,"responses":responses,"character":identity.data.character,"fixture_serial":fixture_serial}
 if crew.hosting:state.saved=crew.authority.world.crew;state.error=crew.authority.error
 var output:=FileAccess.open(folder+"/status.tmp",FileAccess.WRITE);output.store_string(JSON.stringify(state));output.close();DirAccess.rename_absolute(folder+"/status.tmp",folder+"/status.json")
 return false
func fixture(command: Dictionary) -> void:
 if not crew.hosting:return
 var w: Dictionary=crew.authority.world;var nav: Dictionary=w.crew.navigation;var id: String=command.id
 var row: Dictionary=FrontierCorporateTraces.definition(m,id) if id.begins_with("trace:") else FrontierFreightSalvage.definition(m,id)
 var stage:=int(FrontierFreightSalvage.records(w).get(id,{}).get("stage",0))
 var point:=FrontierCrewWorld.vector(row.position if id.begins_with("trace:") else FrontierFreightSalvage.endpoint(row,stage))
 nav.system=row.system;nav.target=row.body;nav.position=FrontierExpeditionBusiness.array(point+Vector3(0,0,float(command.distance)));nav.orbit_time=0;nav.mode="idle";nav.speed=0;nav.direction=[0,0,-1];nav.manual=true;nav.erase("freight_anchor")
 w.location=row.body_id;w.navigation_target=row.body_id;w.flight_position=nav.position.duplicate();w.crew.pilot_id=command.pilot;w.crew.landing={}
 for member in w.crew.members.values():member.aboard=true;member.area="cabin"
 fixture_serial+=1;crew._publish()
func ground_fixture(command: Dictionary) -> void:
 if not crew.hosting:return
 var w: Dictionary=crew.authority.world;var clue:=FrontierCooperTechClues.describe(w,command.id);var actor: String=command.actor
 var body:=FrontierUniverse.body(m,clue.body);w.location=body.id;w.navigation_target=body.id;w.crew.landing={};w.crew.pilot_id=actor
 var nav: Dictionary=w.crew.navigation;nav.system=body.system_ordinal;nav.target=clue.body;nav.position=FrontierExplorationIncidents.array(FrontierCrewNavigation.center(clue.body,m,float(nav.orbit_time))+Vector3.UP*(FrontierUniverse.navigation_radius(body)+1))
 for member in w.crew.members.values():member.ready=true;member.aboard=true
 var error:=FrontierCrewSurface.apply(w,actor,"land",{},crew.authority.peers)
 if not error.is_empty():printerr("GROUND_FIXTURE ",error);return
 var row: Dictionary=w.incidents.records[clue.incident];var member: Dictionary=w.crew.members[actor];member.aboard=false;member.area="surface"
 var point:=FrontierExplorationIncidents.point(row,Vector3(0,0,2));point.y=FrontierCrewSurface.field(w).height(point.x,point.z)+.1
 member.position=FrontierExplorationIncidents.array(point);member.loadout.items["fixture:pulse_2"]="pulse_2";member.loadout.slots[0]="fixture:pulse_2";member.loadout.selected=0
 fixture_serial+=1;crew._publish()
func ground_action(cargo: bool) -> void:
 var clue: Dictionary=crew.latest.coopertech_clues.values()[0];var row: Dictionary=crew.latest.incidents.records.get(clue.incident,{})
 if row.is_empty():return
 var point:=FrontierExplorationIncidents.cargo_point(row) if cargo else FrontierExplorationIncidents.point(row,Vector3(0,1.5,0))
 var origin:=FrontierCrewWorld.vector(crew.latest.crew.members[crew.latest.self_id].position)+Vector3.UP*1.72
 crew.send_request("surface_incident" if cargo else "surface_incident_tool",{"id":clue.incident,"part":"cargo" if cargo else "robot","aim":FrontierExplorationIncidents.array((point-origin).normalized())})
