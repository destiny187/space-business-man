class_name FrontierFieldInstruments
extends Control
const StatusMeter=preload("res://scripts/ui/status_meter.gd")
var meters: Dictionary={}
var app: FrontierCrewExpedition
var shield: ProgressBar
var shield_text: Label
var last_legendary:=-1
var last_shield:=-1
var last_break:=-1
var shield_flash:=0.0
var shield_crack:=0.0
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
	vitals_box=VBoxContainer.new();vitals_box.mouse_filter=Control.MOUSE_FILTER_IGNORE;vitals_box.add_theme_constant_override("separation",FrontierInterfaceStyle.SPACE);add_child(vitals_box)
	for kind in ["shield","health","stamina"]:
		var meter:=StatusMeter.new();vitals_box.add_child(meter)
		meter.configure(kind,{"shield":"실드","health":"체력","stamina":"스태미나"}[kind])
		meters[kind]=meter
	shield=meters.shield.bar;shield_text=meters.shield.value_label
	health=meters.health.bar;health_text=meters.health.value_label
	stamina=meters.stamina.bar;stamina_text=meters.stamina.value_label
	movement_hint=FrontierInterfaceStyle.label(vitals_box,"Shift  달리기",12,FrontierInterfaceStyle.MUTED)
	FrontierInterfaceStyle.hud_shadow(movement_hint)
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
			FrontierInterfaceStyle.hud_shadow(label)
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
	var shield_max:=FrontierSuitModules.shield_max(member)
	meters.shield.update_value(float(v.get("shield",0)),shield_max)
	if last_shield>=0 and int(v.get("shield_serial",0))>last_shield:
		shield_flash=.5
		if not app.feedback.blocked() and int(v.get("shield_break_serial",0))==last_break:app.feedback.audio.play("sfx_gun_hit_shield",Vector3.INF,.9,-2)
	if last_break>=0 and int(v.get("shield_break_serial",0))>last_break:
		if not app.feedback.blocked():
			shield_crack=.4;app.feedback.audio.play("sfx_gun_break",Vector3.INF,.82,0)
		notice.text="실드 소진  엄폐 후 재충전";notice_left=3
	if last_legendary>=0 and int(v.get("legendary_serial",0))>last_legendary:
		var effect: Dictionary=FrontierSuitModules.config().legendary.get(str(v.get("legendary_effect","")),{})
		if not effect.is_empty():notice.text="◆ "+str(effect.name);notice_left=2
		if not app.feedback.blocked():app.feedback.audio.play("ui_discovery")
	last_legendary=int(v.get("legendary_serial",0))
	last_shield=int(v.get("shield_serial",0));last_break=int(v.get("shield_break_serial",0));shield_flash=maxf(0,shield_flash-delta)
	shield_crack=maxf(0,shield_crack-delta)
	if app.feedback.blocked():shield_crack=0;shield_flash=0
	_update_shield_echoes(delta)
	for id in FrontierSuitModules.state(member).get("items",{}):
		if modules_ready and not module_seen.has(id):notice.text=FrontierSuitModules.title(member.modules.items[id])+" 획득  I 모듈";notice_left=5;app.feedback.audio.play("ui_discovery")
		module_seen[id]=true
	modules_ready=true
	var health_max:=FrontierCrewAugmentation.maximum_health(member)
	var low_health: bool=v.health<=health_max*.3
	meters.health.update_value(float(v.health),health_max,low_health)
	meters.stamina.update_value(float(v.stamina),float(FrontierCrewVitals.config().maximum_stamina),bool(v.exhausted))
	if last_damage>=0 and int(v.damage_serial)>last_damage:
		damage_flash=.65
		if not app.feedback.blocked() and shield_crack<=0:app.feedback.audio.play("sfx_gun_hit_organic",Vector3.INF,.78,-4)
	if last_rescue>=0 and int(v.rescue_serial)>last_rescue:notice.text="긴급 구조  장비와 화물 보존";notice_left=4
	last_damage=int(v.damage_serial);last_rescue=int(v.rescue_serial)
	damage_flash=maxf(0,damage_flash-delta);notice_left=maxf(0,notice_left-delta);notice.visible=notice_left>0
	var viewport_size:=get_viewport().get_visible_rect().size
	vitals_box.position=Vector2(28,viewport_size.y-86-vitals_box.size.y);radar.position=Vector2(viewport_size.x-208,26)
	pickups.position=Vector2(viewport_size.x-226,248);notice.position=Vector2((viewport_size.x-notice.size.x)/2,80)
	queue_redraw()
func _draw() -> void:
	if damage_flash<=0 and shield_flash<=0 and shield_crack<=0:return
	var view_size:=get_viewport().get_visible_rect().size
	if damage_flash>0:draw_rect(Rect2(Vector2(3,3),view_size-Vector2(6,6)),Color(1,.35,.2,damage_flash),false,6)
	if shield_flash>0:draw_rect(Rect2(Vector2(12,12),view_size-Vector2(24,24)),Color(.3,.7,1,shield_flash),false,4)
	if shield_crack>0:
		var color:=Color(.57,.85,1,minf(.8,shield_crack/.15))
		var drift: float=(1-shield_crack/.4)*12
		for side in [-1,1]:
			var at:=Vector2(22+drift if side==1 else view_size.x-22-drift,view_size.y*.5)
			for vertical in [-1,1]:
				var points:=PackedVector2Array([at+Vector2(0,vertical*50),at+Vector2(side*15,vertical*67),at+Vector2(side*8,vertical*81),at+Vector2(side*29,vertical*111)])
				draw_polyline(points,color,2,true)

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
