class_name FrontierFirearmView
extends Node
## Local trigger/recoil and authoritative hit feedback. Inventory ownership stays with the host.
var app: FrontierCrewExpedition
var ads:=0.0
var crouched:=false
var test_ads:=false
var last_stance:=false
var stance_retry:=0.0
var reload_left:=0.0
var reload_duration:=1.0
var next_shot:=0.0
var hit_left:=0.0
var hit_kind: String=""
var seen: Dictionary={}
var pending: Dictionary={}
var accepted: Dictionary={}
var hud: Control
var ammo_label: Label
var reload_bar: ProgressBar
var observed_item: String=""
var was_enabled:=false
func configure(owner_app: FrontierCrewExpedition) -> void:
	app=owner_app
	var layer:=CanvasLayer.new();add_child(layer)
	hud=Control.new();hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);hud.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(hud)
	hud.draw.connect(_draw)
	ammo_label=Label.new();ammo_label.add_theme_font_size_override("font_size",18);ammo_label.mouse_filter=Control.MOUSE_FILTER_IGNORE;hud.add_child(ammo_label)
	reload_bar=ProgressBar.new();reload_bar.show_percentage=false;reload_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE;reload_bar.custom_minimum_size=Vector2(110,4);hud.add_child(reload_bar)
	app.session.request_started.connect(func(sequence: int,kind: String,args: Dictionary):
		if kind in ["surface_fire","surface_reload","surface_stance"]:pending[sequence]={"kind":kind,"item_id":args.get("item_id","")})
	app.session.response_received.connect(_response)
	app.session.snapshot_received.connect(_snapshot)
func enabled() -> bool:
	return app.session.active and not app.session.latest.is_empty() and app.session.latest.crew.members[app.session.latest.self_id].area=="surface" and not app.session.latest.crew.members[app.session.latest.self_id].aboard and app.surface_world!=null and not app.feedback.blocked() and app.placement_kind.is_empty() and not app.outside and app.rovers.seat().is_empty() and (app.test_mode or app.get_window().has_focus())
func tool() -> Dictionary:
	return FrontierEquipment.active(app.session.latest.crew.members[app.session.latest.self_id]) if not app.session.latest.is_empty() else {}
func shoot() -> void:
	if not enabled() or next_shot>0:return
	var gun:=tool()
	if not gun.has("firearm") or reload_left>0:return
	if int(accepted.get("ammo",gun.magazine))<=0:reload();return
	next_shot=maxf(.06,float(gun.interval))
	var aim: Vector3=-app.camera.global_basis.z
	app.session.send_request("surface_fire",{"item_id":gun.item_id,"aim":[aim.x,aim.y,aim.z],"ads":ads>.5})
	# This predicts only the attempt; confirmed impacts arrive in _response.
	app.feedback.recoil=.35+float(gun.recoil)*8
	app.feedback.recoil_velocity=8+float(gun.recoil)*90
	app.pitch=clampf(app.pitch+float(gun.recoil)*(1.0-.45*ads)*(.55 if crouched and gun.effect=="braced" else 1),-1.45,1.45)
	app.feedback.audio.play(str(gun.sound))
func reload() -> void:
	if not enabled():return
	var gun:=tool()
	if gun.has("firearm"):app.session.send_request("surface_reload",{"item_id":gun.item_id})
func _response(sequence: int,result: Dictionary) -> void:
	if not pending.has(sequence):return
	var request: Dictionary=pending[sequence];pending.erase(sequence)
	if request.kind=="surface_stance":
		if result.has("crouched"):crouched=result.crouched;last_stance=crouched
		if not result.get("ok",false):
			stance_retry=.25
			last_stance=bool(result.get("crouched",app.session.latest.crew.members[app.session.latest.self_id].loadout.get("crouched",false)))
		return
	if not result.get("ok",false):
		if result.has("weapon"):accepted=result.weapon.duplicate(true)
		if result.has("error"):app.feedback.reject(result.error)
		return
	if request.item_id!=tool().get("item_id",""):return
	seen[app.session.latest.self_id]=sequence
	if result.has("weapon"):accepted=result.weapon.duplicate(true)
	if result.get("reload",false):
		reload_left=float(result.duration);reload_duration=reload_left
		if enabled():
			var sound:=app.feedback.audio.stream("sfx_gun_reload")
			if sound!=null:app.feedback.audio.play("sfx_gun_reload",Vector3.INF,sound.get_length()/maxf(.1,reload_duration))
	elif result.has("rays"):
		present(result,true)
func _snapshot(value: Dictionary) -> void:
	for id in value.get("crew",{}).get("members",{}):
		var member: Dictionary=value.crew.members[id]
		var event: Dictionary=member.get("weapon_event",{})
		var serial:=int(event.get("serial",0))
		if not seen.has(id):seen[id]=serial;continue
		if serial<=int(seen[id]):continue
		seen[id]=serial
		if id!=value.self_id and event.has("rays") and member.get("place_key","")==value.crew.members[value.self_id].get("place_key","!"):present(event,false)
