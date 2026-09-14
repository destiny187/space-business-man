class_name FrontierFieldHud
extends Control
var scan_card: FrontierSurveyCard
var environment: FrontierEnvironmentHud
var instruments: FrontierFieldInstruments
var app: FrontierCrewExpedition
var place: Label
var day_dial: DayDial
var location: Label
var return_label: Label
var ship_direction: TextureRect
var context: PanelContainer
var target_name: Label
var target_action: Label
var target_icon: TextureRect
var target_bar: ProgressBar
var target_health: FrontierTargetHealth
var equipment_name: Label
var cooldown: ProgressBar
var navigation: HBoxContainer
var saved: Label
var toast: PanelContainer
var toast_label: Label
var toast_left:=0.0
var save_left:=0.0
var jet_meter: ProgressBar
var jet_hint: Label
func configure(owner_app: FrontierCrewExpedition) -> void:
	app=owner_app;theme=FrontierInterfaceStyle.theme();mouse_filter=Control.MOUSE_FILTER_IGNORE;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	instruments=FrontierFieldInstruments.new();add_child(instruments);instruments.configure(app)
	scan_card=FrontierSurveyCard.new();scan_card.configure(app);add_child(scan_card)
	var heading:=VBoxContainer.new();heading.position=Vector2(32,28);heading.add_theme_constant_override("separation",4);heading.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(heading)
	place=FrontierInterfaceStyle.label(heading,"",24)
	environment=FrontierEnvironmentHud.new();heading.add_child(environment);environment.configure(app)
	var local_row:=HBoxContainer.new();heading.add_child(local_row)
	day_dial=DayDial.new();local_row.add_child(day_dial)
	location=FrontierInterfaceStyle.label(local_row,"",12,Color("d0d6ce"))
	var compass:=HBoxContainer.new();compass.name="Compass";compass.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(compass);ship_direction=FrontierInterfaceStyle.interface_icon("ship",22);compass.add_child(ship_direction);return_label=FrontierInterfaceStyle.label(compass,"",13)
	saved=FrontierInterfaceStyle.label(self,"✓",16,FrontierInterfaceStyle.ACCENT)
	context=PanelContainer.new();context.mouse_filter=Control.MOUSE_FILTER_IGNORE;context.add_theme_stylebox_override("panel",FrontierInterfaceStyle.box(Color("10191fdb"),Color("31434d00"),10));add_child(context)
	var row:=HBoxContainer.new();row.mouse_filter=Control.MOUSE_FILTER_IGNORE;context.add_child(row)
	target_icon=TextureRect.new();target_icon.custom_minimum_size=Vector2(36,36);target_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;target_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;target_icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;row.add_child(target_icon)
	var labels:=VBoxContainer.new();labels.add_theme_constant_override("separation",4);labels.mouse_filter=Control.MOUSE_FILTER_IGNORE;row.add_child(labels)
	target_name=FrontierInterfaceStyle.label(labels,"",15);target_action=FrontierInterfaceStyle.label(labels,"",12,FrontierInterfaceStyle.ACCENT)
	target_bar=ProgressBar.new();target_bar.show_percentage=false;target_bar.custom_minimum_size=Vector2(190,3);labels.add_child(target_bar)
	target_health=FrontierTargetHealth.new();add_child(target_health)
	var weapon:=VBoxContainer.new();weapon.name="Weapon";weapon.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(weapon)
	equipment_name=FrontierInterfaceStyle.label(weapon,"",14);cooldown=ProgressBar.new();cooldown.show_percentage=false;cooldown.custom_minimum_size=Vector2(170,3);weapon.add_child(cooldown)
	var jet_row:=VBoxContainer.new();jet_row.name="Jetpack";add_child(jet_row)
	jet_hint=FrontierInterfaceStyle.label(jet_row,"Space · 공중에서 다시 길게",12)
	jet_meter=ProgressBar.new();jet_meter.show_percentage=false;jet_meter.custom_minimum_size=Vector2(170,6);jet_row.add_child(jet_meter)
	navigation=HBoxContainer.new();navigation.add_theme_constant_override("separation",FrontierInterfaceStyle.SPACE);add_child(navigation)
	var rows: Array=[["inventory","I","아이템  장비",app.toggle_inventory],["build","B","건설",app.toggle_business],["scan","J","연구",app.toggle_research],["ship","Tab","지도",app.toggle_navigation]]
	for entry in rows:
		var button:=Button.new();button.custom_minimum_size=Vector2(46,46);button.tooltip_text=entry[2]+" ["+entry[1]+"]";button.pressed.connect(entry[3]);navigation.add_child(button)
		var icon:=FrontierInterfaceStyle.interface_icon(entry[0],22);icon.position=Vector2(12,5);icon.size=Vector2(22,22);button.add_child(icon)
		var key:=FrontierInterfaceStyle.label(button,entry[1],10,FrontierInterfaceStyle.MUTED);key.position=Vector2(0,29);key.size.x=46;key.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	app.session.response_received.connect(func(_seq: int,result: Dictionary):
		if result.has("firearm_action"):return
		if result.get("ok",false):save_left=.7;toast_left=0)
	toast=PanelContainer.new();toast.theme=theme;toast.mouse_filter=Control.MOUSE_FILTER_IGNORE;toast.add_theme_stylebox_override("panel",FrontierInterfaceStyle.box(FrontierInterfaceStyle.INK,FrontierInterfaceStyle.WARNING,12));get_parent().add_child(toast)
	toast_label=FrontierInterfaceStyle.label(toast,"",13,FrontierInterfaceStyle.WARNING);toast_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;toast_label.custom_minimum_size.x=360;toast.hide()
	app.session.response_received.connect(func(_seq: int,result: Dictionary):
		if result.has("firearm_action"):return
		if result.get("code")=="mining_cooldown":return
		if not result.get("ok",false):toast_label.text=str(result.get("error","실행할 수 없습니다."));toast_left=4)
	for label in [place,location,return_label,equipment_name]:
		FrontierInterfaceStyle.hud_shadow(label)
	get_viewport().size_changed.connect(_layout);_layout()
