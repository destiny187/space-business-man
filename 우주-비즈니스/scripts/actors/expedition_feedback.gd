class_name FrontierExpeditionFeedback
extends Node3D

# Presentation consumes accepted commands; it never mutates world or inventory.
var app: FrontierCrewExpedition
var audio: FrontierAudio
var effects: FrontierEffects
var equipped_model: String="manual_tool"
var handheld: Node3D
var muzzle: OmniLight3D
var parts: Array[Node]=[]
var pending: Dictionary={}
var recoil:=0.0
var elapsed:=0.0
var work_left:=0.0
var audio_tick:=0.0
var scan_tick:=0.0
var industry_tick:=0.0
var scan_bar: ProgressBar
var cue: FrontierResourceReadout
var cue_left:=0.0
var observed_body: String=""
var known_buildings: Dictionary={}
var known_robots: Dictionary={}
var known_observations:=0
var last_veins: Dictionary={}
var cache: Dictionary={}

func configure(owner_app: FrontierCrewExpedition) -> void:
	app=owner_app
	audio=FrontierAudio.new();add_child(audio)
	effects=FrontierEffects.new();add_child(effects)
	handheld=load("res://assets/models/manual_tool.glb").instantiate()
	FrontierInkStyle.apply(handheld,cache);app.camera.add_child(handheld)
	handheld.position=Vector3(.36,-.30,-.92);handheld.scale=Vector3.ONE*.72
	handheld.set_meta("intake_offset",Vector3(0,0,-.78));handheld.hide()
	parts=handheld.find_children("Anim_*","Node3D",true,false)
	for part in parts:part.set_meta("rest",part.position)
	muzzle=OmniLight3D.new();muzzle.position=Vector3(0,0,-.78);muzzle.omni_range=4;muzzle.light_color=Color("ffc07c");muzzle.light_energy=0;handheld.add_child(muzzle)
	var hud:=CanvasLayer.new();add_child(hud)
	scan_bar=ProgressBar.new();scan_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE;scan_bar.custom_minimum_size=Vector2(160,8);scan_bar.show_percentage=false;hud.add_child(scan_bar);scan_bar.hide()
	cue=FrontierResourceReadout.new();cue.theme=app.ui_theme;cue.mouse_filter=Control.MOUSE_FILTER_IGNORE;cue.custom_minimum_size=Vector2(360,40);hud.add_child(cue);cue.hide()
	app.session.request_started.connect(_requested)
	app.session.response_received.connect(_response)
	app.session.surface_received.connect(_surface)

func blocked() -> bool:
	return app.any_menu_open() or (app.arrival!=null and app.arrival.active) or FrontierCursorPolicy.modal_open(get_tree()) or app.inventory_panel.visible or app.business_panel.visible or app.shipyard_panel.visible or app.research_frame.visible or app.navigation_frame.visible or FrontierClientSettings.ensure(get_tree()).is_open()

func _requested(sequence: int,kind: String,args: Dictionary) -> void:
	if app.surface_world==null:return
	# Keep the point at request time, including when the client turns while awaiting the host.
	var point:=app.camera.global_position-app.camera.global_basis.z*4
	var query:=PhysicsRayQueryParameters3D.create(app.camera.global_position,app.camera.global_position-app.camera.global_basis.z*12)
	query.exclude=[app.actors[app.session.latest.self_id].get_rid()]
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():point=hit.position
	var resource: String="stone"
	if kind=="business_mine":
		var vein:=FrontierExpeditionBusiness.find_vein(app.surface_world.body,str(args.get("vein_id","")))
		if not vein.is_empty():resource=vein.resource
	if args.has("position"):point=FrontierCrewWorld.vector(args.position)
	pending[sequence]={"kind":kind,"point":point,"resource":resource,"body":app.surface_world.body.id,"created":Time.get_ticks_msec()}

