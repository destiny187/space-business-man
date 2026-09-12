class_name FrontierExpeditionFeedback
extends Node3D
const HANDHELD_LAYER := 1 << 19

# Presentation consumes accepted commands; it never mutates world or inventory.
var app: FrontierCrewExpedition
var audio: FrontierAudio
var effects: FrontierEffects
var equipped_model: String="manual_tool"
var handheld: Node3D
var muzzle: OmniLight3D
var parts: Array[Node]=[]
var swim_lower:=0.0
var pending: Dictionary={}
var optics: FrontierFieldToolEffects
var intake_strength:=0.0
var intake_point:=Vector3.ZERO
var intake_resource: String="stone"
var intake_tick:=0.0
var scan_id: String=""
var scan_was_known:=false
var scan_complete_left:=0.0
var recoil_velocity:=0.0
var recoil:=0.0
var elapsed:=0.0
var work_left:=0.0
var audio_tick:=0.0
var industry_tick:=0.0
var scan_bar: ProgressBar
var cue: FrontierResourceReadout
var cue_left:=0.0
var observed_body: String=""
var known_buildings: Dictionary={}
var known_robots: Dictionary={}
var known_shuttle_state: String=""
var known_observations:=0
var last_veins: Dictionary={}
var cache: Dictionary={}

func configure(owner_app: FrontierCrewExpedition) -> void:
	app=owner_app
	audio=FrontierAudio.new();add_child(audio)
	effects=FrontierEffects.new();add_child(effects)
	optics=FrontierFieldToolEffects.new();add_child(optics)
	handheld=load("res://assets/models/manual_tool.glb").instantiate()
	FrontierInkStyle.apply(handheld,cache);_tool_lighting();app.camera.add_child(handheld)
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
	app.session.snapshot_received.connect(_shuttle_snapshot)

func _shuttle_snapshot(value: Dictionary) -> void:
	var state:=str(value.get("crew",{}).get("shuttles",{}).get(value.get("self_id",""),{}).get("state",""))
	if known_shuttle_state=="assembling" and state=="docked":
		show_cue("FINCH 조립 완료 · 착륙선 옆에서 출발하세요.")
		if not blocked():audio.play("sfx_factory_complete")
	known_shuttle_state=state

func blocked() -> bool:
	return app.any_menu_open() or (app.arrival!=null and app.arrival.active) or FrontierCursorPolicy.modal_open(get_tree()) or app.inventory_panel.visible or app.business_panel.visible or app.shipyard_panel.visible or app.research_frame.visible or app.navigation_frame.visible or FrontierClientSettings.ensure(get_tree()).is_open()

func _requested(sequence: int,kind: String,args: Dictionary) -> void:
	if kind in ["deposit","withdraw"] or kind.begins_with("shuttle_"):
		pending[sequence]={"kind":kind};return
	if app.surface_world==null or kind in ["surface_fire","surface_reload","surface_stance"]:return
	# Keep the point at request time, including when the client turns while awaiting the host.
	var point:=app.camera.global_position-app.camera.global_basis.z*4
	var query:=PhysicsRayQueryParameters3D.create(app.camera.global_position,app.camera.global_position-app.camera.global_basis.z*12)
	query.exclude=[app.actors[app.session.latest.self_id].get_rid()]
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():point=hit.position
	var resource: String="stone"
	if kind=="business_mine":
		var vein:=FrontierExpeditionBusiness.find_vein(app.surface_world.body,str(args.get("vein_id","")))
		if not vein.is_empty():
			resource=vein.resource
			# The target selector can see an ore mesh before a physics ray hits it.
			if app.surface_world.business_view.nodes.has(vein.id):
				var visual: Node3D=app.surface_world.business_view.nodes[vein.id]
				var center:=visual.global_position+Vector3.UP*.55
				if hit.is_empty() or point.distance_to(center)>1.5:point=center
	if args.has("position"):point=FrontierCrewWorld.vector(args.position)
	pending[sequence]={"kind":kind,"point":point,"resource":resource,"body":app.surface_world.body.id,"created":Time.get_ticks_msec()}

func reject(message: String="배치할 수 없습니다") -> void:
	work_left=0;intake_strength=0;optics.reset()
	audio.play("sfx_build_invalid");app.reticle.modulate=Color("ff826d");cue.value=message;cue_left=.8;cue.show()

