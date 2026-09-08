class_name FrontierRoverController
extends Node
var app: FrontierCrewExpedition
var actors: Dictionary={}
var panel: FrontierRoverPanel
var hint: Label
var gauge: ProgressBar
var chase:=false
var last_seat: String=""
var target: Dictionary={}
var test_controls: Array=[]
func configure(owner_app: FrontierCrewExpedition) -> void:
	app=owner_app
	for key in FrontierInput.DEFAULTS:
		if not InputMap.has_action("frontier_"+key):
			InputMap.add_action("frontier_"+key);var event:=InputEventKey.new();event.physical_keycode=FrontierInput.DEFAULTS[key];InputMap.action_add_event("frontier_"+key,event)
	panel=FrontierRoverPanel.new();app.navigation_frame.get_parent().add_child(panel);panel.configure(app,self)
	hint=Label.new();hint.theme=FrontierInterfaceStyle.theme();hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;hint.mouse_filter=Control.MOUSE_FILTER_IGNORE;hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM);hint.offset_left=-390;hint.offset_right=390;hint.offset_top=-162;hint.offset_bottom=-132;app.navigation_frame.get_parent().add_child(hint)
	gauge=ProgressBar.new();gauge.mouse_filter=Control.MOUSE_FILTER_IGNORE;gauge.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM);gauge.offset_left=-125;gauge.offset_right=125;gauge.offset_top=-130;gauge.offset_bottom=-117;gauge.show_percentage=false;app.navigation_frame.get_parent().add_child(gauge)
func runtime() -> Dictionary:return app.session.authority.rover_runtime if app.session.hosting else app.session.latest.get("rover_runtime",{})
func fleet() -> Dictionary:return FrontierRovers.fleet(app.session.authority.world) if app.session.hosting else app.session.latest.get("rovers",{"vehicles":{},"jobs":{}})
func seat(actor: String="") -> Dictionary:return FrontierRovers.seated(runtime(),actor if not actor.is_empty() else str(app.session.latest.get("self_id","")))
func local() -> Dictionary:
	var result: Dictionary={}
	for id in fleet().vehicles:
		var r: Dictionary=fleet().vehicles[id]
		if r.location_kind=="surface" and r.body_id==app.session.latest.get("location") and app.surface_world!=null:result[id]=r
	return result
func controls(enabled: bool) -> Array:
	if not test_controls.is_empty():return test_controls if enabled else [0.0,0.0,1.0,0.0]
	if not enabled:return [0.0,0.0,1.0,0.0]
	return [float(FrontierInput.pressed("forward"))-float(FrontierInput.pressed("backward")),float(FrontierInput.pressed("right"))-float(FrontierInput.pressed("left")),float(FrontierInput.pressed("jump")),float(FrontierInput.pressed("rover_interact"))]
func physics(delta: float) -> void:
	var rows:=local()
	for id in actors.keys():
		if not rows.has(id):actors[id].queue_free();actors.erase(id)
	for id in rows:
		var r: Dictionary=rows[id]
		if not actors.has(id):
			var node:=FrontierRoverActor.new();app.add_child(node);node.position=FrontierCrewWorld.vector(r.position);node.rotation=FrontierCrewWorld.vector(r.rotation);node.last_distance=float(r.distance);actors[id]=node
	if not app.session.hosting:return
	var authority:=app.session.authority
	authority.rover_spawn_validator=func(p: Vector3):return app.surface_world!=null and app.surface_world.ready_at(p) and clear(p,Vector3(2.6,2.8,4.0))
	var excludes: Array[RID]=[]
	for actor in app.actors.values():excludes.append(actor.get_rid())
	for actor in actors.values():excludes.append(actor.get_rid())
	for id in rows:
		var r: Dictionary=rows[id];var riders:=FrontierRovers.seats(runtime(),id);var input: Dictionary={}
		for peer in authority.peers:
			if authority.peers[peer]==riders[0]:input=authority.inputs.get(peer,{});break
		var enabled: bool=float(input.get("expires",-1))>=authority.now and input.get("controls_enabled",false) and not FrontierRovers.busy(runtime(),id)
		var control: Array=input.get("vehicle_controls",[]) if enabled else []
		if control.size()!=4:control=[0.0,0.0,1.0,0.0]
		for rider in riders:
			if runtime().exits.has(rider):control=[0.0,0.0,1.0,0.0]
		actors[id].drive_host(r,control,delta,app.surface_world,excludes)
		if FrontierRovers.stopped(r):
			for b in FrontierExpeditionBusiness.site(authority.world).get("buildings",{}).values():
				if b.type=="charger" and b.get("active",false) and FrontierRovers.point(r).distance_to(FrontierCrewWorld.vector(b.position))<=float(FrontierRovers.config().charge_range):r.battery=minf(float(FrontierRovers.stats(r).battery),float(r.battery)+float(FrontierRovers.config().charge_rate)*delta);break
		for index in 2:
			var rider: String=riders[index]
			if rider.is_empty():continue
			var member: Dictionary=authority.world.crew.members[rider]
			if runtime().exits.has(rider) and FrontierRovers.stopped(r):
				var p:=Vector3.INF
				for offset in [[-2.45,0,0],[2.45,0,0],[0,0,3.2],[0,0,-3.2]] if index==0 else [[2.45,0,0],[-2.45,0,0],[0,0,3.2],[0,0,-3.2]]:
					var candidate:=FrontierRovers.safe(authority.world,FrontierRovers.point(r,offset),.45,id)
					if candidate.is_finite() and clear(candidate,Vector3(.65,1.7,.65),id):p=candidate+Vector3.UP*.1;break
				if p.is_finite() and clear(p,Vector3(.65,1.7,.65),id):
					riders[index]="";runtime().exits.erase(rider);runtime().status.erase(rider);member.position=FrontierExpeditionBusiness.array(p);r.event="door";r.event_serial+=1
					if app.actors.has(rider):app.actors[rider].position=p;app.actors[rider].velocity=Vector3.ZERO
					continue
				runtime().status[rider]="하차 공간이 막혔습니다 · 자리를 확보하세요"
			member.position=FrontierExpeditionBusiness.array(FrontierRovers.point(r,FrontierRovers.config().eyes[index])-Vector3.UP*1.72)
			if app.actors.has(rider):app.actors[rider].position=FrontierCrewWorld.vector(member.position);app.actors[rider].velocity=Vector3.ZERO
		step_task(r,delta)
	for actor_id in app.actors:
		var seated: bool=not seat(actor_id).is_empty();app.actors[actor_id].collision_layer=0 if seated else 2;app.actors[actor_id].collision_mask=0 if seated else 1