func reject(message: String="배치할 수 없습니다") -> void:
	audio.play("sfx_build_invalid");app.reticle.modulate=Color("ff826d");cue.value=message;cue_left=.8;cue.show()

func _response(sequence: int,value: Dictionary) -> void:
	if not pending.has(sequence):return
	var request: Dictionary=pending[sequence];pending.erase(sequence)
	if app.surface_world==null or app.surface_world.body.id!=request.body:return
	if not value.get("ok",false):reject(str(value.get("error","작업할 수 없습니다")));return
	var point: Vector3=request.point
	match request.kind:
		"business_craft":audio.play("sfx_build_place");show_cue("로봇 조립 시작")
		"surface_attack":
			recoil=1;effects.pulse(handheld.to_global(Vector3(0,0,-.78)),point);effects.burst(point,Color("ffb578"),10);audio.play("sfx_combat_pulse")
		"equipment_upgrade","equipment_suit_upgrade":audio.play("sfx_factory_complete");show_cue("Mk.2 개조 완료")
		"business_produce":audio.play("sfx_build_place");show_cue("제품 생산 예약")
		"business_facility_upgrade","business_robot_upgrade":effects.construction(point);audio.play("sfx_factory_complete");show_cue("Mk.2 개조 완료")
		"equipment_craft":audio.play("sfx_factory_complete");show_cue("제작 완료 · 아이템창에서 슬롯에 장착하세요")
		"equipment_equip","equipment_select":audio.play("sfx_build_place");work_left=0;recoil=.3;cue_left=0
		"surface_dig":
			recoil=1;work_left=.25;effects.pulse(handheld.to_global(Vector3(0,0,-.78)),point)
			effects.suction(point,handheld,"stone",4);audio.play("sfx_combat_pulse")
		"business_mine":
			cue_left=0;recoil=.3;work_left=.4;effects.suction(point,handheld,request.resource,6)
			effects.burst(point,Color(FrontierCatalog.entry("resources",request.resource).color),8)
			audio.play("sfx_mine_hit_metal",point);audio.play("sfx_pickup_resource")
		"business_withdraw","business_deposit","business_recover_crate","surface_collect","surface_resupply":
			effects.burst(point,Color("82f5d2"),10);audio.play("sfx_pickup_resource");show_cue("인수 완료")
		"business_build":
			# The shared surface packet presents construction to every observer.
			show_cue("건설 완료")
		"business_register","business_toggle","business_demolish":
			effects.construction(point);audio.play("sfx_build_place",point)
		"surface_analyze","surface_restore","surface_introduce","business_research_install":
			effects.construction(point);audio.play("ui_discovery");show_cue("연구 · 생태 기록 갱신")
		"business_settle":audio.play("ui_planet_sold");show_cue("복원 계약 정산 완료")
		_:audio.play("sfx_pickup_resource")

func show_cue(text: String) -> void:
	cue.value=text;cue_left=1.8;cue.show();app.reticle.modulate=Color("82f5d2")

func _surface(packet: Dictionary) -> void:
	if app.surface_world==null:return
	var site: Dictionary=packet.get("business",{}).get("sites",{}).get(packet.body_id,{})
	var buildings: Dictionary=site.get("buildings",{})
	var robots: Dictionary=site.get("robots",{})
	var observations: int=packet.get("ecology",{}).get("observations",{}).size()
	if observed_body==str(packet.body_id)+":"+str(packet.epoch):
		for id in buildings:
			if not known_buildings.has(id):
				var p:=FrontierCrewWorld.vector(buildings[id].position)
				effects.construction(p);audio.play("sfx_build_place",p)
		for id in buildings:
			if known_buildings.has(id) and int(buildings[id].get("product_serial",0))>int(known_buildings[id].get("product_serial",0)):
				var p:=FrontierCrewWorld.vector(buildings[id].position)
				effects.construction(p);audio.play("sfx_factory_complete",p)
		for id in robots:
			if not known_robots.has(id):
				var p:=FrontierCrewWorld.vector(robots[id].position)
				effects.construction(p);audio.play("sfx_factory_complete",p)
		if observations>known_observations:audio.play("ui_discovery");show_cue("새 생명체 기록")
		for vein in FrontierExpeditionBusiness.veins(app.surface_world.body,app.camera.global_position):
			if float(last_veins.get(vein.id,0))>0 and float(site.get("remaining",{}).get(vein.id,0))<=0:
				var p:=FrontierMineralWorld.point(app.surface_world.terrain.field,vein)
				if p.is_finite():effects.burst(p,Color(FrontierCatalog.entry("resources",vein.resource).color),24);audio.play("sfx_mine_break",p)
	observed_body=str(packet.body_id)+":"+str(packet.epoch)
	known_buildings=buildings.duplicate(true);known_robots=robots.duplicate();known_observations=observations;last_veins=site.get("remaining",{}).duplicate()