func _response(sequence: int,value: Dictionary) -> void:
	if not pending.has(sequence):return
	var request: Dictionary=pending[sequence];pending.erase(sequence)
	if request.kind in ["deposit","withdraw"]:
		audio.play("sfx_pickup_resource" if value.get("ok",false) else "sfx_build_invalid");return
	if request.kind.begins_with("shuttle_"):
		if not value.get("ok",false):reject(str(value.get("error","소형선 작업 실패")))
		else:audio.play("sfx_build_place" if request.kind=="shuttle_build" else "sfx_factory_complete");show_cue("FINCH 조립 시작" if request.kind=="shuttle_build" else "FINCH 출동" if request.kind=="shuttle_board" else "이탈 승무원 회수 완료" if request.kind=="shuttle_recall" else "원정선 합류 완료")
		return
	if app.surface_world==null or app.surface_world.body.id!=request.body:return
	if value.get("code")=="mining_cooldown":return
	if not value.get("ok",false):reject(str(value.get("error","작업할 수 없습니다")));return
	var point: Vector3=request.point
	if request.kind in ["business_mine","surface_dig"] and app.surface_world.presence!=null:app.surface_world.presence.mark(point,Vector3.FORWARD,1.0)
	match request.kind:
		"business_assign":audio.play("sfx_build_place");show_cue("로봇 한 대 · 광맥 작업 지시")
		"business_robot_auto":audio.play("sfx_build_place");show_cue("자동 채광 설정 적용")
		"business_craft":audio.play("sfx_build_place");show_cue("로봇 조립 시작")
		"surface_incident_tool":
			work_left=.3;recoil=.5
			var incident_tool:=FrontierEquipment.active(app.session.latest.crew.members[app.session.latest.self_id])
			if incident_tool.get("kind")=="pulse":effects.pulse(handheld.to_global(Vector3(0,0,-.78)),point);audio.play("sfx_combat_pulse")
			else:effects.burst(point,Color("87c6e7"),10);audio.play("sfx_discovery_excavate")
		"surface_incident":
			effects.burst(point,Color("82f5d2"),8);audio.play("sfx_lotus_open")
			var recovered: String=value.get("incident",{}).get("equipment","")
			if recovered!="":show_cue(str(FrontierEquipment.config().items[recovered].name)+" 회수 · I에서 장착")
		"surface_discovery":
			work_left=.28;recoil=.35;effects.burst(point,Color("cbb5ff"),8)
			if FrontierEquipment.active(app.session.latest.crew.members[app.session.latest.self_id]).get("kind")=="terrain":effects.pulse(handheld.to_global(Vector3(0,0,-.78)),point)
		"surface_attack":
			if value.has("water_hit"):point=FrontierCrewWorld.vector(value.water_hit.position)
			recoil_velocity=15;recoil=.65;effects.pulse(handheld.to_global(Vector3(0,0,-.78)),point,not value.has("water_hit"));audio.play("sfx_combat_pulse")
		"equipment_upgrade","equipment_suit_upgrade":audio.play("sfx_factory_complete");show_cue("Mk.2 개조 완료")
		"business_produce":audio.play("sfx_build_place");show_cue("제품 생산 예약")
		"business_facility_upgrade","business_robot_upgrade":effects.construction(point);audio.play("sfx_factory_complete");show_cue("시설·로봇 개조 완료")
		"equipment_craft":audio.play("sfx_factory_complete");show_cue("제작 완료 · 아이템창에서 슬롯에 장착하세요")
		"equipment_equip","equipment_select":audio.play("sfx_build_place");work_left=0;recoil=.3;cue_left=0
		"surface_dig":
			recoil=1;work_left=.25;effects.pulse(handheld.to_global(Vector3(0,0,-.78)),point)
			effects.suction(point,handheld,"stone",4);audio.play("sfx_combat_pulse")
		"business_mine":
			cue_left=0;recoil=0;recoil_velocity=0
			var equipped:=FrontierEquipment.active(app.session.latest.crew.members[app.session.latest.self_id])
			work_left=float(equipped.get("interval",.6))+.16
			intake_point=point;intake_resource=request.resource
			effects.suction(point,handheld,request.resource,12)
			audio.play("sfx_pickup_resource")
		"business_store_equipment","business_withdraw","business_deposit","business_recover_crate","surface_collect","surface_resupply":
			effects.burst(point,Color("82f5d2"),10);audio.play("sfx_pickup_resource");show_cue("인수 완료")
		"business_build":
			# The shared surface packet presents construction to every observer.
			show_cue("건설 완료")
		"business_register","business_lease","business_lease_release","business_toggle","business_demolish":
			effects.construction(point);audio.play("sfx_build_place",point)
		"surface_study","surface_analyze","surface_restore","surface_introduce","business_research_install":
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
	if blocked() or (not app.test_mode and not app.get_window().has_focus()):audio.stop_wildlife_cues()
	var enabled: bool=active and not blocked() and app.placement_kind.is_empty() and (app.rovers==null or app.rovers.seat().is_empty())
	var tool: Dictionary={}
	if active:tool=FrontierEquipment.active(app.session.latest.crew.members[app.session.latest.self_id])
	if not tool.is_empty() and tool.model!=equipped_model:_replace_tool(tool.model)
	handheld.visible=enabled and not tool.is_empty()
	effects.running=active
	if not active:
		effects.clear();observed_body="";pending.clear()
	for sequence in pending.keys():
		if Time.get_ticks_msec()-int(pending[sequence].created)>15000:pending.erase(sequence)
	var mining: bool=enabled and tool.get("kind")=="miner" and work_left>0
	if not enabled:
		work_left=0;intake_strength=0;recoil=0;recoil_velocity=0;scan_complete_left=0
		optics.reset()
	intake_strength=move_toward(intake_strength,1.0 if mining else 0.0,delta*(4.5 if mining else 7.0))
	# Damped spring is reserved for weapons. A loaded extractor stays braced.
	var step:=minf(delta,.04)
	recoil_velocity+=(-recoil*140-recoil_velocity*20)*step
	recoil=maxf(0,recoil+recoil_velocity*step)
	muzzle.light_color=Color("8de8db") if tool.get("kind")=="miner" else Color("ffc07c")
	muzzle.light_energy=0.0 if tool.has("firearm") else intake_strength*.32+pow(recoil,3)*2.4
	var moving: bool=active and app.actors[app.session.latest.self_id].velocity.length()>1
	var swimming: bool=active and app.visuals[app.session.latest.self_id].get("motion",{}).get("state","") in ["swim","tread"]
	swim_lower=lerpf(swim_lower,1.0 if swimming else 0.0,1-exp(-delta*6))
	var bob: float=sin(elapsed*(4.65 if swimming else 9 if moving else 2))*(.018 if moving else .005)*(1-intake_strength*.75)
	handheld.position=Vector3(.36-intake_strength*.035,-.30+bob+intake_strength*.015,-.92+recoil*.10-intake_strength*.025)
	handheld.position.y-=swim_lower*.08;handheld.position.x+=sin(elapsed*4.65)*.018*swim_lower;handheld.position.y+=sin(elapsed*4.65)*.012*swim_lower
	handheld.rotation=Vector3(recoil*.10+sin(elapsed*73)*intake_strength*.002,0,-.03+sin(elapsed*59)*intake_strength*.003)
	for part in parts:
		if part.name.begins_with("Anim_Fan"):part.rotate_z(delta*(2+intake_strength*65))
		elif part.name.begins_with("Anim_Piston") or part.name.begins_with("Anim_Collar"):
			part.position=part.get_meta("rest")+Vector3(0,0,recoil*.065+sin(elapsed*47)*intake_strength*.002)
	optics.update_intake(intake_point,handheld.to_global(Vector3(0,0,-.78)),app.camera,intake_strength if enabled else 0.0,delta)
	intake_tick-=delta
	if mining and intake_tick<=0:
		intake_tick=.10;effects.suction(intake_point,handheld,intake_resource,4)
	var scanning: bool=enabled and float(app.session.latest.get("scan",{}).get("progress",0))>0 and not app.session.latest.get("scan",{}).get("known",false)
	audio.set_suction(intake_strength if enabled and tool.get("kind")=="miner" else 0.0)
	audio.set_survey(float(app.session.latest.get("scan",{}).get("progress",0)) if scanning else 0.0)
	var size:=get_viewport().get_visible_rect().size
	cue.position=Vector2(size.x/2-180,size.y/2+45);cue.visible=enabled and cue_left>0
	if cue_left<=0:app.reticle.modulate=Color.WHITE
	var progress: float=float(app.session.latest.get("scan",{}).get("progress",0))
	scan_bar.position=Vector2(size.x/2-80,size.y/2+22);scan_bar.value=progress*100;scan_bar.visible=enabled and progress>0 and not app.session.latest.get("scan",{}).get("known",false)
	var scan: Dictionary=app.session.latest.get("scan",{})
	var current_id: String=str(scan.get("id",""))
	var known: bool=scan.get("known",false)
	scan_complete_left=maxf(0,scan_complete_left-delta)
	if enabled and known and not scan_was_known and current_id==scan_id and not current_id.is_empty():
		scan_complete_left=.5;audio.play("ui_discovery")
	if current_id!=scan_id:scan_complete_left=0
	scan_id=current_id;scan_was_known=known
	if enabled and (scanning or scan_complete_left>0):
		var scan_point:=Vector3.INF
		var subject: Node3D=null
		if app.surface_world.ecology.actors.has(current_id):
			subject=app.surface_world.ecology.actors[current_id]
			scan_point=subject.global_position+Vector3.UP*.7
		elif scan.has("point"):scan_point=FrontierCrewWorld.vector(scan.point)+Vector3.UP*.45
		elif scan.get("info",{}).has("point"):scan_point=FrontierCrewWorld.vector(scan.info.point)+Vector3.UP*.45
		if subject==null and app.surface_world.business_view.nodes.has(current_id):subject=app.surface_world.business_view.nodes[current_id]
		if scan_point.is_finite():optics.survey(scan_point,progress,scan_complete_left>0,1.25,subject)
		else:optics.stop_survey()
	else:optics.stop_survey()
	industry_tick-=delta
	if enabled and industry_tick<=0:
		industry_tick=.65;_industry_effects()
	audio_tick-=delta
	if audio_tick<=0:
		audio_tick=.2;_update_audio(active)

