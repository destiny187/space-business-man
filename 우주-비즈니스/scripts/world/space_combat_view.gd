class_name FrontierSpaceCombatView
extends Node3D
## Authoritative combat presentation in the current expedition viewport.
var view: FrontierCrewFlightView
var models: Dictionary={}
var cache: Dictionary={}
var fx: FrontierSpaceCombatEffects
var key_light: DirectionalLight3D
var rim_light: DirectionalLight3D
var mount_parts: Array=[]
var shot_target:=Vector3.ZERO
var light_blend:=0.0
const COMBAT_LAYER=1<<18
var last_serial: int=-1
var selected_wreck: String=""
var hud: Control
var mount: Node3D
var audio: FrontierAudio
var hit_flash:=0.0
var hit_bearing: float=-PI*.5
var hit_shielded:=false
var shot_flash:=0.0
var hit_confirm:=0.0
var blocked:=true
var visible_enemies: Array=[]
var visible_wrecks: Array=[]
var preloaded: Dictionary={}
var radio: Dictionary={}
var radio_left:=0.0
var warned_encounters: Dictionary={}
func configure(owner_view: FrontierCrewFlightView) -> void:
	view=owner_view
	for cfg in FrontierSpaceCombat.config().enemy.values():
		for path in [cfg.model,cfg.lod]:preloaded[path]=load(path)
	preloaded["mount"]=load("res://assets/models/ships/expedition_pulse_mount.glb")
	preloaded["pod"]=load("res://assets/models/ships/lost_freight_pod.glb")
	fx=FrontierSpaceCombatEffects.new();add_child(fx)
	key_light=DirectionalLight3D.new();key_light.light_cull_mask=COMBAT_LAYER;key_light.light_color=Color("e1edff");add_child(key_light)
	rim_light=DirectionalLight3D.new();rim_light.light_cull_mask=COMBAT_LAYER;rim_light.light_color=Color("f9c18b");add_child(rim_light)
	audio=FrontierAudio.new();add_child(audio)
	for cue in FrontierSpaceCombat.config().audio.values():audio.stream(cue)
	var layer:=CanvasLayer.new();add_child(layer)
	hud=load("res://scripts/ui/space_combat_hud.gd").new();hud.presentation=self;layer.add_child(hud)
func data() -> Dictionary:return view.combat_snapshot
func encounter() -> Dictionary:return data().get("encounter",{})
func id() -> String:return view.freight_carrier
func relevant() -> bool:
	var e:=encounter()
	return not e.is_empty() and not view.navigation.is_empty() and int(e.system)==view.current_system and view.navigation.mode!="jump" and (e.carrier==id() or view.ship.position.distance_to(FrontierSpaceCombat.point(e.origin))<4500)
func armed() -> bool:
	return relevant() and encounter().phase in ["warning","combat"] and id()=="crew" and view.freight_pilot and view.exterior and not blocked
func repair_available() -> bool:
	return not data().is_empty() and view.navigation.get("combat_fitted",false) and float(view.navigation.get("hull",100))<100 and not view.navigation.get("combat_active",false) and view.navigation.get("mode","")=="idle" and absf(float(view.navigation.speed))<=20
func suspend() -> void:
	blocked=true;selected_wreck="";radio={};radio_left=0.0;hide();hud.hide()
	for player in audio.get_children():
		if player is AudioStreamPlayer or player is AudioStreamPlayer3D:player.stop()
	last_serial=int(data().get("event_serial",0));fx.clear();key_light.light_energy=0;rim_light.light_energy=0;light_blend=0
	if is_instance_valid(mount):mount.hide()
