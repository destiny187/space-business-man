class_name FrontierSurfaceCourier
extends CharacterBody3D
signal status_changed(text: String)
var record: Dictionary
var terrain: FrontierTerrainStreamer
var settings: Dictionary
var player: CharacterBody3D
var depot:=Vector3(-4,2,4)
var points: Array=[]
var waypoint:=0
var job: Dictionary={}
var request_version:=0
var pending_path:=false
var transfer_time:=0.0
var stuck_time:=0.0
var retry_time:=0.0
var reason:="대기"
var wheels: Array[Node3D]=[]
var label: Label3D
var path_metrics: Dictionary={}
var last_foot:=Vector3.ZERO
func configure(data: Dictionary,stream: FrontierTerrainStreamer,carrier: CharacterBody3D) -> void:
	record=data;terrain=stream;player=carrier;settings=FrontierSurfaceLogistics.config()
	var saved: Array=record.robot.position
	position=Vector3(saved[0],saved[1],saved[2]);floor_snap_length=.7
	var collision:=CollisionShape3D.new();var shape:=CapsuleShape3D.new();shape.radius=.73;shape.height=1.5;collision.shape=shape;add_child(collision)
	collision_layer=2;collision_mask=1
	var visual: Node3D=load("res://assets/models/robots/locus_courier.glb").instantiate()
	visual.scale=Vector3.ONE*.45;visual.position.y=-.75;visual.rotation.y=PI;add_child(visual)
	FrontierInkStyle.apply(visual,{})
	_find_wheels(visual)
	label=Label3D.new();label.position.y=1.7;label.font=load("res://assets/fonts/NotoSansKR.ttf");label.font_size=44;label.pixel_size=.007
	label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.no_depth_test=false;label.modulate=Color("e1d7bf");add_child(label)
	terrain.geometry_changed.connect(_terrain_changed)
	if record.robot.phase!="idle":pending_path=true
func _find_wheels(node: Node) -> void:
	if node is Node3D and node.name.begins_with("Anim_Wheel_"):wheels.append(node)
	for child in node.get_children():_find_wheels(child)
func request_pickup() -> bool:
	if int(record.hand_rock)==0:status_changed.emit("운반할 채집물이 없습니다.");return false
	if record.robot.cargo>=int(settings.cargo_capacity):status_changed.emit("로봇 화물칸이 가득 찼습니다.");return false
	var target:=player.position-Vector3.UP*.9
	record.robot.target=[target.x,target.y,target.z];record.robot.phase="pickup"
	_request_path();return true
func request_return() -> void:
	record.robot.target=[depot.x,depot.y,depot.z];record.robot.phase="return";_request_path()
func _request_path() -> void:
	request_version+=1;pending_path=true;points.clear();waypoint=0;velocity=Vector3.ZERO;stuck_time=0;transfer_time=0
	reason="경로 조사 중"
func _terrain_changed() -> void:
	if record.robot.phase!="idle":_request_path()
func _all_edits() -> Array:
	var seen: Dictionary={};var result: Array=[]
	for edits in terrain.field.edits_by_chunk.values():
		for edit in edits:
			var id:=JSON.stringify(edit)
			if not seen.has(id):seen[id]=true;result.append(edit.duplicate(true))
	return result
func _build_path(packet: Dictionary,start: Vector3,target: Vector3,edits: Array,seed_value: int,span: float,traits: Dictionary) -> void:
	var field:=FrontierTerrainField.new();field.configure(seed_value,edits,span,traits)
	packet.result=FrontierTerrainNavigation.new().find_path(field,start,target,settings.navigation)
