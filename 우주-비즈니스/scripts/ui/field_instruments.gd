class_name FrontierFieldInstruments
extends Control
var app: FrontierCrewExpedition
var shield: ProgressBar
var shield_text: Label
var last_legendary:=-1
var last_shield:=-1
var last_break:=-1
var shield_flash:=0.0
var module_seen: Dictionary={}
var modules_ready:=false
var shield_echoes: Dictionary={}
var health: ProgressBar
var stamina: ProgressBar
var health_text: Label
var stamina_text: Label
var movement_hint: Label
var vitals_box: VBoxContainer
var radar: FrontierSurfaceRadar
var pickups: VBoxContainer
var gains: Dictionary={}
var seen: Dictionary={}
var last_damage:=-1
var last_rescue:=-1
var damage_flash:=0.0
var notice: Label
var notice_left:=0.0
func configure(owner_app: FrontierCrewExpedition) -> void:
	app=owner_app;mouse_filter=Control.MOUSE_FILTER_IGNORE;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vitals_box=VBoxContainer.new();vitals_box.mouse_filter=Control.MOUSE_FILTER_IGNORE;vitals_box.add_theme_constant_override("separation",5);add_child(vitals_box)
	for kind in ["shield","health","stamina"]:
		var row:=HBoxContainer.new();row.mouse_filter=Control.MOUSE_FILTER_IGNORE;vitals_box.add_child(row)
		var symbol:=TextureRect.new();symbol.texture=load("res://assets/ui/resources/shielding_material.svg") if kind=="shield" else load("res://assets/ui/interface/"+kind+".svg");symbol.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;symbol.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;symbol.custom_minimum_size=Vector2(18,18);symbol.mouse_filter=Control.MOUSE_FILTER_IGNORE;row.add_child(symbol)
		var bar:=ProgressBar.new();bar.show_percentage=false;bar.custom_minimum_size=Vector2(136,8);bar.size_flags_vertical=Control.SIZE_SHRINK_CENTER;bar.mouse_filter=Control.MOUSE_FILTER_IGNORE;row.add_child(bar)
		var label:=FrontierInterfaceStyle.label(row,"",11)
		if kind=="shield":shield=bar;shield_text=label;bar.modulate=Color("77bdf5")
		elif kind=="health":health=bar;health_text=label
		else:stamina=bar;stamina_text=label
	movement_hint=FrontierInterfaceStyle.label(vitals_box,"Shift  달리기",10,FrontierInterfaceStyle.MUTED)
	radar=FrontierSurfaceRadar.new();radar.configure(app);add_child(radar)
	pickups=VBoxContainer.new();pickups.custom_minimum_size.x=216;pickups.size.x=216;pickups.mouse_filter=Control.MOUSE_FILTER_IGNORE;pickups.add_theme_constant_override("separation",6);add_child(pickups)
	notice=FrontierInterfaceStyle.label(self,"",14,FrontierInterfaceStyle.WARNING)
	notice.add_theme_stylebox_override("normal",FrontierInterfaceStyle.box(FrontierInterfaceStyle.INK,FrontierInterfaceStyle.LINE,8))
	app.session.response_received.connect(_response)