func update(delta: float,paused: bool) -> void:
	blocked=paused;hit_flash=maxf(0,hit_flash-delta);shot_flash=maxf(0,shot_flash-delta);hit_confirm=maxf(0,hit_confirm-delta)
	if paused:suspend();return
	radio_left=maxf(0,radio_left-delta)
	if radio_left<=0 or not relevant():radio={}
	show();hud.visible=view.exterior and not data().is_empty()
	visible_enemies=[];visible_wrecks=[];selected_wreck=""
	if relevant() and encounter().phase=="warning" and encounter().carrier==id() and not warned_encounters.has(encounter().id):
		warned_encounters[encounter().id]=true
		audio.play(FrontierSpaceCombat.config().audio.warning)
	var active: Dictionary={}
	light_blend=move_toward(light_blend,1.0 if relevant() else 0.0,delta*2)
	key_light.global_basis=view.camera.global_basis*Basis.from_euler(Vector3(-.55,-.65,0))
	rim_light.global_basis=view.camera.global_basis*Basis.from_euler(Vector3(-.3,2.4,0))
	key_light.light_energy=light_blend*float(FrontierSpaceCombat.config().presentation.key_energy)
	rim_light.light_energy=light_blend*float(FrontierSpaceCombat.config().presentation.rim_energy)
	if light_blend>0:combat_layer(view.ship)
	if not data().is_empty() and view.refits.hull_id!="finch":
		if not is_instance_valid(mount):
			mount=preloaded.mount.instantiate();FrontierInkStyle.apply(mount,cache);view.ship.add_child(mount);mount.position=Vector3(0,3.1,3);mount.scale=Vector3.ONE*2
			mount_parts=parts(mount)
		mount.visible=view.exterior
		for part in mount_parts:
			if str(part.node.name).begins_with("Anim_Barrel_"):part.node.position=part.rest.origin+Vector3(0,0,shot_flash*5)
			if shot_target!=Vector3.ZERO:
				var aim: Vector3=view.ship.global_basis.inverse()*(shot_target-mount.global_position).normalized()
				if part.node.name=="Anim_Yaw":part.node.rotation.y=lerpf(part.node.rotation.y,clampf(atan2(-aim.x,-aim.z),-.36,.36),1-exp(-delta*18))
				if part.node.name=="Anim_Elevation":part.node.rotation.x=lerpf(part.node.rotation.x,clampf(asin(aim.y),-.3,.4),1-exp(-delta*18))
	elif is_instance_valid(mount):mount.queue_free();mount=null;mount_parts=[]
	if relevant():
		var e:=encounter()
		for enemy in e.enemies:
			var key: String="enemy:"+str(e.id)+":"+str(enemy.id)
			if float(enemy.hull)<=0:
				if models.has(key) and not models[key].get("destroyed",false):
					active[key]=true;dying(models[key],enemy,delta)
				continue
			active[key]=true
			var cfg: Dictionary=FrontierSpaceCombat.config().enemy[enemy.kind]
			var p:=FrontierSpaceCombat.point(enemy.position)
			var heading:=FrontierSpaceCombat.point(enemy.direction)
			if e.phase in ["escaped","victory","recovered"]:p+=heading*(float(e.elapsed)*float(cfg.speed)+float(e.elapsed)*float(e.elapsed)*30)
			var row:=model(key,cfg.model,cfg.lod)
			row.root.position=row.root.position.lerp(p,1-exp(-delta*14)) if row.get("placed",false) else p;row.placed=true
			var facing:=FrontierSpaceCombatPilot.basis(heading)*Basis(Vector3.FORWARD,float(enemy.get("roll",0)))
			row.root.quaternion=row.root.quaternion.slerp(facing.get_rotation_quaternion(),1-exp(-delta*8))
			row.near.visible=p.distance_to(view.camera.global_position)<1200;row.far.visible=not row.near.visible
			animate(row,enemy,delta)
			visible_enemies.append(enemy)
		for bolt in e.get("projectiles",[]):
			var p:=FrontierSpaceCombat.point(bolt.position);var velocity:=FrontierSpaceCombat.point(bolt.velocity)
			fx.line(p-velocity.normalized()*18,p,Color("ff9e68"),float(bolt.radius)*.45,delta*1.2)
	for wreck in data().get("wrecks",[]):
		var dying_key: String="enemy:"+str(wreck.id).replace("/",":")
		if models.has(dying_key) and models[dying_key].death_age>0 and not models[dying_key].destroyed:continue
		if int(wreck.system)!=view.current_system or view.navigation.get("mode","")=="jump":continue
		var p:=FrontierSpaceCombat.point(wreck.position)
		if p.distance_to(view.ship.position)>6000:continue
		var key: String="wreck:"+str(wreck.id);active[key]=true
		var row:=model(key,"pod","pod");row.root.position=p;row.root.rotation.y+=delta*.16;row.near.scale=Vector3.ONE*.6;row.far.hide()
		visible_wrecks.append(wreck)
		if p.distance_to(view.ship.position)<=float(FrontierSpaceCombat.config().salvage_range) and not view.camera.is_position_behind(p):
			var screen:=view.camera.unproject_position(p)
			if screen.distance_to(Vector2(view.get_viewport().size)*.5)<220:selected_wreck=wreck.id
	for key in models.keys():
		if not active.has(key):
			if is_instance_valid(models[key].get("charge_voice")):models[key].charge_voice.queue_free()
			models[key].root.queue_free();models.erase(key)
	var event_serial:=int(data().get("event_serial",0))
	if last_serial<0:last_serial=event_serial
	for event in data().get("events",[]):
		if int(event.serial)<=last_serial or int(event.system)!=view.current_system:continue
		var source:=FrontierSpaceCombat.point(event.origin);var target:=FrontierSpaceCombat.point(event.target)
		if source.distance_to(view.ship.position)>4500 and target.distance_to(view.ship.position)>4500:continue
		if FrontierSpaceCombat.config().get("radio",{}).get("lines",{}).has(event.kind):receive_radio(event)
		if event.kind in ["shot","enemy_shot"]:
			var muzzle:=source
			if event.kind=="shot" and event.id==id() and is_instance_valid(mount):
				shot_flash=.12;shot_target=target
				var socket:=mount.find_child("Socket_Muzzle_*",true,false)
				if socket!=null:muzzle=socket.global_position
				fx.tracer(muzzle,target,Color("b5ffed"))
			else:
				for row in models.values():
					if not str(row.get("enemy_id",""))==str(event.id):continue
					var socket: Node3D=row.near.find_child("Socket_Muzzle_*",true,false)
					if socket!=null:muzzle=socket.global_position
			fx.spark(muzzle,Color("caffed") if event.kind=="shot" else Color("ffe6a2"),1.4,.1)
		elif event.kind in ["impact","break"]:
			var shield_anchor: Node3D=view.ship if event.id==id() else null
			var shielded:=false;var center:=target;var radius:=22.0 if id()=="crew" else 13.0
			if event.id==id():
				hit_flash=.25;center=view.ship.position
				var local_source: Vector3=view.camera.global_basis.inverse()*(source-center)
				var screen_source:=Vector2(local_source.x,-local_source.y)
				hit_bearing=screen_source.angle() if screen_source.length()>2 else -PI*.5
				shielded=float(data().get("ships",{}).get(id(),{}).get("shield",0))>0;hit_shielded=shielded or event.kind=="break"
			else:
				hit_confirm=.16
				for enemy in encounter().get("enemies",[]):
					if str(enemy.id)==str(event.id):
						center=FrontierSpaceCombat.point(enemy.position);radius=float(FrontierSpaceCombat.config().enemy[enemy.kind].radius);shielded=enemy.shield>0
						var key: String="enemy:"+str(encounter().id)+":"+str(enemy.id)
						if models.has(key):shield_anchor=models[key].root
						break
			if shielded or event.kind=="break":fx.shield(center,source,radius,event.kind=="break",shield_anchor)
			else:fx.impact(target,source,int(event.serial))
		var cue: String=FrontierSpaceCombat.config().audio.get("enemy_shot" if event.kind=="enemy_shot" else event.kind,"")
		if not cue.is_empty() and event.kind not in ["destroy","warning"]:sound(cue,target if event.kind in ["impact","break"] else source,event.id==id(),.85 if event.kind=="enemy_shot" else 1.0)
	last_serial=event_serial
	var operation: Dictionary=data().get("ships",{}).get(id(),{}).get("operation",{})
	if not operation.is_empty() and operation.kind=="space_salvage":
		for w in visible_wrecks:
			if w.id==operation.id:fx.line(view.ship.position+Vector3.UP*4,FrontierSpaceCombat.point(w.position),Color("83d9c5"),.25,delta*1.2);break
	fx.step(delta)
	hud.queue_redraw()