func present(event: Dictionary,local: bool) -> void:
	if not enabled():return
	var origin:=FrontierCrewWorld.vector(event.origin)
	if not local:app.feedback.audio.play(str(FrontierFirearms.config().families[event.family].sound),origin)
	if local:
		var sockets:=app.feedback.handheld.find_children("Socket_Muzzle","Node3D",true,false)
		origin=sockets[0].global_position if not sockets.is_empty() else app.feedback.handheld.to_global(Vector3(0,0,-.78))
	for point in event.rays:app.feedback.effects.pulse(origin,FrontierCrewWorld.vector(point),false)
	var hit: Dictionary=event.get("hits",{})
	if float(hit.get("damage",0))+float(hit.get("shield",0))>0:
		var point:=FrontierCrewWorld.vector(event.rays[0])
		app.feedback.effects.burst(point,Color("b9dce9") if hit.shield>0 else Color("ffb36c"),14 if hit.broken else 5)
		if local:
			hit_left=.26;hit_kind="kill" if hit.killed else "break" if hit.broken else "weak" if hit.weak else "shield" if hit.shield>0 else "hit"
			app.feedback.audio.play("sfx_shield_break" if hit.broken else ("sfx_wildlife_hurt" if hit.get("organic",false) else "sfx_gun_impact"))
	if event.effect=="splash":app.feedback.effects.burst(FrontierCrewWorld.vector(event.rays[0]),Color("b995ff"),20)
func _process(delta: float) -> void:
	if app==null:return
	next_shot=maxf(0,next_shot-delta);hit_left=maxf(0,hit_left-delta)
	var active:=enabled();var gun:=tool()
	if was_enabled and not active:app.feedback.audio.stop_firearm_cues()
	was_enabled=active
	var firearm: bool=active and gun.has("firearm")
	ads=move_toward(ads,1.0 if firearm and (test_ads if app.test_mode else Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)) else 0.0,delta*8)
	stance_retry=maxf(0,stance_retry-delta)
	if active and stance_retry<=0 and not app.test_mode:crouched=Input.is_physical_key_pressed(KEY_CTRL)
	if active and stance_retry<=0 and crouched!=last_stance:
		last_stance=crouched
		app.session.send_request("surface_stance",{"crouched":crouched})
	if not active:
		ads=0
		if not app.session.latest.is_empty() and (app.session.latest.crew.members[app.session.latest.self_id].area!="surface" or app.session.latest.crew.members[app.session.latest.self_id].aboard):crouched=false;last_stance=false
	if gun.get("item_id","")!=observed_item:
		observed_item=gun.get("item_id","");accepted={};reload_left=0;next_shot=.12
		if gun.has("firearm"):
			var states: Dictionary=app.session.latest.crew.members[app.session.latest.self_id].loadout.get("weapon_states",{})
			accepted=states.get(observed_item,{}).duplicate(true);reload_left=float(accepted.get("reload_left",0));reload_duration=maxf(.1,reload_left)
	if reload_left>0:
		reload_left=maxf(0,reload_left-delta)
		if reload_left==0:accepted.ammo=int(gun.get("magazine",0))
	if app.surface_world!=null:app.camera.fov=lerpf(76,38 if gun.get("effect")=="precision" else 57,ads)
	if firearm and app.feedback.handheld!=null:
		var held: Node3D=app.feedback.handheld
		held.position=held.position.lerp(Vector3(0,-.15,-.72),ads)
		held.visible=not (ads>.92 and gun.get("effect") in ["precision","weak_chain"])
		var phase:=1.0-reload_left/maxf(.1,reload_duration)
		var motion:=sin(phase*PI) if reload_left>0 else 0.0
		held.rotation.z-=motion*.42;held.position.y-=motion*.13
		for part in app.feedback.parts:
			if part.name.begins_with("Anim_Magazine"):part.position=part.get_meta("rest")+Vector3(0,-motion*.24,motion*.12)
			elif part.name.begins_with("Anim_Bolt") or part.name.begins_with("Anim_Pump"):part.position=part.get_meta("rest")+Vector3(0,0,app.feedback.recoil*.08)
	hud.visible=firearm
	if firearm:
		var size:=hud.get_viewport_rect().size;ammo_label.position=Vector2(size.x*.5+45,size.y-126)
		ammo_label.text="%02d / %02d"%[int(accepted.get("ammo",gun.magazine)),int(gun.magazine)]
		reload_bar.position=ammo_label.position+Vector2(0,29);reload_bar.size=Vector2(110,4);reload_bar.visible=reload_left>0;reload_bar.value=(1-reload_left/maxf(.1,reload_duration))*100
	if active:app.reticle.visible=not firearm or ads<.9
	hud.queue_redraw()
func _draw() -> void:
	var center:=hud.get_viewport_rect().size*.5
	if ads>.92 and tool().get("effect") in ["precision","weak_chain"]:
		var radius:=hud.get_viewport_rect().size.y*.38;var edge:=hud.get_viewport_rect().size.length()
		for i in 64:
			var a:=Vector2.from_angle(i*TAU/64);var b:=Vector2.from_angle((i+1)*TAU/64)
			hud.draw_colored_polygon(PackedVector2Array([center+a*radius,center+b*radius,center+b*edge,center+a*edge]),Color(.015,.024,.031,.94))
		for axis in [Vector2.RIGHT,Vector2.UP]:
			hud.draw_line(center+axis*8,center+axis*radius,Color("c4e0d6"),1,true);hud.draw_line(center-axis*8,center-axis*radius,Color("c4e0d6"),1,true)
	if ads>.8:hud.draw_circle(center,1.7,Color("e5f7ef"))
	if hit_left<=0:return
	var color:=Color("ffd19b") if hit_kind in ["weak","kill"] else Color("e5f7ef")
	for angle in [PI*.25,PI*.75,PI*1.25,PI*1.75]:
		var direction:=Vector2(cos(angle),sin(angle));hud.draw_line(center+direction*6,center+direction*(14 if hit_kind in ["break","kill"] else 10),color,2,true)
	if hit_kind=="break":hud.draw_arc(center,20,PI*.12,PI*.8,12,color,2,true);hud.draw_arc(center,20,PI*1.12,PI*1.8,12,color,2,true)