func clear(p: Vector3,size: Vector3,ignore: String="") -> bool:
	var query:=PhysicsShapeQueryParameters3D.new();var shape:=BoxShape3D.new();shape.size=size;query.shape=shape;query.transform.origin=p+Vector3.UP*(size.y*.5+.32);query.collision_mask=11
	if actors.has(ignore):query.exclude=[actors[ignore].get_rid()]
	return app.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
func step_task(r: Dictionary,delta: float) -> void:
	var task: Dictionary=runtime().tasks.get(r.id,{})
	if task.is_empty():return
	var authority:=app.session.authority;var input: Dictionary={}
	for peer in authority.peers:
		if authority.peers[peer]==task.actor:input=authority.inputs.get(peer,{});break
	var control: Array=input.get("vehicle_controls",[])
	if task.kind=="recover":
		task["elapsed"]=float(task.get("elapsed",0))+delta
		if float(task.progress)==0 and float(task.elapsed)<.35 and (control.size()!=4 or control[3]<.5):return
		if float(input.get("expires",-1))<authority.now or control.size()!=4 or control[3]<.5 or not FrontierRovers.within(authority.world,task.actor,r,8) or FrontierCrewWorld.vector(authority.world.crew.members[task.actor].position).distance_to(FrontierCrewWorld.vector(task.origin))>1.5:
			runtime().status[task.actor]="복구 취소 · 차량 가까이에서 F를 계속 눌러 주세요";runtime().tasks.erase(r.id);return
		task.progress+=delta
		if float(task.progress)<float(task.seconds):return
		var center:=FrontierRovers.point(r)
		var validator:=func(candidate: Vector3):
			if not clear(candidate,Vector3(2.6,2.6,3.8),r.id):return false
			return app.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(center+Vector3.UP*1.5,candidate+Vector3.UP*1.5,1,[actors[r.id].get_rid()])).is_empty()
		var p:=FrontierRovers.safe(authority.world,center,2.3,r.id)
		if not p.is_finite() or not validator.call(p):p=FrontierRovers.spawn_point(authority.world,center,r.id,4.0,validator)
		if p.is_finite() and clear(p,Vector3(2.6,2.8,3.8),r.id):
			var query:=PhysicsRayQueryParameters3D.create(center+Vector3.UP*1.5,p+Vector3.UP*1.5,1,[actors[r.id].get_rid()])
			if app.get_world_3d().direct_space_state.intersect_ray(query).is_empty():r.position=FrontierExpeditionBusiness.array(p);r.rotation=[0.0,float(r.rotation[1]),0.0];r.overturned=false;r.speed=0.0;actors[r.id].position=p;actors[r.id].rotation=FrontierCrewWorld.vector(r.rotation);r.event="service";r.event_serial+=1
		if r.overturned:runtime().status[task.actor]="차량 주변 5m에 안전한 복구 공간이 없습니다"
		runtime().tasks.erase(r.id)