func receive_radio(event: Dictionary) -> void:
	if not relevant():return
	for enemy in encounter().enemies:
		if str(enemy.id)!=str(event.id) or float(enemy.hull)<=0:continue
		var cfg: Dictionary=FrontierSpaceCombat.config().radio
		var line: Dictionary=cfg.lines[event.kind]
		var receiver: String="원정선" if encounter().carrier=="crew" else "FINCH"
		radio={"sender":str(FrontierSpaceCombat.config().enemy[enemy.kind].name),"receiver":receiver if line.receiver=="target" else str(line.receiver),"text":str(line.text)}
		radio_left=float(cfg.seconds)
		return
func combat_layer(node: Node) -> void:
	if node is MeshInstance3D:node.layers|=COMBAT_LAYER
	for child in node.get_children():combat_layer(child)
func parts(node: Node3D) -> Array:
	var found: Array=[]
	for part in node.find_children("Anim_*","Node3D",true,false):found.append({"node":part,"rest":part.transform})
	return found
func model(key: String,path: String,lod: String) -> Dictionary:
	if models.has(key):return models[key]
	var node:=Node3D.new();add_child(node)
	var near: Node3D=preloaded[path].instantiate();var far: Node3D=preloaded[lod].instantiate()
	node.add_child(near);node.add_child(far);FrontierInkStyle.apply(near,cache);FrontierInkStyle.apply(far,cache);combat_layer(node)
	var jets: Array=[]
	if path!="pod":
		for socket in near.find_children("Socket_Exhaust_*","Node3D",true,false):
			var jet:=MeshInstance3D.new();var cone:=CylinderMesh.new();cone.top_radius=1.5;cone.bottom_radius=.1;cone.height=10;cone.radial_segments=8
			jet.mesh=cone;jet.material_override=fx.material(Color("86dacc"));jet.rotation.x=PI*.5;jet.position.z=5;socket.add_child(jet);jets.append(jet)
	models[key]={"root":node,"near":near,"far":far,"parts":parts(near)+parts(far),"jets":jets,"placed":false,"death_age":0.0,"destroyed":false,"charge":0.0,"enemy_id":""};return models[key]
