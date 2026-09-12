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
var gun_effects: FrontierFirearmEffects
var kick:=0.0
var shot_bloom:=0.0
var flash_left:=0.0
var hit_duration:=.2
var kick_side:=1.0
var muzzle_socket: Node3D
var muzzle_model: Node3D
var audio_rng:=RandomNumberGenerator.new()
var damage_numbers=preload("res://scripts/actors/firearm_damage_numbers.gd").new()
var shield_break_left:=0.0
func configure(owner_app: FrontierCrewExpedition) -> void:
	app=owner_app
	process_priority=5
	audio_rng.randomize()
	gun_effects=FrontierFirearmEffects.new();app.add_child(gun_effects);gun_effects.camera=app.camera
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
	var style: Dictionary=FrontierFirearmEffects.config().families.get(event.family,FrontierFirearmEffects.config().families.carbine)
	var family: Dictionary=FrontierFirearms.config().families[event.family]
	if local:
		_update_muzzle()
		origin=muzzle_socket.global_position if is_instance_valid(muzzle_socket) else app.feedback.handheld.to_global(Vector3(0,0,-.78))
		var gun:=tool()
		kick=minf(1.25,kick+.95);kick_side=-kick_side;shot_bloom=minf(1.4,shot_bloom+.75);flash_left=float(style.flash_time)
		app.pitch=clampf(app.pitch+float(gun.recoil)*(1.0-.45*ads)*(.55 if crouched and gun.effect=="braced" else 1),-1.45,1.45)
	app.feedback.audio.play(str(family.sound),Vector3.INF if local else origin,audio_rng.randf_range(.985,1.015),float(style.sound_gain)+audio_rng.randf_range(-.35,.0),"firearm_shot")
	if not local or not (ads>.92 and event.effect in ["precision","weak_chain"]):
		gun_effects.muzzle(origin,-app.camera.global_basis.z,event.family,muzzle_socket if local else null)
	# Magnified near-camera streaks otherwise cover the scope even with the muzzle hidden.
	gun_effects.shot(origin,event,4.0 if local and ads>.92 and event.effect in ["precision","weak_chain"] else 0.0)
	var hit: Dictionary=event.get("hits",{})
	if float(hit.get("damage",0))+float(hit.get("shield",0))>0:
		# Older event snapshots can lack contacts; do not invent a pellet hit location for them.
		if local:
			damage_numbers.add(event.get("damage_targets",[]))
			hit_kind="kill" if hit.killed else "break" if hit.broken else "weak" if hit.weak else "shield" if hit.shield>0 else "organic" if hit.get("organic",false) else "hit"
			var cue: Dictionary=FrontierFirearmEffects.config().confirmation[hit_kind]
			hit_duration=float(cue.duration);hit_left=hit_duration
			if hit.broken:
				shield_break_left=float(FrontierFirearmEffects.config().damage_numbers.break_time)
				var crack: Dictionary=FrontierFirearmEffects.config().confirmation["break"]
				app.feedback.audio.firearm_confirmation("sfx_gun_break_down" if hit.killed else str(crack.sound),float(crack.gain))
			else:app.feedback.audio.firearm_confirmation(str(cue.sound),float(cue.gain))

func _update_muzzle() -> void:
	if muzzle_model==app.feedback.handheld:return
	muzzle_model=app.feedback.handheld
	var sockets:=muzzle_model.find_children("Socket_Muzzle","Node3D",true,false)
	muzzle_socket=sockets[0] if not sockets.is_empty() else null