func _layout() -> void:
	var size:=get_viewport().get_visible_rect().size
	get_node("Compass").position=Vector2(size.x/2-45,26);saved.position=Vector2(size.x-230,28)
	navigation.position=Vector2(28,size.y-68);get_node("Weapon").position=Vector2(size.x-200,size.y-63)
func _process(delta: float) -> void:
	toast_left=maxf(0,toast_left-delta)
	toast.visible=app.surface_world!=null and toast_left>0
	toast.position=Vector2((get_viewport().get_visible_rect().size.x-toast.size.x)/2,32)
	var on_surface: bool=app.session.active and app.surface_world!=null
	app.status.get_parent().visible=not app.session.active
	app.navigation_toggle.get_parent().visible=false
	visible=on_surface and app.feedback!=null and not app.feedback.blocked()
	if not visible:return
	for i in navigation.get_child_count():
		var button:=navigation.get_child(i);var key: String=FrontierPlayInput.text(["inventory","build","journal","map"][i])
		button.get_child(1).text=key;button.tooltip_text=["아이템", "건설", "연구", "지도"][i]+" ["+key+"]"
	save_left=maxf(0,save_left-delta);saved.visible=save_left>0
	var jet_id: String=app.session.latest.self_id
	var equipped:=FrontierEquipment.jetpack(app.session.latest.crew.members[jet_id])
	get_node("Jetpack").visible=equipped;get_node("Jetpack").position=Vector2(get_viewport().get_visible_rect().size.x-240,get_viewport().get_visible_rect().size.y-150)
	if equipped:
		var motion: Dictionary=app.session.authority.motions.get(jet_id,{}) if app.session.hosting else app.predicted_motion
		jet_meter.value=100.*float(motion.get("jet_charge",FrontierCrewLocomotion.config().jetpack.capacity_seconds))/float(FrontierCrewLocomotion.config().jetpack.capacity_seconds)
		jet_hint.text="제트팩 충전 중" if motion.get("grounded",false) and jet_meter.value<99 else ("추진 중 · Space 놓으면 하강" if motion.get("jet_active",false) else "Space · 공중에서 다시 길게")
	var position: Vector3=app.actors[app.session.latest.self_id].position
	place.text=app.surface_world.body.name
	var depth:=maxf(0,app.surface_world.terrain.field.height(position.x,position.z)-position.y)
	location.text="지표 탐사" if depth<5 else "지하  %.0f m"%depth
	var air=app.surface_world.atmosphere
	day_dial.visible=not air.cycles.is_empty()
	if day_dial.visible:
		day_dial.height=float(air.sky_state.sun_height);day_dial.queue_redraw()
		location.text+="  "+air.cycle_label()
		var a: Dictionary=app.surface_world.body.astro
		location.tooltip_text="동주기 자전  같은 지역은 낮/밤 면 유지" if a.spin_state=="synchronous" else "현지 하루 약 %.1f시간  플레이 약 %.1f분"%[float(a.mean_solar_seconds)/3600.0,float(a.mean_solar_seconds)/float(a.time_scale)/60.0]
	var ship:=FrontierCrewWorld.vector(FrontierCrewSurface.config().ship_position)
	return_label.text="착륙선 %.0f m"%position.distance_to(ship)
	if app.planet_map!=null and app.planet_map.waypoint.is_finite():
		var target:=app.planet_map.waypoint
		return_label.text="지도 표식 %.0f m   착륙선 %.0f m"%[Vector2(position.x,position.z).distance_to(target),position.distance_to(ship)]
	var tool:=FrontierEquipment.active(app.session.latest.crew.members[app.session.latest.self_id])
	equipment_name.text=tool.get("name","I  장비 준비")
	equipment_name.get_parent().visible=app.rovers==null or app.rovers.seat().is_empty()
	cooldown.value=100*(1-clampf(app.dig_timer/maxf(.1,float(tool.get("interval",1))),0,1))
	context.hide();target_bar.hide();target_health.hide();target_icon.show();target_name.show();target_action.show()
	var target:=app.surface_world.business_view.target(app.camera,app.actors[app.session.latest.self_id])
	if target.get("kind")=="vein":
		var vein:=FrontierExpeditionBusiness.find_vein(app.surface_world.body,target.id)
		var known: bool=app.session.latest.crew.get("survey",{}).has(FrontierSurfaceSurvey.key(app.surface_world.body.id,{"kind":"mineral","resource":vein.resource}))
		target_icon.visible=known
		target_icon.texture=FrontierResourceIcons.texture(vein.resource) if known else null
		target_name.text=FrontierCatalog.entry("resources",vein.resource).name+" 광맥" if known else "미확인 광맥"
		var site: Dictionary=app.session.surface.get("business",{}).get("sites",{}).get(app.surface_world.body.id,{})
		var remaining:=int(site.get("remaining",{}).get(vein.id,vein.capacity))
		target_action.text="잔량 %d / 총 %d개"%[remaining,int(vein.capacity)]
		target_action.modulate=Color.WHITE
		target_bar.show();target_bar.max_value=vein.capacity;target_bar.value=remaining
		context.show()
	elif not app.surface_target.is_empty():
		var form:=FrontierEcologyCatalog.form(app.surface_target.form_id)
		# Identity, portraits and specimen uses belong to the short completed scan,
		# even when this species is already recorded in the journal.
		target_name.text="";target_name.hide();target_icon.texture=null;target_icon.hide()
		target_action.text="E  스캔";target_action.modulate=Color.WHITE;context.show()
		if form.category=="animal":
			context.hide();target_name.text="";target_action.text=""
			var maximum:=FrontierWildlifeCombat.health(app.surface_target)
			var remaining: float=app.session.latest.crew.get("combat",{}).get(app.surface_world.body.id+"/"+str(app.surface_target.id),maximum)
			target_health.present(remaining,maximum)
	elif not target.is_empty():
		var site: Dictionary=app.session.surface.get("business",{}).get("sites",{}).get(app.surface_world.body.id,{})
		var row: Dictionary=site.get("buildings",{}).get(target.id,{})
		target_name.text="현장 창고" if target.get("kind")=="base" else ("M-01 로봇" if target.get("kind")=="robot" else FrontierCatalog.entry("buildings",row.get("type","")).get("name","회수 화물"))
		target_icon.texture=load("res://assets/ui/interface/build.svg");target_action.text="F  로봇 제작소" if row.get("type","")=="factory" else "F  열기";target_action.modulate=Color.WHITE;context.show()
		if not row.is_empty():
			target_action.text+="\n"+("▶ " if row.get("working",false) else "Ⅱ ")+str(row.get("status",""))
			target_action.modulate=FrontierInterfaceStyle.ACCENT if row.get("working",false) else FrontierInterfaceStyle.WARNING
	var size:=get_viewport().get_visible_rect().size
	context.position=Vector2(size.x/2+24,size.y/2+36)

	if not app.placement_kind.is_empty():
		var def:=app.placement_definition()
		target_icon.show();target_name.show();target_action.show()
		target_icon.texture=load("res://assets/ui/interface/ship.svg") if app.placement_kind=="shuttle" else FrontierInterfaceStyle.icon(def.model)
		target_name.text=("✓ 배치 가능  " if app.placement_valid else "× 배치 불가  ")+str(def.name)
		target_action.text=("클릭 호출  휠 회전" if app.placement_kind=="shuttle" else "클릭 건설  휠 회전  "+FrontierCatalog.cost_text(def.cost)) if app.placement_valid else app.placement_reason
		target_action.modulate=FrontierInterfaceStyle.ACCENT if app.placement_valid else FrontierInterfaceStyle.WARNING
		target_action.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;target_action.custom_minimum_size.x=260
		context.show();target_bar.hide();target_health.hide()
	else:target_action.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;target_action.custom_minimum_size.x=0 if not app.surface_target.is_empty() else 260
	target_action.text=FrontierPlayInput.hint(target_action.text,"ground")
	jet_hint.text=FrontierPlayInput.hint(jet_hint.text,"ground")
	context.size=context.get_combined_minimum_size()
	context.position.x=minf(context.position.x,size.x-context.size.x-24)
	if scan_card.visible:context.hide();target_health.hide()

class DayDial extends Control:
	var height:=1.0
	func _init() -> void:custom_minimum_size=Vector2(28,19);mouse_filter=Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_line(Vector2(2,10),Vector2(26,10),Color("718794"),1.0,true)
		draw_arc(Vector2(14,10),9,PI,TAU,20,Color("536b7b"),1.0,true)
		var point:=Vector2(14,10-clampf(height,-1,1)*7)
		draw_circle(point,3.2,Color("ffc77f") if height>-.1 else Color("a2c4e8"),true,-1,true)