func animate(row: Dictionary,enemy: Dictionary,delta: float) -> void:
	row.enemy_id=str(enemy.id)
	var leaving: bool=encounter().get("phase","") in ["escaped","victory","recovered"]
	var maneuver: String="break" if leaving else enemy.get("maneuver","approach")
	var charge:=1-float(enemy.windup)/float(FrontierSpaceCombat.config().enemy[enemy.kind].windup) if enemy.windup>0 else 0.0
	for part in row.parts:
		var node: Node3D=part.node;var name: String=node.name;var side: float=-1 if name.ends_with("L") or name.contains("L_") else 1
		var rotation: Vector3=part.rest.basis.get_euler()
		if name.begins_with("Anim_Wing_"):rotation.z=side*(-.25 if maneuver=="align" else .10)+float(enemy.get("roll",0))*.15
		elif name.begins_with("Anim_Flap_"):rotation.x=.6 if maneuver in ["align","break"] else .04
		elif name.begins_with("Anim_Nozzle_"):rotation.y=-float(enemy.get("roll",0))*.28;rotation.x=.15 if maneuver=="break" else 0
		elif name.begins_with("Anim_Jammer_"):rotation.z=side*(.08 if maneuver in ["align","strike"] else .65)
		elif name.begins_with("Anim_Vane_"):rotation.x=-.25-charge*.45 if maneuver=="align" else .15
		elif name.begins_with("Anim_Barrel_"):node.position=part.rest.origin+Vector3(0,0,float(enemy.get("recoil",0))*.85)
		node.rotation=node.rotation.lerp(rotation,1-exp(-delta*10))
	for jet in row.jets:
		jet.scale=Vector3(.8,lerpf(.35,1.8,1.0 if leaving else float(enemy.get("throttle",.2))),.8)
		jet.position.z=jet.scale.y*5
	if charge>0:
		if not is_instance_valid(row.get("charge_voice")):
			var voice:=AudioStreamPlayer3D.new();voice.stream=audio.stream("sfx_robot_charge",true);voice.bus="SFX";voice.max_distance=1200;voice.unit_size=160;voice.volume_db=-24;voice.max_db=-18;audio.add_child(voice);row.charge_voice=voice
		row.charge_voice.global_position=row.root.position
		row.charge_voice.pitch_scale=lerpf(.75,1.3,charge)
		if not row.charge_voice.playing:row.charge_voice.play();audio.last_played["sfx_robot_charge"]=Time.get_ticks_msec()
	elif is_instance_valid(row.get("charge_voice")):row.charge_voice.stop()
	row.charge+=delta
	if charge>0 and row.charge>.06:
		row.charge=0.0
		for socket in row.near.find_children("Socket_Muzzle_*","Node3D",true,false):fx.spark(socket.global_position,Color("ffb268"),.4+charge*1.4,.085)
