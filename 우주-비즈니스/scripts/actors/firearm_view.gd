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
var reserve_ammo:=0
var result_sequence:=-1
var draw_left:=0.0
var recoil_index:=0
var recoil_idle:=0.0
var mouse_sway:=Vector2.ZERO
var input_buffered:=false
var ammo_icon: TextureRect
var hands: Node3D
var reload_cues: Dictionary={}
var empty_latched:=false
var recoil_impulses: Dictionary={}
var predicted_shots:=0
var beam_audio: Dictionary={}
var heat_bar: ProgressBar
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
		if kind in ["surface_fire","surface_reload","surface_stance"]:pending[sequence]={"kind":kind,"item_id":args.get("item_id","")}
		if kind=="surface_fire" and args.get("item_id","")==tool().get("item_id",""):_anticipate(sequence,tool()))
	app.session.response_received.connect(_response)
	app.session.snapshot_received.connect(_snapshot)
	app.session.firearm_event_received.connect(_event)
	heat_bar=ProgressBar.new();heat_bar.show_percentage=false;heat_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE;hud.add_child(heat_bar)
	ammo_icon=TextureRect.new();ammo_icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;ammo_icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;ammo_icon.mouse_filter=Control.MOUSE_FILTER_IGNORE;hud.add_child(ammo_icon)
func enabled() -> bool:
	return app.session.active and not app.session.latest.is_empty() and app.session.latest.crew.members[app.session.latest.self_id].area=="surface" and not app.session.latest.crew.members[app.session.latest.self_id].aboard and app.surface_world!=null and not app.feedback.blocked() and app.placement_kind.is_empty() and not app.outside and app.rovers.seat().is_empty() and (app.test_mode or app.get_window().has_focus())
func tool() -> Dictionary:
	return FrontierEquipment.active(app.session.latest.crew.members[app.session.latest.self_id]) if not app.session.latest.is_empty() else {}
func shoot() -> void:
	if not enabled():return
	if next_shot>0 or draw_left>0:
		input_buffered=not tool().get("auto",false);return
	# Keep cadence independent of round-trip time; at most four unacknowledged shots.
	if pending.values().filter(func(p):return p.kind=="surface_fire").size()>=4:
		input_buffered=not tool().get("auto",false);return
	var gun:=tool()
	if not gun.has("firearm") or reload_left>0 or accepted.get("overheated",false):return
	if int(accepted.get("ammo",gun.magazine))<=0:reload(true);return
	if int(accepted.get("ammo",gun.magazine))<=pending.values().filter(func(p):return p.kind=="surface_fire" and p.item_id==gun.item_id).size():return
	next_shot=maxf(.06,float(gun.interval))
	var aim: Vector3=-app.camera.global_basis.z
	app.session.send_request("surface_fire",{"item_id":gun.item_id,"aim":[aim.x,aim.y,aim.z],"ads":ads>.5})
func reload(automatic: bool=false) -> void:
	if not enabled():return
	if automatic and empty_latched:return
	var gun:=tool()
	if gun.has("firearm") and reload_left<=0 and not pending.values().any(func(p):return p.kind=="surface_reload"):
		app.session.send_request("surface_reload",{"item_id":gun.item_id})
