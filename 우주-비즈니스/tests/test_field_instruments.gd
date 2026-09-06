extends "res://tests/test_solo_entry.gd"
## Focused real-window flow. Fixtures isolate movement, fall damage and exact receipts.
func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--crew-folder="):folder=argument.trim_prefix("--crew-folder=")
	root.size=Vector2i(1280,800)
	app=load("res://scenes/app/crew_expedition.tscn").instantiate();root.add_child(app);current_scene=app
	await process_frame
	app.world_store.write(FrontierUniverse.new_world(112052220));app.start_solo(true)
	if not await until(func():return app.session.active,"solo opens",15):quit(1);return
	app.travel_action("land")
	if not await until(func():return app.surface_world!=null and app.surface_world.ready_at(app.actors[app.session.latest.self_id].position),"landing ready",60):quit(1);return
	var id: String=app.session.latest.self_id
	var authority:=app.session.authority
	var actor: CharacterBody3D=app.actors[id]
	await create_timer(1).timeout
	var origin:=actor.position
	app.test_direction=Vector2(1,0)
	await create_timer(.5).timeout
	var walk: float=Vector2(actor.velocity.x,actor.velocity.z).length()
	app.test_sprint=true
	await create_timer(.6).timeout
	var sprint: float=Vector2(actor.velocity.x,actor.velocity.z).length()
	check(sprint>walk*1.3 and authority.world.crew.members[id].vitals.stamina<100,"host sprint increases speed and consumes stamina")
	app.test_direction=Vector2.ZERO;app.test_sprint=false
	var drained: float=authority.world.crew.members[id].vitals.stamina
	await create_timer(1.5).timeout
	check(authority.world.crew.members[id].vitals.stamina>drained,"stamina recovers after delay")
	# Tiny stamina fixture reaches exhaustion without a long repetitive run.
	authority.world.crew.members[id].vitals.stamina=.2
	app.test_direction=Vector2(1,0);app.test_sprint=true
	await create_timer(.25).timeout
	check(authority.world.crew.members[id].vitals.exhausted and not authority.world.crew.members[id].vitals.sprinting,"exhaustion forces walking")
	app.toggle_inventory();await create_timer(.2).timeout
	check(not authority.world.crew.members[id].vitals.sprinting and authority.direction_for(1)==Vector2.ZERO,"menu blocks held sprint")
	app.test_direction=Vector2.ZERO;app.test_sprint=false;app.inventory_panel.hide()
	# Falling velocity is simulated by CharacterBody3D collision, not a damage RPC.
	actor.position=origin+Vector3.UP*4;actor.velocity=Vector3.ZERO
	await create_timer(.1).timeout
	actor.velocity=Vector3(0,-18,0)
	var before_damage: int=authority.world.crew.members[id].vitals.damage_serial
	if not await until(func():return authority.world.crew.members[id].vitals.damage_serial>before_damage,"landing collision causes real health damage",8):quit(1);return
	await create_timer(.15).timeout
	check(authority.world.crew.members[id].vitals.health<100,"health reflects fall damage")
	await capture("damage")
	var member: Dictionary=authority.world.crew.members[id]
	member.vitals.health=50;member.vitals.hurt=0
	actor.position=origin;actor.velocity=Vector3.ZERO;authority.update_position(1,origin)
	await create_timer(.5).timeout
	check(authority.world.crew.members[id].vitals.health>50,"landing support heals health")
	var loadout_before: Dictionary=authority.world.crew.members[id].loadout.duplicate(true)
	authority.world.crew.members[id].carried=1
	var rescue_before: int=authority.world.crew.members[id].vitals.rescue_serial
	authority.world.crew.members[id].vitals.health=1
	actor.position=origin+Vector3.UP*4;actor.velocity=Vector3.ZERO
	await create_timer(.1).timeout
	actor.velocity=Vector3(0,-22,0)
	if not await until(func():return authority.world.crew.members[id].vitals.rescue_serial>rescue_before,"depleted health triggers host rescue",8):quit(1);return
	check(actor.position.distance_to(FrontierCrewWorld.vector(FrontierCrewSurface.config().landing_spawn_positions[0]))<3,"rescue returns to landing position")
	check(authority.world.crew.members[id].loadout==loadout_before and int(authority.world.crew.members[id].carried)==1,"rescue preserves equipment and cargo")
	app.session.send_request("business_register",{})
	app.session.send_request("equipment_craft",{"definition":"miner_1"});app.session.send_request("equipment_equip",{"item_id":"crafted:1","slot":0})
	# Stable starter vein exists in both old and expanded geology.
	var vein:=FrontierExpeditionBusiness.find_vein(app.surface_world.body,"vein:0")
	var p:=FrontierExpeditionBusiness.ground(app.surface_world.terrain.field,vein.position[0],vein.position[2])
	actor.position=p+Vector3(0,.25,0);actor.velocity=Vector3.ZERO;authority.update_position(1,actor.position)
	var bag_before: int=int(FrontierExpeditionBusiness.bag(authority.world,id).get(vein.resource,0))
	app.session.send_request("business_mine",{"vein_id":vein.id})
	var amount: int=int(FrontierExpeditionBusiness.bag(authority.world,id).get(vein.resource,0))-bag_before
	var instruments:=app.field_hud.instruments
	check(amount>0 and instruments.gains.get(vein.resource,{}).get("amount")==amount,"pickup displays exact committed amount")
	var receipt: Dictionary=authority.world.crew.receipts[id+":"+str(app.session.next_sequence-1)].result
	instruments._response(app.session.next_sequence-1,receipt)
	check(int(instruments.gains.get(vein.resource,{}).get("amount",-1))==amount,"duplicate receipt does not duplicate pickup")
	await create_timer(.7).timeout
	app.session.send_request("business_mine",{"vein_id":vein.id})
	check(int(instruments.gains.get(vein.resource,{}).get("amount",0))>amount,"consecutive mining merges pickup")
	instruments.radar.refresh_contacts()
	check(instruments.radar.relief!=null and not instruments.radar.contacts.is_empty(),"radar renders local relief and deposits")
	await capture("field-instruments")
	root.size=Vector2i(960,640);root.content_scale_size=Vector2i(960,640)
	await capture("field-instruments-960")
	check(instruments.radar.get_global_rect().end.x<=960 and instruments.vitals_box.get_global_rect().end.y<572,"small viewport keeps radar and vitals above controls")
	check(app.session._valid_snapshot(authority.snapshot(1)),"vitals snapshot passes client validation")
	var retained: Dictionary=authority.world.crew.members[id].vitals.duplicate(true)
	check(await app.session.close_session(),"vitals checkpoint saves")
	var saved:=FrontierWorldStore.new(folder+"/world.json").read_state()
	check(not saved.is_empty() and saved.crew.members[id].vitals.health==retained.health,"saved health retained")
	var resumed:=FrontierCrewAuthority.new()
	check(resumed.start(saved,saved.crew.members[id].profile,func(_world: Dictionary):return true) and resumed.world.crew.members[id].vitals.health==retained.health,"reconnect retains health")
	var invalid:=saved.duplicate(true);invalid.crew.members[id].vitals.stamina=-1
	check(not FrontierCrewWorld.validate(invalid.crew).is_empty(),"invalid vitals rejected")
	# Existing saves without vitals are upgraded at host admission.
	saved.crew.members[id].erase("vitals")
	check(resumed.start(saved,saved.crew.members[id].profile,func(_world: Dictionary):return true) and resumed.world.crew.members[id].vitals.health==100,"old member migrates safely")
	print("FIELD_CHECKS ",checks," FAILURES ",failures);quit(1 if failures else 0)