func _process(delta: float) -> void:
	if app==null:return
	elapsed+=delta;work_left=maxf(0,work_left-delta);cue_left=maxf(0,cue_left-delta)
	var active: bool=app.session.active and app.surface_world!=null
	var enabled: bool=active and not blocked() and app.placement_kind.is_empty()
	var tool: Dictionary={}
	if active:tool=FrontierEquipment.active(app.session.latest.crew.members[app.session.latest.self_id])
	if not tool.is_empty() and tool.model!=equipped_model:_replace_tool(tool.model)
	handheld.visible=enabled and not tool.is_empty()
	effects.running=active
	if not active:
		effects.clear();observed_body="";pending.clear()
	for sequence in pending.keys():
		if Time.get_ticks_msec()-int(pending[sequence].created)>15000:pending.erase(sequence)
	recoil=move_toward(recoil,0,delta*5);muzzle.light_energy=pow(recoil,4)*2
	var moving: bool=active and app.actors[app.session.latest.self_id].velocity.length()>1
	handheld.position=Vector3(.36,-.30+sin(elapsed*(9 if moving else 2))*(.018 if moving else .005),-.92+recoil*.13)
	handheld.rotation=Vector3(recoil*.16,0,-.03)
	for part in parts:
		if part.name.begins_with("Anim_Fan"):part.rotate_z(delta*(30 if work_left>0 else 2))
		elif part.name.begins_with("Anim_Piston") or part.name.begins_with("Anim_Collar"):part.position=part.get_meta("rest")+Vector3(0,0,recoil*.075)
	var scanning: bool=enabled and float(app.session.latest.get("scan",{}).get("progress",0))>0 and not app.session.latest.get("scan",{}).get("known",false)
	audio.set_suction(1 if enabled and work_left>0 else (.35 if scanning else 0))
	var size:=get_viewport().get_visible_rect().size
	cue.position=Vector2(size.x/2-180,size.y/2+45);cue.visible=enabled and cue_left>0
	if cue_left<=0:app.reticle.modulate=Color.WHITE
	var progress: float=float(app.session.latest.get("scan",{}).get("progress",0))
	scan_bar.position=Vector2(size.x/2-80,size.y/2+22);scan_bar.value=progress*100;scan_bar.visible=enabled and progress>0 and not app.session.latest.get("scan",{}).get("known",false)
	scan_tick-=delta
	if scan_bar.visible and scan_tick<=0:
		scan_tick=.22
		var encounter: String=str(app.session.latest.get("scan",{}).get("id",""))
		if app.surface_world.ecology.actors.has(encounter):
			var subject: Node3D=app.surface_world.ecology.actors[encounter]
			effects.burst(subject.global_position+Vector3.UP*.5,Color("64dce6"),3)
		elif app.session.latest.get("scan",{}).has("point"):
			effects.burst(FrontierCrewWorld.vector(app.session.latest.scan.point)+Vector3.UP,Color("64dce6"),3)
	industry_tick-=delta
	if enabled and industry_tick<=0:
		industry_tick=.65;_industry_effects()
	audio_tick-=delta
	if audio_tick<=0:
		audio_tick=.2;_update_audio(active)