func _response(sequence: int,result: Dictionary) -> void:
	if not pending.has(sequence):return
	var request: Dictionary=pending[sequence];pending.erase(sequence)
	if request.kind=="surface_stance":
		if result.has("crouched"):crouched=result.crouched;last_stance=crouched
		if not result.get("ok",false):
			stance_retry=.25
			last_stance=bool(result.get("crouched",app.session.latest.crew.members[app.session.latest.self_id].loadout.get("crouched",false)))
		return
	if request.item_id!=tool().get("item_id",""):
		if result.get("ok",false) and result.has("rays"):result.actor=app.session.latest.self_id;present(result,false)
		return
	if not result.get("ok",false):
		if recoil_impulses.has(sequence):recoil_impulses[sequence].denied=true
		if result.has("weapon"):accepted=result.weapon.duplicate(true)
		if result.get("code","")=="no_ammo":empty_latched=true;reserve_ammo=0
		if result.has("error"):app.feedback.reject(result.error)
		return
	result_sequence=sequence
	if result.has("reserve"):reserve_ammo=int(result.reserve)
	seen[app.session.latest.self_id]=sequence
	if result.has("weapon"):accepted=result.weapon.duplicate(true)
	if result.get("reload",false):
		if recoil_impulses.has(sequence):recoil_impulses[sequence].denied=true
		reload_left=float(result.duration);reload_duration=reload_left
		reload_cues.clear()
	elif result.has("rays"):
		result.actor=app.session.latest.self_id;present(result,true)
func _snapshot(value: Dictionary) -> void:
	for id in value.get("crew",{}).get("members",{}):
		var member: Dictionary=value.crew.members[id]
		if id==value.self_id and int(member.get("last_sequence",0))>=result_sequence:
			var state: Dictionary=member.get("loadout",{}).get("weapon_states",{}).get(observed_item,{})
			if not state.is_empty():accepted=state.duplicate(true);reload_left=float(state.get("reload_left",0));reload_duration=maxf(.1,float(state.get("reload_duration",reload_duration)))
			reserve_ammo=FrontierFirearms.reserve(tool(),value.get("inventory",{}))
		var event: Dictionary=member.get("weapon_event",{})
		if event.get("ballistic",false):continue
		var serial:=int(event.get("serial",0))
		if not seen.has(id):seen[id]=serial;continue
		if serial<=int(seen[id]):continue
		seen[id]=serial
		if id!=value.self_id and event.has("rays") and member.get("place_key","")==value.crew.members[value.self_id].get("place_key","!"):present(event,false)
func _event(event: Dictionary) -> void:
	if app.session.latest.is_empty() or event.get("body_id","")!=app.session.latest.get("location",""):return
	var local: bool=event.get("actor","")==app.session.latest.self_id
	if event.get("impact_only",false):present(event,local)
	elif not local:present(event,false)
func present(event: Dictionary,local: bool) -> void:
	if not enabled():return
	var impact: bool=event.get("impact_only",false)
	var origin:=FrontierCrewWorld.vector(event.get("origin",[0,0,0]))
	var style: Dictionary=FrontierFirearmEffects.config().families.get(event.family,FrontierFirearmEffects.config().families.carbine)
	var family: Dictionary=FrontierFirearms.config().families[event.family]
	if local and not impact:
		_update_muzzle()
		if not recoil_impulses.has(int(event.get("serial",-1))):_anticipate(int(event.get("serial",-1)),tool())
		flash_left=float(style.flash_time)
	if not impact:
		if event.get("beam",false):_beam_sound(str(event.get("actor","")),origin,local,float(event.get("weapon",{}).get("heat",0)))
		else:app.feedback.audio.play(str(family.sound),Vector3.INF if local else origin,audio_rng.randf_range(.985,1.015),float(style.sound_gain)+audio_rng.randf_range(-.35,.0),"firearm_shot")
		if not local or not (ads>.92 and event.effect in ["precision","weak_chain"]):
			var flash_origin: Vector3=muzzle_socket.global_position if local and is_instance_valid(muzzle_socket) else origin
			gun_effects.muzzle(flash_origin,-app.camera.global_basis.z,event.family,muzzle_socket if local else null)
	if event.get("beam",false) and local and is_instance_valid(muzzle_socket):origin=muzzle_socket.global_position
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
				var crack: Dictionary=FrontierFirearmEffects.config().confirmation["break"]
				app.feedback.audio.firearm_confirmation("sfx_gun_break_down" if hit.killed else str(crack.sound),float(crack.gain))
			else:app.feedback.audio.firearm_confirmation(str(cue.sound),float(cue.gain))

