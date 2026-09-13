extends SceneTree
class ScopeSession extends FrontierCrewSession:
	var snapshots:=0
	var surfaces:=0
	func _ready() -> void:pass
	func _process(_delta: float) -> void:pass
	func _physics_process(_delta: float) -> void:pass
	func _publish() -> void:snapshots+=1
	func _publish_surface() -> void:surfaces+=1
	func _exit_tree() -> void:pass
var failures:=0
func _initialize() -> void:run.call_deferred()
func check(value: bool,label: String) -> void:
	print("PASS " if value else "FAIL ",label)
	if not value:failures+=1
func run() -> void:
	var world:=FrontierWorldStore.new("/tmp/firearm-upgrade-rules/world.json").read_state()
	if world.is_empty():quit(2);return
	var actor: String=world.crew.owner_id;var member: Dictionary=world.crew.members[actor]
	var stock:=FrontierExpeditionBusiness.bag(world,actor)
	stock.iron=50;stock.copper=50
	for definition in ["pulse_1","pistol_1"]:
		var result:=FrontierEquipment.apply(world,actor,"equipment_craft",{"definition":definition})
		var id: String="crafted:"+str(int(member.loadout.counter));var gun:=FrontierFirearms.item(member,id)
		check(result.is_empty() and member.loadout.weapon_states[id].ammo==(0 if definition=="pulse_1" else gun.magazine),"new finite gun empty / pistol loaded "+definition)
	var id: String="fixture:pulse_2";var gun:=FrontierFirearms.item(member,id);var state:=FrontierFirearms.ensure(member,gun)
	check(state.reload_rounds==2,"load retains reserved cartridges")
	var shelf: Dictionary={"inventory":FrontierExpeditionBusiness.inventory(),"stored_equipment":{},"buildings":{},"slot_capacity":48}
	check(FrontierItemInventory.warehouse_equipment(world,actor,{"item_id":id},shelf).is_empty(),"pending magazine can be stored")
	check(shelf.stored_equipment[actor+"/"+id].weapon_states.reload_rounds==2 and not member.loadout.weapon_states.has(id),"stored gun owns reservation exactly once")
	check(FrontierItemInventory.warehouse_equipment(world,actor,{"item_id":id,"withdraw":true},shelf).is_empty(),"stored gun returns")
	member.loadout.slots[2]=id;member.loadout.selected=2
	FrontierFirearms.tick(member,4)
	check(member.loadout.weapon_states[id].ammo==2 and shelf.stored_equipment.is_empty(),"returning reload cannot duplicate reserved rounds")
	var bad: Dictionary=member.loadout.duplicate(true);bad.weapon_states[id].ammo=gun.magazine+1
	check(not FrontierFirearms.validate(bad).is_empty(),"oversized saved magazine rejected")
	world.business.bags[actor]=FrontierExpeditionBusiness.inventory()
	stock=world.business.bags[actor];stock["ammo_light"]=4800;stock.iron=2;stock.copper=1
	check(FrontierFirearms.craft_ammo(world,actor,{"ammunition":"ammo_light","batches":1}).is_empty() and stock.ammo_light==4860,"large ammo stack obeys slots instead of former 4800-unit cap")
	check(FrontierExpeditionBusiness.valid_inventory(stock,FrontierItemInventory.limit()),"large valid ammunition inventory survives storage validation")
	var core:=FrontierCrewAuthority.new();core.world=world;core.phase="playing"
	var session:=ScopeSession.new();root.add_child(session);session.authority=core
	var before: Array=[int(world.crew.revision)-1,core.phase,{}]
	session._publish_request_result({"kind":"equipment_ammo_craft"},{"ok":true},before)
	check(session.snapshots==1 and session.surfaces==0,"ammo commit publishes inventory without surface packet")
	core.completed_requests=[{"peer":1,"sequence":45,"committed":true,"envelope":{"kind":"equipment_ammo_craft"},"result":{"ok":true}}]
	session._drain_completed_requests()
	check(session.snapshots==2 and session.surfaces==0,"asynchronous ammo commit also avoids surface packet")
	core.completed_requests=[{"peer":1,"sequence":46,"kind":"surface_fire","stale":true,"result":{"ok":true}}]
	session._drain_completed_requests()
	check(session.snapshots==2 and session.surfaces==0,"buffered shot avoids unrelated world publication")
	var effects:=FrontierFirearmEffects.new();root.add_child(effects)
	var event: Dictionary={"actor":actor,"serial":90,"family":"shotgun","effect":"breach","origin":[0,0,0],"ballistic":true,"projectiles":[],"contacts":[],"rays":[]}
	for i in 8:event.projectiles.append({"index":i,"velocity":[0,0,-200],"gravity":10,"range":40})
	effects.shot(Vector3.ZERO,event);effects.clear(true)
	check(effects.active.size()==8,"weapon switch preserves all travelling pellets")
	effects.shot(Vector3.ZERO,{"actor":actor,"family":"shotgun","impact_only":true,"shot_serial":90,"retired":[2],"rays":[],"contacts":[]})
	check(effects.active.filter(func(e):return e.age>=e.life).size()==1 and effects.active[2].age>=effects.active[2].life,"one pellet impact retires only that pellet")
	effects.clear();effects.queue_free();session.queue_free();await process_frame
	print("FIREARM_INTEGRITY FAILURES ",failures);quit(1 if failures else 0)