func present(delta: float) -> void:
	var rows:=local();var own:=seat()
	var audible: bool=not app.feedback.blocked() and (app.test_mode or app.get_window().has_focus())
	for id in actors:
		if not rows.has(id):continue
		var r: Dictionary=rows[id];var node: FrontierRoverActor=actors[id]
		if not app.session.hosting:
			node.position=node.position.lerp(FrontierCrewWorld.vector(r.position),1-exp(-delta*14));var rot:=FrontierCrewWorld.vector(r.rotation)
			for i in 3:node.rotation[i]=lerp_angle(node.rotation[i],rot[i],1-exp(-delta*14))
		node.present(r,delta,audible,runtime().get("tasks",{}).get(id,{}))
	if not own.is_empty() and actors.has(own.id):
		var node: FrontierRoverActor=actors[own.id]
		if last_seat!=own.id:app.yaw=node.rotation.y;app.pitch=0;chase=false
		if chase:
			var target_point:=node.position+Vector3.UP*1.8;var desired:=target_point+Basis(Vector3.UP,app.yaw)*Vector3(0,2.8,7)
			var hit:=app.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(target_point,desired,1,[node.get_rid()]))
			app.camera.position=hit.position+hit.normal*.3 if not hit.is_empty() else desired;app.camera.look_at(target_point)
		else:app.camera.position=node.visual.socket("Socket_Eye_Driver" if int(own.seat)==0 else "Socket_Eye_Passenger")
		app.cancel_placement()
	last_seat=str(own.get("id",""))
	for actor_id in app.actors:
		var rider:=seat(actor_id)
		if rider.is_empty() or not actors.has(rider.id):continue
		var node: FrontierRoverActor=actors[rider.id]
		app.actors[actor_id].position=node.visual.socket("Socket_Eye_Driver" if int(rider.seat)==0 else "Socket_Eye_Passenger")-Vector3.UP*1.72
		app.visuals[actor_id].pose.seated(node.rotation.y,int(rider.seat)==0)
		app.visuals[actor_id].model.visible=actor_id!=app.session.latest.self_id or chase
		app.visuals[actor_id].label.hide()
	target=find_target()
	hint.visible=app.surface_world!=null and not app.any_menu_open() and not app.arrival.active;gauge.visible=hint.visible and not own.is_empty()
	if not own.is_empty() and rows.has(own.id):
		var r: Dictionary=rows[own.id];hint.text=("%d km/h  ·  "%int(absf(r.speed)*3.6))+ ("운전" if own.seat==0 else "동승 · E 스캔 · %s 운전석"%FrontierInput.text("rover_seat"))+"  ·  %s 제동  ·  %s 하차  ·  %s 시점"%[FrontierInput.text("jump"),FrontierInput.text("rover_interact"),FrontierInput.text("camera")]
		gauge.max_value=float(FrontierRovers.stats(r).battery);gauge.value=r.battery
		if runtime().get("exits",{}).has(app.session.latest.self_id):hint.text=runtime().get("status",{}).get(app.session.latest.self_id,"정차 후 안전한 쪽으로 하차 중")
	else:hint.text=target.get("caption","")
	for id in runtime().get("tasks",{}):
		var task: Dictionary=runtime().tasks[id]
		if task.actor==app.session.latest.self_id:gauge.visible=hint.visible;gauge.max_value=task.seconds;gauge.value=task.progress;hint.text="%s 유지 · 차량 복구 중"%FrontierInput.text("rover_interact")
	if panel.visible:panel.refresh()
func find_target() -> Dictionary:
	if app.surface_world==null or not app.actors.has(app.session.latest.self_id):return {}
	var origin: Vector3=app.actors[app.session.latest.self_id].position
	var closest:=3.01;var result: Dictionary={}
	for id in local():
		var r: Dictionary=local()[id]
		for index in 3:
			var p:=FrontierRovers.point(r,FrontierRovers.config().doors[index] if index<2 else FrontierRovers.config().cargo_point)
			var distance:=origin.distance_to(p)
			if distance>closest or (-app.camera.global_basis.z).dot((p+Vector3.UP*.5-app.camera.position).normalized())<.15:continue
			closest=distance;result={"id":id,"seat":index,"caption":FrontierInput.text("rover_interact")+" · "+("길게 눌러 바로 세우기" if r.overturned else ["운전석 탑승","동승석 탑승","화물 · 정비"][index])}
	return result
func interact() -> bool:
	var own:=seat()
	if not own.is_empty():app.session.send_request("rover_exit",{"id":own.id});return true
	target=find_target()
	if target.is_empty():return false
	var r: Dictionary=local()[target.id]
	if r.overturned:app.session.send_request("rover_recover",{"id":target.id})
	elif int(target.seat)<2:app.session.send_request("rover_enter",{"id":target.id,"seat":target.seat})
	else:app.session.send_request("rover_cargo_open",{"id":target.id});panel.vehicle_id=target.id;app.open_menu(panel)
	return true