func dying(row: Dictionary,enemy: Dictionary,delta: float) -> void:
	if is_instance_valid(row.get("charge_voice")):row.charge_voice.stop()
	row.death_age+=delta
	var velocity:=FrontierSpaceCombat.point(enemy.get("velocity",[0,0,0]))
	row.root.position+=velocity*delta*.55;row.root.rotate_object_local(Vector3.FORWARD,delta*.7)
	for jet in row.jets:jet.hide()
	if int(row.death_age*16)!=int((row.death_age-delta)*16):
		fx.vent(row.root.position+row.root.basis*Vector3(7,2,8),velocity,hash(enemy.id)+int(row.death_age*16))
	if row.death_age>=float(FrontierSpaceCombat.config().presentation.corpse_seconds):
		fx.explosion(row.near,velocity,hash(str(enemy.id)));row.destroyed=true;row.root.hide()
		sound(str(FrontierSpaceCombat.config().audio.destroy),row.root.position,false,.85)
func sound(cue: String,position: Vector3,local: bool,pitch: float=1.0) -> void:
	var stream:=audio.stream(cue)
	if stream==null:return
	# A dedicated flight distance curve and finite voice count; ground sounds retain their own range.
	var speakers: Array=[]
	for child in audio.get_children():
		if child is AudioStreamPlayer3D:speakers.append(child)
	if speakers.size()>=20:speakers[0].queue_free()
	var speaker:=AudioStreamPlayer3D.new();speaker.stream=stream;speaker.bus="SFX";speaker.pitch_scale=pitch
	speaker.max_distance=1500;speaker.unit_size=150;speaker.max_db=-8;speaker.volume_db=-15 if local else -12;speaker.attenuation_filter_cutoff_hz=12000
	audio.add_child(speaker);speaker.global_position=view.camera.global_position if local else position
	speaker.finished.connect(speaker.queue_free);speaker.play();audio.last_played[cue]=Time.get_ticks_msec()