func _update_audio(active: bool) -> void:
	if not active:audio.update_world({},false);return
	var site: Dictionary=app.session.surface.get("business",{}).get("sites",{}).get(app.surface_world.body.id,{})
	var player: Vector3=app.actors[app.session.latest.self_id].position
	var state: Dictionary={"environment":{"ecology":site.get("environment",{}).get("ecology",0)},"player":{"position":[player.x,player.z]},"robots":[],"buildings":[],"events":[]}
	# Convert only presentation coordinates. The authoritative 3D positions stay unchanged.
	var heights: Dictionary={}
	for category in ["robots","buildings"]:
		for row in site.get(category,{}).values():
			var p:=FrontierCrewWorld.vector(row.position)
			if p.distance_to(player)>35:continue
			var record: Dictionary=row.duplicate();record.position=[p.x,p.z]
			if category=="robots" and record.status in ["창고로 운반","충전기 복귀"]:record.status="자원 운반"
			state[category].append(record);heights[row.id]=p.y
	audio.update_world(state,blocked())
	for id in audio.emitters:
		if heights.has(id):audio.emitters[id].position.y=float(heights[id])+.8

func _industry_effects() -> void:
	var site: Dictionary=app.session.surface.get("business",{}).get("sites",{}).get(app.surface_world.body.id,{})
	var visuals: Dictionary=app.surface_world.business_view.nodes
	for robot in site.get("robots",{}).values():
		if not visuals.has(robot.id):continue
		var actor: Node3D=visuals[robot.id]
		if actor.global_position.distance_to(app.camera.global_position)>25:continue
		if robot.status=="채광 중":
			var vein:=FrontierExpeditionBusiness.find_vein(app.surface_world.body,robot.target)
			if vein.is_empty() or not visuals.has(vein.id):continue
			effects.suction(visuals[vein.id].global_position+Vector3.UP,actor,vein.resource,4)
		elif robot.status=="충전 중":effects.burst(actor.global_position+Vector3.UP*.5,Color("82f5d2"),3)
	for building in site.get("buildings",{}).values():
		if not visuals.has(building.id) or not building.active:continue
		if building.type=="factory" and not building.get("production",{}).is_empty():
			var actor: Node3D=visuals[building.id]
			if actor.global_position.distance_to(app.camera.global_position)<25:effects.burst(actor.global_position+Vector3.UP*1.5,Color("efb46f"),3)
		if building.type not in ["atmosphere","thermal","water","biolab"]:continue
		var actor: Node3D=visuals[building.id]
		if actor.global_position.distance_to(app.camera.global_position)>25:continue
		var color: Color={"atmosphere":Color("c4e8e2"),"thermal":Color("ffc487"),"water":Color("71caf4"),"biolab":Color("8bdd82")}[building.type]
		effects.burst(actor.global_position+Vector3.UP*2,color,2)

func _replace_tool(model: String) -> void:
	handheld.get_parent().remove_child(handheld);handheld.queue_free()
	equipped_model=model;handheld=load("res://assets/models/"+model+".glb").instantiate()
	FrontierInkStyle.apply(handheld,cache);app.camera.add_child(handheld);handheld.scale=Vector3.ONE*(.72 if model in ["manual_tool","equipment/miner_mk2"] else .5)
	handheld.set_meta("intake_offset",Vector3(0,0,-.78))
	parts=handheld.find_children("Anim_*","Node3D",true,false)
	for part in parts:part.set_meta("rest",part.position)
	muzzle=OmniLight3D.new();muzzle.position=Vector3(0,0,-.78);muzzle.omni_range=4;muzzle.light_color=Color("ffc07c");muzzle.light_energy=0;handheld.add_child(muzzle)
