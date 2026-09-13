extends Node3D
## Local, bounded presentation of host attacks. Never writes damage or world state.
var view: FrontierIncidentView
var bullets: FrontierFirearmEffects
var blasts: FrontierSpaceCombatEffects
var shells: Dictionary = {}
var counters: Dictionary = {"shots":0,"launches":0,"impacts":0}

func _ready() -> void:
	bullets=FrontierFirearmEffects.new();bullets.camera=view.camera;add_child(bullets)
	blasts=FrontierSpaceCombatEffects.new();add_child(blasts)
	for cue in ["sfx_gun_smg","sfx_gun_carbine","sfx_gun_plasma","sfx_ship_missile_blast"]:view.audio.stream(cue)
	process_priority=5

func shot(start: Vector3,finish: Vector3,role: String) -> void:
	var family: String="smg" if role=="raptor" else "carbine"
	bullets.muzzle(start,(finish-start).normalized(),family)
	bullets.shot(start,{"family":family,"rays":[FrontierExplorationIncidents.array(finish)],"contacts":[]})
	# Cartridge smoke belongs to the muzzle; it never draws a line to the victim.
	blasts.blast(start,Vector2(.28,.18),.24,Vector3.UP*.35,3,randf()*20,.035)
	view.audio.play("sfx_gun_smg" if role=="raptor" else "sfx_gun_carbine",start,1.0,-2.0,"firearm_shot")
	counters.shots+=1
	# Only a real terrain/prop endpoint gets a surface impact. No floating hit puffs.
	if view.surface.terrain.field.density(finish-Vector3.UP*.12)>0:
		bullets.impact({"point":FrontierExplorationIncidents.array(finish),"normal":[0,1,0],"kind":"surface"})

func launch(id: String,start: Vector3,finish: Vector3) -> void:
	shells[id]={"clock":0.0,"age":0.0,"remaining":1.0}
	bullets.muzzle(start,(finish-start).normalized(),"shotgun")
	blasts.blast(start,Vector2(.9,.35),.16,(start-finish).normalized()*.8,0,randf()*20,0,(finish-start).normalized())
	view.audio.play("sfx_gun_plasma",start,1.0,-2.0,"firearm_shot");counters.launches+=1

func shell(id: String,start: Vector3,finish: Vector3,age: float,delta: float) -> void:
	if not shells.has(id):return
	var state: Dictionary=shells[id];state.clock+=delta;state.age=maxf(float(state.age)+delta,age)
	if state.age>.75:return
	if state.clock<.04:return
	state.clock=0.0
	# Same straight flight and 0.75 s arrival as the authoritative collision path.
	var at:=start.lerp(finish,clampf(float(state.age)/.75,0,1));var direction: Vector3=(finish-start).normalized()
	blasts.blast(at,Vector2(.48,.09),.07,direction*2,2,float(id.hash()%23),0,direction)
	blasts.blast(at,Vector2(.32,.22),.38,Vector3.UP*.24,3,float(id.hash()%19),.015)

func impact(id: String,point: Vector3) -> void:
	shells.erase(id);counters.impacts+=1
	var at:=point+Vector3.UP*.12
	# One sharp ignition, uneven flame jets, then drifting dust and fragments.
	blasts.blast(at+Vector3.UP*.2,Vector2(2.8,2.1),.10,Vector3.ZERO,1,randf()*20)
	blasts.blast(at+Vector3.UP*.45,Vector2(2.1,1.8),.34,Vector3.UP*1.3,0,randf()*20,.025)
	for i in 5:
		var angle:=float(i)*2.4;var direction:=Vector3(cos(angle),.35+float(i%3)*.25,sin(angle)).normalized()
		blasts.blast(at,Vector2(1.4,.48),.36,direction*4.2,0,angle,.025+i*.013,direction)
		blasts.blast(at,Vector2(1.2,.85),.85,direction*1.9+Vector3.UP*.35,3,angle,.09+i*.022)
	for i in 8:
		var direction:=Vector3(cos(i*2.4),.25+float(i%3)*.22,sin(i*2.4)).normalized()
		blasts.blast(at,Vector2(.28,.035),.35+float(i%3)*.08,direction*(5+i*.4),2,float(i),0,direction)
	view.audio.play("sfx_ship_missile_blast",point,1.2,-6.0,"firearm_shot")

func _process(delta: float) -> void:
	var stopped:=view.blocked()
	bullets.set_process(not stopped)
	if stopped:
		bullets.clear();blasts.clear();shells.clear();return
	for id in shells.keys():
		shells[id].remaining-=delta
		if shells[id].remaining<=0:shells.erase(id)
	blasts.step(delta)