func _update_muzzle() -> void:
	if muzzle_model==app.feedback.handheld:return
	muzzle_model=app.feedback.handheld
	if tool().has("firearm"):
		hands=preload("res://scripts/actors/firearm_hands.gd").new();hands.configure(muzzle_model)
	var sockets:=muzzle_model.find_children("Socket_Muzzle","Node3D",true,false)
	muzzle_socket=sockets[0] if not sockets.is_empty() else null

func _process(delta: float) -> void:
	if app==null:return
	_recover(delta)
	for actor in beam_audio.keys():
		var voice: Dictionary=beam_audio[actor];voice.left-=delta
		if voice.left<=0 or not enabled():voice.node.stop();voice.node.queue_free();beam_audio.erase(actor)
		else:voice.node.volume_db=-22+linear_to_db(clampf(voice.left/.04,.001,1))
	draw_left=maxf(0,draw_left-delta);recoil_idle+=delta
	next_shot=maxf(0,next_shot-delta);hit_left=maxf(0,hit_left-delta);flash_left=maxf(0,flash_left-delta)
	damage_numbers.update(delta)
	var active:=enabled();var gun:=tool()
	if reserve_ammo!=0 or (not app.test_mode and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):empty_latched=false
	if was_enabled and not active:app.feedback.audio.stop_firearm_cues();gun_effects.clear();damage_numbers.clear();kick=0;shot_bloom=0;hit_left=0;flash_left=0
	was_enabled=active
	var firearm: bool=active and gun.has("firearm")
	var preferences:=FrontierClientSettings.ensure(get_tree())
	var aiming:=FrontierPlayInput.state("aim",Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT),firearm,bool(preferences.values.toggle_aim))
	ads=move_toward(ads,1.0 if firearm and (test_ads if app.test_mode else aiming) else 0.0,delta/maxf(.05,float(gun.get("ads_seconds",.18))))
	stance_retry=maxf(0,stance_retry-delta)
	if active and stance_retry<=0 and not app.test_mode:crouched=FrontierPlayInput.pressed("crouch")
	if active and stance_retry<=0 and crouched!=last_stance:
		last_stance=crouched
		app.session.send_request("surface_stance",{"crouched":crouched})
	if not active:
		ads=0
		if not app.session.latest.is_empty() and (app.session.latest.crew.members[app.session.latest.self_id].area!="surface" or app.session.latest.crew.members[app.session.latest.self_id].aboard):crouched=false;last_stance=false
	if gun.get("item_id","")!=observed_item:
		observed_item=gun.get("item_id","");accepted={};reload_left=0;next_shot=.12;draw_left=float(gun.get("draw_seconds",.22));input_buffered=false;recoil_index=0;empty_latched=false
		gun_effects.clear(true);damage_numbers.clear();kick=0;shot_bloom=0;hit_left=0;flash_left=0;app.feedback.audio.stop_firearm_cues()
		if gun.has("firearm"):
			var states: Dictionary=app.session.latest.crew.members[app.session.latest.self_id].loadout.get("weapon_states",{})
			accepted=states.get(observed_item,{}).duplicate(true);reload_left=float(accepted.get("reload_left",0));reload_duration=maxf(.1,float(accepted.get("reload_duration",reload_left)))
			reserve_ammo=FrontierFirearms.reserve(gun,app.session.latest.get("inventory",{}));reload_cues.clear()
	if reload_left>0:
		reload_left=maxf(0,reload_left-delta)

	if app.surface_world!=null:app.camera.fov=lerpf(float(preferences.values.fov),float(gun.get("ads_fov",57)),ads)
	if firearm and app.feedback.handheld!=null:
		var style: Dictionary=FrontierFirearmEffects.config().families[gun.firearm]
		kick*=exp(-float(style.recovery)*delta);shot_bloom=move_toward(shot_bloom,0,delta*7)
		var held: Node3D=app.feedback.handheld
		held.position=Vector3(.24,held.position.y,-.65).lerp(Vector3(0,-.15,-.60),ads)
		var strength:=kick*lerpf(1,.52,ads)*(.6 if crouched and gun.effect=="braced" else 1.0)
		held.position.z+=float(style.kick)*strength
		held.rotation.x+=float(style.lift)*strength;held.rotation.z+=float(style.roll)*strength*kick_side
		mouse_sway=mouse_sway.lerp(Vector2.ZERO,1-exp(-delta*12))
		held.rotation.y+=mouse_sway.x*(1-ads*.8);held.rotation.x+=mouse_sway.y*(1-ads*.8)
		held.position.y-=draw_left*.5;held.rotation.x-=draw_left*.5
		_update_muzzle()
		app.feedback.muzzle.light_color=Color(style.color)
		if is_instance_valid(muzzle_socket):app.feedback.muzzle.position=held.to_local(muzzle_socket.global_position)
		app.feedback.muzzle.omni_range=2.4
		app.feedback.muzzle.light_energy=.7*clampf(flash_left/float(style.flash_time),0,1)
		held.visible=not (ads>.92 and gun.get("effect") in ["precision","weak_chain"])
		var phase:=1.0-reload_left/maxf(.1,reload_duration)
		var motion:=sin(phase*PI) if reload_left>0 else 0.0
		held.rotation.z-=motion*float(gun.reload_tilt);held.position.y-=motion*.08
		if is_instance_valid(hands):hands.pose(gun,app.feedback.parts,phase,reload_left>0,kick,float(accepted.get("heat",0)))
		if reload_left>0:
			for cue in {"sfx_gun_mag_out":float(gun.get("reload_out",.19)),"sfx_gun_mag_in":float(gun.get("reload_insert",.64)),"sfx_gun_charge":float(gun.get("reload_charge",.82))}:
				var at: float={"sfx_gun_mag_out":float(gun.get("reload_out",.19)),"sfx_gun_mag_in":float(gun.get("reload_insert",.64)),"sfx_gun_charge":float(gun.get("reload_charge",.82))}[cue]
				if phase>=at and not reload_cues.has(cue):
					reload_cues[cue]=true
					app.feedback.audio.play(cue,Vector3.INF,.9 if gun.firearm=="lmg" else 1.0)
	hud.visible=firearm
	if firearm:
		heat_bar.visible=gun.effect=="beam"
		heat_bar.value=float(accepted.get("heat",0))*100;heat_bar.modulate=Color("ff865d") if accepted.get("overheated",false) else Color("85f7e3")
		heat_bar.position=ammo_label.position+Vector2(0,-10);heat_bar.size=Vector2(110,4)
		var size:=hud.get_viewport_rect().size;ammo_label.position=Vector2(size.x*.5+45,size.y-126)
		var display_reserve: String="∞" if str(gun.get("ammo_type","")).is_empty() else str(maxi(0,reserve_ammo))
		ammo_label.text="%02d / %s"%[int(accepted.get("ammo",gun.magazine)),display_reserve]
		ammo_icon.texture=FrontierResourceIcons.texture(str(gun.ammo_type)) if not str(gun.get("ammo_type","")).is_empty() else null
		ammo_icon.position=ammo_label.position-Vector2(32,-2);ammo_icon.size=Vector2(26,26)
		ammo_label.modulate=FrontierInterfaceStyle.WARNING if int(accepted.get("ammo",1))==0 else Color.WHITE
		reload_bar.position=ammo_label.position+Vector2(0,29);reload_bar.size=Vector2(110,4);reload_bar.visible=reload_left>0;reload_bar.value=(1-reload_left/maxf(.1,reload_duration))*100
	if input_buffered and active and next_shot<=0 and draw_left<=0 and reload_left<=0:input_buffered=false;shoot()
	if not active:
		input_buffered=false
		if reload_left>0:
			var progress:=1-reload_left/maxf(.1,reload_duration)
			for cue in {"sfx_gun_mag_out":float(gun.get("reload_out",.19)),"sfx_gun_mag_in":float(gun.get("reload_insert",.64)),"sfx_gun_charge":float(gun.get("reload_charge",.82))}:
				if progress>={"sfx_gun_mag_out":float(gun.get("reload_out",.19)),"sfx_gun_mag_in":float(gun.get("reload_insert",.64)),"sfx_gun_charge":float(gun.get("reload_charge",.82))}[cue]:reload_cues[cue]=true
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
	if hit_left<=0:return
	var color:=Color("ffd19b") if hit_kind in ["weak","kill"] else Color("a9e9ff") if hit_kind in ["shield","break"] else Color("e5f7ef")
	var phase:=1-hit_left/hit_duration;color.a=minf(1,hit_left/.075)
	var settle:=2.0*pow(1-phase,3)
	for angle in [PI*.25,PI*.75,PI*1.25,PI*1.75]:
		var direction:=Vector2(cos(angle),sin(angle));hud.draw_line(center+direction*(6+settle),center+direction*((14 if hit_kind in ["break","kill"] else 11)+settle),color,2,true)
	if hit_kind=="kill":hud.draw_line(center+Vector2(-4,18),center+Vector2(0,21),color,2,true);hud.draw_line(center+Vector2(0,21),center+Vector2(4,18),color,2,true)