func _process(delta: float) -> void:
	if app==null:return
	next_shot=maxf(0,next_shot-delta);hit_left=maxf(0,hit_left-delta);flash_left=maxf(0,flash_left-delta)
	damage_numbers.update(delta);shield_break_left=maxf(0,shield_break_left-delta)
	var active:=enabled();var gun:=tool()
	if was_enabled and not active:app.feedback.audio.stop_firearm_cues();gun_effects.clear();damage_numbers.clear();shield_break_left=0;kick=0;shot_bloom=0;hit_left=0;flash_left=0
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
		gun_effects.clear();damage_numbers.clear();shield_break_left=0;kick=0;shot_bloom=0;hit_left=0;flash_left=0;app.feedback.audio.stop_firearm_cues()
		if gun.has("firearm"):
			var states: Dictionary=app.session.latest.crew.members[app.session.latest.self_id].loadout.get("weapon_states",{})
			accepted=states.get(observed_item,{}).duplicate(true);reload_left=float(accepted.get("reload_left",0));reload_duration=maxf(.1,reload_left)
	if reload_left>0:
		reload_left=maxf(0,reload_left-delta)
		if reload_left==0:accepted.ammo=int(gun.get("magazine",0))
	if app.surface_world!=null:app.camera.fov=lerpf(76,38 if gun.get("effect")=="precision" else 57,ads)
	if firearm and app.feedback.handheld!=null:
		var style: Dictionary=FrontierFirearmEffects.config().families[gun.firearm]
		kick*=exp(-float(style.recovery)*delta);shot_bloom=move_toward(shot_bloom,0,delta*7)
		var held: Node3D=app.feedback.handheld
		held.position=held.position.lerp(Vector3(0,-.15,-.72),ads)
		var strength:=kick*lerpf(1,.52,ads)*(.6 if crouched and gun.effect=="braced" else 1.0)
		held.position.z+=float(style.kick)*strength
		held.rotation.x+=float(style.lift)*strength;held.rotation.z+=float(style.roll)*strength*kick_side
		_update_muzzle()
		app.feedback.muzzle.light_color=Color(style.color)
		if is_instance_valid(muzzle_socket):app.feedback.muzzle.position=held.to_local(muzzle_socket.global_position)
		app.feedback.muzzle.omni_range=2.4
		app.feedback.muzzle.light_energy=.7*clampf(flash_left/float(style.flash_time),0,1)
		held.visible=not (ads>.92 and gun.get("effect") in ["precision","weak_chain"])
		var phase:=1.0-reload_left/maxf(.1,reload_duration)
		var motion:=sin(phase*PI) if reload_left>0 else 0.0
		held.rotation.z-=motion*.42;held.position.y-=motion*.13
		for part in app.feedback.parts:
			if part.name.begins_with("Anim_Magazine"):part.position=part.get_meta("rest")+Vector3(0,-motion*.24,motion*.12)
			elif part.name.begins_with("Anim_Bolt") or part.name.begins_with("Anim_Pump"):part.position=part.get_meta("rest")+Vector3(0,0,kick*.075)
	hud.visible=firearm
	if firearm:
		var size:=hud.get_viewport_rect().size;ammo_label.position=Vector2(size.x*.5+45,size.y-126)
		ammo_label.text="%02d / %02d"%[int(accepted.get("ammo",gun.magazine)),int(gun.magazine)]
		reload_bar.position=ammo_label.position+Vector2(0,29);reload_bar.size=Vector2(110,4);reload_bar.visible=reload_left>0;reload_bar.value=(1-reload_left/maxf(.1,reload_duration))*100
	if active:app.reticle.visible=not firearm
	hud.queue_redraw()
func _draw() -> void:
	var center:=hud.get_viewport_rect().size*.5
	if ads<.92:
		var gap:=lerpf(7,3,ads)+shot_bloom*3
		for axis in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
			hud.draw_line(center+axis*gap,center+axis*(gap+3),Color(.87,.96,.93,.7),1.5,true)
	if ads>.92 and tool().get("effect") in ["precision","weak_chain"]:
		var radius:=hud.get_viewport_rect().size.y*.38;var edge:=hud.get_viewport_rect().size.length()
		for i in 64:
			var a:=Vector2.from_angle(i*TAU/64);var b:=Vector2.from_angle((i+1)*TAU/64)
			hud.draw_colored_polygon(PackedVector2Array([center+a*radius,center+b*radius,center+b*edge,center+a*edge]),Color(.015,.024,.031,.94))
		for axis in [Vector2.RIGHT,Vector2.UP]:
			hud.draw_line(center+axis*8,center+axis*radius,Color("c4e0d6"),1,true);hud.draw_line(center-axis*8,center-axis*radius,Color("c4e0d6"),1,true)
	if ads>.8:hud.draw_circle(center,1.7,Color("e5f7ef"))
	damage_numbers.draw(hud,app.camera,ads>.92 and tool().get("effect") in ["precision","weak_chain"])
	if shield_break_left>0:
		var crack_color:=Color(FrontierFirearmEffects.config().damage_numbers.shield_color);crack_color.a=minf(1,shield_break_left/.12)
		damage_numbers.draw_shield(hud,center+Vector2(0,-32),crack_color,true,1-shield_break_left/float(FrontierFirearmEffects.config().damage_numbers.break_time))
	if hit_left<=0:return
	var color:=Color("ffd19b") if hit_kind in ["weak","kill"] else Color("a9e9ff") if hit_kind in ["shield","break"] else Color("e5f7ef")
	var phase:=1-hit_left/hit_duration;color.a=minf(1,hit_left/.075)
	var settle:=2.0*pow(1-phase,3)
	for angle in [PI*.25,PI*.75,PI*1.25,PI*1.75]:
		var direction:=Vector2(cos(angle),sin(angle));hud.draw_line(center+direction*(6+settle),center+direction*((14 if hit_kind in ["break","kill"] else 11)+settle),color,2,true)
	if hit_kind=="break":
		var radius:=16+phase*6
		hud.draw_arc(center,radius,PI*.12,PI*.8,12,color,1.5,true);hud.draw_arc(center,radius,PI*1.12,PI*1.8,12,color,1.5,true)
	if hit_kind=="kill":hud.draw_line(center+Vector2(-4,18),center+Vector2(0,21),color,2,true);hud.draw_line(center+Vector2(0,21),center+Vector2(4,18),color,2,true)
