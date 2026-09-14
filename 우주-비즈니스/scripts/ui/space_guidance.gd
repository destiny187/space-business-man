class_name FrontierSpaceGuidance
extends RefCounted
static func project(camera: Camera3D,point: Vector3,viewport_size: Vector2) -> Dictionary:
	var inset:=Vector2(minf(64,viewport_size.x*.12),minf(110,viewport_size.y*.2))
	var bounds:=Rect2(inset,viewport_size-inset*2)
	var local:=camera.to_local(point)
	var screen:=camera.unproject_position(point) if local.z<-.01 else viewport_size*.5+Vector2(local.x,-local.y)
	var onscreen: bool=local.z<-.01 and bounds.has_point(screen)
	var offset: Vector2=screen-viewport_size*.5
	var direction: Vector2=offset.normalized() if offset.length_squared()>.001 else Vector2.DOWN
	if not onscreen:
		var half:=bounds.size*.5
		var distance:=minf(half.x/maxf(absf(direction.x),.0001),half.y/maxf(absf(direction.y),.0001))
		screen=viewport_size*.5+direction*distance
	return {"point":screen,"direction":direction,"onscreen":onscreen}
static func read(manifest: Dictionary,nav: Dictionary,camera: Camera3D,viewport_size: Vector2) -> Array:
	if nav.mode=="jump":return []
	var result: Array=[]
	for station in FrontierSpaceStation.all(manifest,int(nav.system),int(nav.get("first_stellar_system",-1)),float(nav.orbit_time)):
		var marker:=project(camera,FrontierCrewWorld.vector(station.position),viewport_size)
		marker.id=station.id;marker.world_point=FrontierCrewWorld.vector(station.position);marker.kind="station";marker.label=station.name+"  정거장";result.append(marker)
	var ordinal:=int(nav.target)
	if FrontierUniverse.system_index(manifest,ordinal)==int(nav.system):
		var body:=FrontierUniverse.body(manifest,ordinal)
		var marker:=project(camera,FrontierUniverse.position(manifest,ordinal,float(nav.get("orbit_time",0))),viewport_size)
		marker.id=body.id;marker.world_point=FrontierUniverse.position(manifest,ordinal,float(nav.get("orbit_time",0)));marker.kind="target";marker.label=body.name;result.append(marker)
	var star:=FrontierUniverse.star_settings(manifest,int(nav.system))
	var ship:=FrontierCrewWorld.vector(nav.position)
	var gap: float=ship.length()-float(star.star_warning_radius)
	var closing: float=-ship.normalized().dot(FrontierCrewWorld.vector(nav.direction))*float(nav.speed)
	if nav.get("star_warning",false) or (gap<float(FrontierFlightTelemetry.config().warning_preview_distance) and closing>0):
		var marker:=project(camera,Vector3.ZERO,viewport_size)
		marker.kind="hazard"
		marker.label="항성 위험 구역" if gap<=0 else "경고 경계까지 "+FrontierFlightTelemetry.distance_label(gap)
		result.append(marker)
	return result

static func readout(canvas: Control,box: Rect2,anchor: Vector2,progress: float=1.0) -> void:
	var cyan:=Color(.35,.88,1,.85)
	canvas.draw_rect(box,Color(.025,.065,.10,.92))
	canvas.draw_rect(box,Color(cyan,.45),false,1)
	var edge:=Vector2(box.position.x if anchor.x<box.get_center().x else box.end.x,clampf(anchor.y,box.position.y+16,box.end.y-16))
	var elbow:=edge+Vector2(-16 if anchor.x<box.get_center().x else 16,0)
	canvas.draw_polyline(PackedVector2Array([anchor,elbow,edge]),cyan,1.5,true)
	canvas.draw_rect(Rect2(anchor-Vector2.ONE*3,Vector2.ONE*6),cyan,false,1)
	for y in range(8,int(box.size.y),12):canvas.draw_line(box.position+Vector2(1,y),box.position+Vector2(box.size.x-1,y),Color(.3,.8,1,.035))
	for corner in [box.position,Vector2(box.end.x,box.position.y),box.end,Vector2(box.position.x,box.end.y)]:
		var toward: Vector2=(box.get_center()-corner).sign()
		canvas.draw_line(corner,corner+Vector2(toward.x*12,0),cyan,2)
		canvas.draw_line(corner,corner+Vector2(0,toward.y*10),cyan,2)
	canvas.draw_line(box.position+Vector2(1,2),box.position+Vector2(maxf(1,(box.size.x-2)*progress),2),cyan,2)