func _process(_delta: float) -> void:
	if not job.is_empty() and WorkerThreadPool.is_task_completed(job.task):
		WorkerThreadPool.wait_for_task_completion(job.task)
		if job.version==request_version:
			var result: Dictionary=job.packet.result
			points=result.points;waypoint=1 if points.size()>1 else 0;path_metrics=result.duplicate();path_metrics.erase("points")
			if points.is_empty():reason=result.reason;retry_time=3.0
			else:reason="회수 지점으로 이동" if record.robot.phase=="pickup" else "착륙 창고로 운반"
		job.clear()
	if pending_path and job.is_empty() and terrain.ready_at(position):
		pending_path=false
		var target: Array=record.robot.target;var packet: Dictionary={"result":{}}
		var task:=WorkerThreadPool.add_task(_build_path.bind(packet,position-Vector3.UP*.75,Vector3(target[0],target[1],target[2]),_all_edits(),terrain.seed_number,terrain.span,terrain.field.traits.duplicate(true)),false,"courier navigation")
		job={"task":task,"packet":packet,"version":request_version}
	label.text="M–07  ·  %d/%d\n%s" % [int(record.robot.cargo),int(settings.cargo_capacity),reason]
func _physics_process(delta: float) -> void:
	if not terrain.ready_at(position):velocity=Vector3.ZERO;return
	var close_to_carrier: bool=record.robot.phase=="pickup" and not pending_path and job.is_empty() and _can_transfer()
	var direction:=Vector3.ZERO
	if not close_to_carrier and job.is_empty() and not pending_path and waypoint<points.size():
		var target: Vector3=points[waypoint];var offset:=Vector3(target.x-position.x,0,target.z-position.z)
		if offset.length()<.45:waypoint+=1;stuck_time=0
		else:direction=offset.normalized()
	var next:=position+direction*float(settings.speed)*delta
	if not terrain.ready_at(next):velocity=Vector3.ZERO;return
	velocity.x=direction.x*float(settings.speed);velocity.z=direction.z*float(settings.speed)
	if not is_on_floor():velocity.y-=14*delta
	var previous:=position
	move_and_slide()
	var travelled: float=Vector2(position.x-previous.x,position.z-previous.z).length()
	if direction.length_squared()>.1:
		rotation.y=lerp_angle(rotation.y,atan2(-direction.x,-direction.z),minf(1,delta*8))
		stuck_time=stuck_time+delta if travelled<.005 else 0
		for wheel in wheels:wheel.rotation.x-=travelled/(.63*.45)
	if stuck_time>2:
		points.clear();reason="경로가 막혔습니다 · 화물 보존";retry_time=3;stuck_time=0
	if close_to_carrier:_transfer(delta)
	elif not pending_path and job.is_empty() and waypoint>=points.size() and record.robot.phase!="idle":
		var target: Array=record.robot.target
		var distance: float=position.distance_to(Vector3(target[0],target[1]+.75,target[2]))
		if distance<float(settings.transfer_distance):_transfer(delta)
		else:
			retry_time-=delta
			if retry_time<=0:retry_time=3;_request_path()
	record.robot.position=[position.x,position.y,position.z]
func _can_transfer() -> bool:
	if position.distance_to(player.position)>float(settings.transfer_distance):return false
	var query:=PhysicsRayQueryParameters3D.create(global_position,player.global_position)
	query.exclude=[get_rid(),player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
func _transfer(delta: float) -> void:
	if record.robot.phase=="pickup" and not _can_transfer():reason="운반 대상이 멀어졌습니다 · 호출 대기";return
	transfer_time+=delta
	reason="채집물 적재 중" if record.robot.phase=="pickup" else "착륙 창고에 하역 중"
	if transfer_time<float(settings.transfer_seconds):return
	transfer_time=0
	if record.robot.phase=="pickup":
		var loaded:=FrontierSurfaceLogistics.load_cargo(record)
		status_changed.emit("로봇에 암석 %d개를 실었습니다." % loaded);request_return()
	else:
		var unloaded:=FrontierSurfaceLogistics.unload(record)
		record.robot.phase="idle";points.clear();reason="하역 완료 · 대기"
		status_changed.emit("착륙 창고에 암석 %d개를 하역했습니다." % unloaded)
func _exit_tree() -> void:
	if not job.is_empty():WorkerThreadPool.wait_for_task_completion(job.task)