func _response(sequence: int,result: Dictionary) -> void:
	if not result.get("ok",false) or app.surface_world==null:return
	var key: String=app.session.session_id+":"+str(sequence)
	if seen.has(key):return
	seen[key]=true
	if seen.size()>256:seen.erase(seen.keys()[0])
	for resource in result.get("gains",{}):
		var amount: int=int(result.gains[resource])
		if amount<=0:continue
		if not gains.has(resource):
			var row:=HBoxContainer.new();row.alignment=BoxContainer.ALIGNMENT_CENTER;row.mouse_filter=Control.MOUSE_FILTER_IGNORE;pickups.add_child(row)
			var icon:=FrontierResourceIcons.view(resource,28);icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;row.add_child(icon)
			var label:=FrontierInterfaceStyle.label(row,"",14);label.clip_text=true;label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
			label.add_theme_color_override("font_shadow_color",Color("081218e0"));label.add_theme_constant_override("shadow_offset_x",1);label.add_theme_constant_override("shadow_offset_y",1)
			gains[resource]={"row":row,"label":label,"amount":0,"left":0.0}
		gains[resource].amount+=amount;gains[resource].left=3.5
		gains[resource].label.text="%s  +%d"%[FrontierResourceIcons.names().get(FrontierResourceIcons.canonical(resource),resource),gains[resource].amount]
		var caption: Label=gains[resource].label
		caption.custom_minimum_size.x=minf(160,caption.get_theme_font("font").get_string_size(caption.text,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x+2)
func _process(delta: float) -> void:
	var displayed:=0
	for resource in gains.keys():
		gains[resource].row.visible=displayed<4
		displayed+=1
		if displayed>4:continue
		gains[resource].left-=delta
		if gains[resource].left<=0:gains[resource].row.queue_free();gains.erase(resource)
	if app.session.latest.is_empty():return
	var motion: Dictionary=app.visuals.get(app.session.latest.self_id,{}).get("motion",{})
	movement_hint.text="Space 상승  시선 방향으로 수영" if motion.get("state","") in ["swim","tread"] else "Shift  달리기"
	var member: Dictionary=app.session.latest.crew.members[app.session.latest.self_id]
	var v: Dictionary=member.get("vitals",FrontierCrewVitals.create())
	shield.max_value=maxf(1,FrontierSuitModules.shield_max(member));shield.value=float(v.get("shield",0))
	shield_text.text="실드 %d / %d"%[ceili(shield.value),ceili(FrontierSuitModules.shield_max(member))]
	if float(v.get("shield_wait",0))>0:shield_text.text+=" · %.1fs"%float(v.shield_wait)
	if last_shield>=0 and int(v.get("shield_serial",0))>last_shield:
		shield_flash=.5
		if not app.feedback.blocked():app.feedback.audio.play("sfx_build_place")
	if last_break>=0 and int(v.get("shield_break_serial",0))>last_break:
		if not app.feedback.blocked():app.feedback.audio.play("sfx_build_invalid")
		notice.text="실드 소진 · 엄폐 후 재충전";notice_left=3
	if last_legendary>=0 and int(v.get("legendary_serial",0))>last_legendary:
		var effect: Dictionary=FrontierSuitModules.config().legendary.get(str(v.get("legendary_effect","")),{})
		if not effect.is_empty():notice.text="◆ "+str(effect.name);notice_left=2
		if not app.feedback.blocked():app.feedback.audio.play("ui_discovery")
	last_legendary=int(v.get("legendary_serial",0))
	if FrontierSuitModules.has_effect(member,"break_dash") and float(v.get("shield_haste",0))>0:movement_hint.text="비상 가속 %.1fs"%float(v.shield_haste)
	elif FrontierSuitModules.has_effect(member,"field_regeneration") and float(v.get("combat_wait",0))<=0 and float(v.hurt)<=0 and v.health<FrontierCrewAugmentation.maximum_health(member):movement_hint.text="자가복원 중"
	last_shield=int(v.get("shield_serial",0));last_break=int(v.get("shield_break_serial",0));shield_flash=maxf(0,shield_flash-delta)
	_update_shield_echoes(delta)
	for id in FrontierSuitModules.state(member).get("items",{}):
		if modules_ready and not module_seen.has(id):notice.text=FrontierSuitModules.title(member.modules.items[id])+" 획득 · I 모듈";notice_left=5;app.feedback.audio.play("ui_discovery")
		module_seen[id]=true
	modules_ready=true
	health.max_value=FrontierCrewAugmentation.maximum_health(member);health.value=v.health
	stamina.max_value=FrontierCrewVitals.config().maximum_stamina;stamina.value=v.stamina
	health_text.text="%d / %d"%[ceili(v.health),ceili(health.max_value)];stamina_text.text="회복 중" if v.exhausted else "%d"%ceili(v.stamina)
	health.modulate=FrontierInterfaceStyle.WARNING if v.health<=health.max_value*.3 else Color.WHITE
	stamina.modulate=FrontierInterfaceStyle.WARNING if v.exhausted else Color.WHITE
	if last_damage>=0 and int(v.damage_serial)>last_damage:
		damage_flash=.65;app.feedback.audio.play("sfx_build_invalid")
	if last_rescue>=0 and int(v.rescue_serial)>last_rescue:notice.text="긴급 구조  장비와 화물 보존";notice_left=4
	last_damage=int(v.damage_serial);last_rescue=int(v.rescue_serial)
	damage_flash=maxf(0,damage_flash-delta);notice_left=maxf(0,notice_left-delta);notice.visible=notice_left>0
	var viewport_size:=get_viewport().get_visible_rect().size
	vitals_box.position=Vector2(28,viewport_size.y-176);radar.position=Vector2(viewport_size.x-208,26)
	pickups.position=Vector2(viewport_size.x-226,248);notice.position=Vector2(viewport_size.x/2-135,80)
	queue_redraw()
func _draw() -> void:
	if damage_flash<=0 and shield_flash<=0:return
	var view_size:=get_viewport().get_visible_rect().size
	if damage_flash>0:draw_rect(Rect2(Vector2(3,3),view_size-Vector2(6,6)),Color(1,.35,.2,damage_flash),false,6)
	if shield_flash>0:draw_rect(Rect2(Vector2(12,12),view_size-Vector2(24,24)),Color(.3,.7,1,shield_flash),false,4)

func _update_shield_echoes(delta: float) -> void:
	for id in app.actors:
		if not app.session.latest.crew.members.has(id):continue
		var serial:=int(app.session.latest.crew.members[id].get("vitals",{}).get("shield_serial",0))
		if not shield_echoes.has(id):shield_echoes[id]={"serial":serial,"left":0.0}
		var echo: Dictionary=shield_echoes[id]
		if serial>int(echo.serial):echo.left=.4
		echo.serial=serial;echo.left=maxf(0,echo.left-delta)
		if not echo.has("mesh") or not is_instance_valid(echo.mesh):
			var mesh:=MeshInstance3D.new();var shape:=SphereMesh.new();shape.radius=.6;shape.height=1.9;mesh.mesh=shape
			var material:=StandardMaterial3D.new();material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.albedo_color=Color(.2,.65,1,.15);mesh.material_override=material
			app.actors[id].add_child(mesh);mesh.position=Vector3.UP;echo.mesh=mesh
		echo.mesh.visible=echo.left>0 and id!=app.session.latest.self_id and not app.feedback.blocked()
		echo.mesh.material_override.albedo_color=Color(.2,.65,1,float(echo.left)*.4)
	for id in shield_echoes.keys():
		if not app.actors.has(id):
			if shield_echoes[id].has("mesh") and is_instance_valid(shield_echoes[id].mesh):shield_echoes[id].mesh.queue_free()
			shield_echoes.erase(id)