var daylight_mix_db:=0.0
func _update_audio(active: bool) -> void:
	audio.ambient.volume_db-=daylight_mix_db;daylight_mix_db=0.0
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
	state["external_ambience"]=app.surface_world.presence!=null
	audio.update_world(state,blocked())
	var atmosphere=app.surface_world.atmosphere
	var particles=app.surface_world.atmospheric_particles
	if particles!=null and app.surface_world.presence==null:
		var air: Dictionary=atmosphere.current
		var gain: float=float(air.atmosphere)*(.3+maxf(float(air.dust),float(air.ice)))*float(particles.exposure)
		audio.ambient.stream_paused=blocked() or not DisplayServer.window_is_focused()
		audio.ambient.volume_db=linear_to_db(maxf(.0001,gain*float(atmosphere.config().particles.wind_level)))
	for id in audio.emitters:
		if heights.has(id):audio.emitters[id].position.y=float(heights[id])+.8
		if app.surface_world.presence!=null:
			var speaker: AudioStreamPlayer3D=audio.emitters[id]
			var hidden:=false
			for ratio in [.25,.5,.75]:
				if app.surface_world.terrain.field.density((player+Vector3.UP*1.6).lerp(speaker.global_position,ratio))>0:hidden=true;break
			speaker.attenuation_filter_cutoff_hz=lerpf(speaker.attenuation_filter_cutoff_hz,900.0 if hidden else 18000.0,.4)
	daylight_mix_db=lerpf(float(app.surface_world.atmosphere.cycles.get("night_wind_db",0)),0.0,app.surface_world.atmosphere.daylight)
	audio.ambient.volume_db+=daylight_mix_db
	# Match the existing rover playback fixture gate without changing normal focus muting.
	if app.test_mode:audio.ambient.stream_paused=blocked()

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
			effects.suction(visuals[vein.id].global_position+Vector3.UP,actor.get_meta("intake",actor),vein.resource,4)
		elif robot.status=="충전 중":effects.burst(actor.global_position+Vector3.UP*.5,Color("82f5d2"),3)
	for building in site.get("buildings",{}).values():
		if not visuals.has(building.id) or not building.active:continue
		if building.type=="factory" and (not building.get("production",{}).is_empty() or building.get("working",false)):
			var actor: Node3D=visuals[building.id]
			if actor.global_position.distance_to(app.camera.global_position)<25:effects.burst(actor.global_position+Vector3.UP*1.5,Color("efb46f"),3)
		if building.type not in ["atmosphere","thermal","water","biolab","source_control"] or not building.get("working",false):continue
		var actor: Node3D=visuals[building.id]
		if actor.global_position.distance_to(app.camera.global_position)>25:continue
		var color: Color={"atmosphere":Color("c4e8e2"),"thermal":Color("ffc487"),"water":Color("71caf4"),"biolab":Color("8bdd82"),"source_control":Color("c4e8e2")}[building.type]
		effects.burst(actor.global_position+Vector3.UP*2,color,2)

func _replace_tool(model: String) -> void:
	work_left=0;intake_strength=0;recoil=0;recoil_velocity=0;optics.reset();effects.clear()
	handheld.get_parent().remove_child(handheld);handheld.queue_free()
	equipped_model=model;handheld=load("res://assets/models/"+model+".glb").instantiate()
	FrontierInkStyle.apply(handheld,cache);_tool_lighting();app.camera.add_child(handheld);handheld.scale=Vector3.ONE*(.72 if model in ["manual_tool","equipment/miner_mk2"] else .5)
	handheld.set_meta("intake_offset",Vector3(0,0,-.78))
	parts=handheld.find_children("Anim_*","Node3D",true,false)
	for part in parts:part.set_meta("rest",part.position)
	muzzle=OmniLight3D.new();muzzle.position=Vector3(0,0,-.78);muzzle.omni_range=4;muzzle.light_color=Color("ffc07c");muzzle.light_energy=0;handheld.add_child(muzzle)

func _tool_lighting() -> void:
	for mesh in handheld.find_children("*","GeometryInstance3D",true,false):mesh.layers=HANDHELD_LAYER
