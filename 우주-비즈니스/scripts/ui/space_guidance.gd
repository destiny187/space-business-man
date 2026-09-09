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
	var station:=FrontierSpaceStation.definition(manifest,int(nav.system),int(nav.get("first_stellar_system",-1)))
	if not station.is_empty():
		var marker:=project(camera,FrontierCrewWorld.vector(station.position),viewport_size)
		marker.kind="station";marker.label=station.name+"  정거장";result.append(marker)
	var ordinal:=int(nav.target)
	if FrontierUniverse.system_index(manifest,ordinal)==int(nav.system):
		var body:=FrontierUniverse.body(manifest,ordinal)
		var marker:=project(camera,FrontierUniverse.position(manifest,ordinal,float(nav.get("orbit_time",0))),viewport_size)
		marker.kind="target";marker.label=body.name;result.append(marker)
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