func _anticipate(sequence: int,gun: Dictionary) -> void:
	# Reversible trigger motion only. Audio, muzzle, ammunition and all hit
	# confirmations still require the host result.
	if not enabled() or not gun.has("firearm"):return
	kick=minf(1.25,kick+.95);kick_side=-kick_side;shot_bloom=minf(1.4,shot_bloom+.75)
	if recoil_idle>1:recoil_index=0
	var pattern: Array=gun.recoil_pattern
	var strength:=float(gun.recoil)*(1-.45*ads)*(.55 if crouched and gun.effect=="braced" else 1.0)
	var amount:=Vector2(float(pattern[recoil_index%pattern.size()])*strength,minf(strength,1.45-app.pitch))
	app.pitch+=amount.y;app.yaw+=amount.x
	recoil_impulses[sequence]={"amount":amount,"age":0.0,"delay":float(gun.recovery_delay),"speed":float(gun.recovery_speed),"denied":false}
	recoil_index+=1;recoil_idle=0;predicted_shots+=1
func _recover(delta: float) -> void:
	for sequence in recoil_impulses.keys():
		var impulse: Dictionary=recoil_impulses[sequence];var previous:=float(impulse.age);impulse.age+=delta
		var active_delta:=delta if impulse.denied else maxf(0,float(impulse.age)-maxf(previous,float(impulse.delay)))
		var amount: Vector2=impulse.amount*(1-exp(-active_delta*(40.0 if impulse.denied else float(impulse.speed))))
		app.pitch=clampf(app.pitch-amount.y,-1.45,1.45);app.yaw-=amount.x;impulse.amount-=amount
		# Keep the receipt marker until slow responses have arrived, preventing
		# a second kick after the predicted movement already recovered.
		if impulse.age>2.0 and not pending.has(sequence):recoil_impulses.erase(sequence)
func _beam_sound(actor: String,origin: Vector3,local: bool,heat: float) -> void:
	if not beam_audio.has(actor):
		var speaker: Node=AudioStreamPlayer.new() if local else AudioStreamPlayer3D.new()
		speaker.stream=app.feedback.audio.stream("sfx_gun_laser_loop",true);speaker.bus="SFX";speaker.volume_db=-22
		if not local:speaker.max_distance=85
		add_child(speaker);speaker.play();beam_audio[actor]={"node":speaker,"left":.18}
	var voice: Dictionary=beam_audio[actor];voice.left=.18;voice.node.pitch_scale=1+heat*.08
	if not local:voice.node.global_position=origin
