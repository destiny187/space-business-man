extends SceneTree
var checks:=0
var failures:=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,name: String) -> void:
	checks+=1
	if not ok:failures+=1;printerr("FAIL ",name)
	else:print("PASS ",name)
func run() -> void:
	var host:=FrontierPlayerProfile.new_character("회수 호스트",0);var guest:=FrontierPlayerProfile.new_character("FINCH 조종사",1)
	var authority:=FrontierCrewAuthority.new();authority.start(FrontierUniverse.new_world(61739),host,func(_w):return true);authority.phase="playing"
	check(authority.admit(2,guest,"",int(FrontierCrewWorld.config().protocol),FrontierCrewWorld.content_hash()).ok and authority.acknowledge(2,authority.session_id).ok,"second peer enters through admission and acknowledgement")
	var world: Dictionary=authority.world;var id: String=guest.character_id;var nav: Dictionary=world.crew.navigation
	nav.erase("solar_opening");nav.mode="idle";nav.manual=true;nav.system=1000;nav.target=FrontierUniverse.first_ordinal(world.manifest,1000);nav.position=[0.0,4000.0,0.0];nav.direction=[0.0,0.0,-1.0];nav.speed=0.0
	for i in range(10,60):
		var p:=Vector3(0,i*400,0)
		if FrontierSpaceCombat.clear_position(world,1000,p,1200):nav.position=FrontierSpaceCombat.arr(p);break
	world.crew.landing={};world.location=FrontierUniverse.body_id(world.manifest,int(nav.target));world.navigation_target=world.location
	world.crew.shuttles={id:{"state":"sortie","pad_slot":1,"progress":0.0,"factory_id":"","system":1000,"location":world.location,"navigation_target":world.location,"navigation":nav.duplicate(true),"landing":{},"cargo":{"copper":3},"cargo_equipment":{},"rock":0}}
	world.crew.members[id].shuttle_id=id;world.crew.members[id].aboard=true
	check(FrontierSpaceCombat.begin(world,"shuttle:"+id,"local_transit"),"guest FINCH enters local encounter")
	check(not FrontierSpaceCombat.fire(world,id,Vector3.FORWARD),"guest cannot fire a main ship gun from FINCH")
	var a:=authority.snapshot(1);var b:=authority.snapshot(2)
	check(a.crew.space_combat.encounter==b.crew.space_combat.encounter and b.local_shuttle==id,"host and guest snapshots share the same encounter and separate carrier context")
	var request: Dictionary={"session_id":authority.session_id,"sequence":1,"kind":"shuttle_recall","args":{"character_id":id},"revision":world.crew.revision}
	check(not authority.request(1,request).ok,"connected FINCH cannot be recalled through combat")
	check(authority.disconnect_member(2),"guest disconnect preserves shuttle")
	request.revision=authority.world.crew.revision
	check(authority.request(1,request).ok,"host can explicitly recover offline FINCH during held encounter")
	world=authority.world
	check(world.crew.space_combat.encounter.is_empty() and world.crew.shuttles[id].state=="docked" and world.crew.shuttles[id].cargo.copper==3 and not world.crew.shuttles[id].navigation.combat_active,"durable recall clears encounter and preserves cargo without stranding travel")
	print("PIRATE_RECALL_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
