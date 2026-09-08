extends Control
signal selected(ordinal: int)
signal station_selected(index: int)
signal route_selected(ordinal: int)
var stellar_range:=8.0
var nearby_only:=false
var scene_3d
var route_system: int=-1
var spatial_key: String=""
var spatial_indices: Dictionary={}
var station_excluded: int=-1
var journal: FrontierNavigationJournal
var manifest: Dictionary={}
var system_index:=0
var current_system:=0
var elapsed:=0.0
var galaxy:=false
var transit: Dictionary={}
var target:=0
var hits: Array=[]
var compact:=false
var ship_position:=Vector3.ZERO
var ship_direction:=Vector3.FORWARD
var zoom:=1.0
var pan:=Vector2.ZERO
# Coordinate-only spatial cache; never instantiate the million planet records.
var map_key: String=""
var map_points:=PackedVector2Array()
var map_cells: Dictionary={}
var map_built:=0
var displayed_systems: Dictionary={}
var map_worker: Thread
var pending_map_key: String=""
func _exit_tree() -> void:
	if map_worker!=null and map_worker.is_started():map_worker.wait_to_finish()
func _process(_delta: float) -> void:
	if compact or not galaxy or not is_visible_in_tree() or manifest.is_empty():return
	if map_built!=FrontierStellarRoutes.built:
		map_built=FrontierStellarRoutes.built;spatial_key="";queue_redraw()
func _visible_systems(center: Vector2,extent: float) -> Dictionary:
	var result: Dictionary={0:true,system_index:true,current_system:true}
	var count: int=int(manifest.settings.planet_count)/int(manifest.settings.planets_per_system)
	for i in 200:result[int(i*count/200)]=true
	if compact or zoom<=1.05:return result
	var low:=(-center-Vector2(16,16))/extent
	var high:=(size-center+Vector2(16,16))/extent
	var occupied: Dictionary={}
	var stride:=maxi(1,floori(count/(200.0*pow(zoom,2.5))))
	for y in range(maxi(-32,floori(low.y*32)),mini(31,floori(high.y*32))+1):
		for x in range(maxi(-32,floori(low.x*32)),mini(31,floori(high.x*32))+1):
			for index in map_cells.get(Vector2i(x,y),[]):
				if index%stride!=0:continue
				var point:=center+map_points[index]*extent
				if not Rect2(Vector2.ZERO,size).grow(8).has_point(point):continue
				var pixel_cell:=Vector2i(floori(point.x/14),floori(point.y/14))
				if occupied.has(pixel_cell):continue
				occupied[pixel_cell]=true;result[index]=true
	return result
func reset_view() -> void:
	nearby_only=false;zoom=1.0;pan=Vector2.ZERO;queue_redraw()
var core_view: SubViewport
func _ready() -> void:
	if not compact:
		scene_3d=load("res://scripts/ui/galaxy_scene.gd").new();scene_3d.setup(self)
	visibility_changed.connect(func():
		if core_view!=null:core_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS if galaxy and is_visible_in_tree() else SubViewport.UPDATE_DISABLED
	)
	tooltip_text="외곽: 저티어 · 중심: 고티어 비중 증가\n별을 선택해 항로를 설정하세요. 내부 정보는 방문 후 공개됩니다.\n중앙 블랙홀은 위치 표식입니다."
	custom_minimum_size=Vector2(180,180) if compact else Vector2(280,340)
	clip_contents=true
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
func can_inspect_system(index: int) -> bool:
	return index==current_system or (journal!=null and journal.data.systems.has(str(index)))
func _draw() -> void:
	hits.clear()
	if manifest.is_empty():return
	if scene_3d!=null:
		scene_3d.viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED if not galaxy or not is_visible_in_tree() else scene_3d.viewport.render_target_update_mode
		if galaxy:_draw_spatial();return
	if compact:draw_circle(size*.5,minf(size.x,size.y)*.5,Color("10191fe6"))
	else:draw_style_box(_background(),Rect2(Vector2.ZERO,size))
	var center:=Vector2(size.x/2,size.y/2)+pan
	var extent: float=(minf(size.x,size.y)*.5-24)*zoom
	var font:=get_theme_default_font()
	if core_view!=null:core_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS if galaxy and is_visible_in_tree() else SubViewport.UPDATE_DISABLED
	if galaxy:
		if core_view!=null:draw_texture_rect(core_view.get_texture(),Rect2(center-Vector2(22,22),Vector2(44,44)),false)
		else:draw_circle(center,5,Color("83d9c5"))
		for band in 5:draw_arc(center,extent*(band+1)/5,0,TAU,80,Color("274152"),1,true)
		var count: int=int(manifest.settings.planet_count)/int(manifest.settings.planets_per_system)
		var indices:=_visible_systems(center,extent)
		var favorite_systems: Dictionary={}
		if journal!=null:
			for key in journal.data.systems:indices[int(key)]=true
			for key in journal.data.favorites:
				var favorite_index:=FrontierUniverse.system_index(manifest,FrontierUniverse.ordinal_of(manifest,key))
				indices[favorite_index]=true;favorite_systems[favorite_index]=true
		displayed_systems.clear()
		for index in indices:
			var normalized: Vector2=map_points[index] if index<map_built else FrontierUniverse.map_position(manifest,index)/float(manifest.settings.outer_radius)
			var point:=center+normalized*extent
			if not Rect2(Vector2.ZERO,size).grow(12).has_point(point):continue
			displayed_systems[index]=point
			var band: int=mini(index/(count/manifest.settings.tier_weights.size()),manifest.settings.tier_weights.size()-1)
			draw_circle(point,4 if index==0 else 2.5,Color("72dfd1") if index==0 else [Color("9dcfca"),Color("81b9db"),Color("d9c379"),Color("e49468"),Color("e9778e")][band])
			if journal!=null and journal.data.systems.has(str(index)):draw_arc(point,5,0,TAU,16,Color("94edcf"),1.5,true)
			if favorite_systems.has(index):draw_string(font,point+Vector2(4,-4),"★",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("ffc180"))
			if index==current_system:draw_rect(Rect2(point-Vector2(7,7),Vector2(14,14)),Color.WHITE,false,1)
			if can_inspect_system(index):hits.append({"point":point,"ordinal":FrontierUniverse.showcase_ordinal(manifest,index)})
		if not transit.is_empty():
			var factor: float=extent/float(manifest.settings.outer_radius)
			var source:=center+Vector2(transit.from[0],transit.from[1])*factor
			var destination:=center+Vector2(transit.to[0],transit.to[1])*factor
			var vessel:=center+Vector2(transit.galaxy_position[0],transit.galaxy_position[1])*factor
			draw_line(source,destination,Color(.4,.85,1,.65),2,true)
			draw_circle(vessel,5,Color.WHITE)
		if not compact:draw_string(font,Vector2(12,24),"은하  ·  휠 확대 / 우클릭 끌기",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("e0ebe3"))
	else:
		draw_circle(center,9,Color("ffe2a3"))
		var count: int=FrontierUniverse.body_count(manifest,system_index)
		var station:=FrontierSpaceStation.definition(manifest,system_index,station_excluded)
		if not station.is_empty():
			var factor: float=extent/maxf(FrontierUniverse.orbit_radius(manifest,system_index,count-1)*1.1,ship_position.length() if system_index==current_system else 0.0)
			var point:=center+Vector2(station.position[0],station.position[2])*factor
			draw_rect(Rect2(point-Vector2(5,5),Vector2(10,10)),Color("ffc180"),false,2)
			if not compact:draw_string(font,point+Vector2(9,0),"정거장",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("ffc180"))
			hits.append({"point":point,"station":system_index,"ordinal":-1})
		for i in count:
			var ordinal:=FrontierUniverse.first_ordinal(manifest,system_index)+i
			var body:=FrontierUniverse.body(manifest,ordinal)
			var position:=FrontierUniverse.position(manifest,ordinal,elapsed)
			var factor: float=extent/maxf(FrontierUniverse.orbit_radius(manifest,system_index,count-1)*1.1,ship_position.length() if system_index==current_system else 0.0)
			var point:=center+Vector2(position.x,position.z)*factor
			draw_circle(point,5 if FrontierUniverse.landable(body) else 8,Color("79cfc8") if FrontierUniverse.landable(body) else Color("d2a977"))
			if journal!=null:
				if journal.data.bodies.get(body.id,{}).get("scanned",false):draw_arc(point,10,0,TAU,24,Color("94edcf"),1,true)
				if journal.data.favorites.has(body.id):draw_string(font,point+Vector2(-16,-10),"★",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("ffc180"))
				if journal.data.bodies.get(body.id,{}).get("site","")=="active":draw_rect(Rect2(point-Vector2(8,8),Vector2(16,16)),Color("ffc180"),false,1.5)
			if ordinal==target:draw_arc(point,11,0,TAU,24,Color.WHITE,2,true)
			if ordinal==target and not compact:draw_string(font,point+Vector2(14,-10),body.name,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color.WHITE)
			hits.append({"point":point,"ordinal":ordinal})
		if system_index==current_system:
			var factor: float=extent/maxf(FrontierUniverse.orbit_radius(manifest,system_index,count-1)*1.1,ship_position.length())
			var vessel:=center+Vector2(ship_position.x,ship_position.z)*factor
			var forward:=Vector2(ship_direction.x,ship_direction.z).normalized()
			if forward.length_squared()<.01:forward=Vector2.UP
			var side:=forward.orthogonal()
			draw_colored_polygon(PackedVector2Array([vessel+forward*8,vessel-forward*5+side*5,vessel-forward*3,vessel-forward*5-side*5]),Color.WHITE)
			if absf(ship_position.y)>100:draw_string(font,vessel+Vector2(8,10),"↑" if ship_position.y>0 else "↓",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.WHITE)
		if not compact:draw_string(font,Vector2(12,24),FrontierUniverse.system(manifest,system_index).star.name,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("e0ebe3"))
	if compact:draw_string(font,Vector2(64,size.y-10),"Tab 지도",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("a4b5bd"))
func _background() -> StyleBoxFlat:
	var style:=StyleBoxFlat.new();style.bg_color=Color("0b1d2b");style.set_corner_radius_all(6);return style
func _gui_input(event: InputEvent) -> void:
	if compact:return
	if galaxy and event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_MIDDLE:
		var eye: Vector3=scene_3d.camera.position
		var forward: Vector3=-scene_3d.camera.basis.z
		var pivot: Vector3=eye+forward*(-eye.y/forward.y)
		scene_3d.yaw-=event.relative.x*.005;scene_3d.tilt=clampf(scene_3d.tilt+event.relative.y*.005,.25,1.5)
		scene_3d.update(size,zoom,Vector2.ZERO,nearby_only)
		pan=Vector2(-pivot.dot(scene_3d.camera.basis.x),pivot.dot(scene_3d.camera.basis.y))*size.y/scene_3d.camera.size
		spatial_key="";queue_redraw();accept_event();return
	if event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_RIGHT:
		pan+=event.relative;queue_redraw();accept_event();return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		var previous:=zoom
		zoom=clampf(zoom*(1.25 if event.button_index==MOUSE_BUTTON_WHEEL_UP else .8),.75,160.0)
		pan=event.position-size*.5-(event.position-size*.5-pan)*(zoom/previous)
		queue_redraw();accept_event();return
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:

		var best: Dictionary={};var distance:=16.0
		for hit in hits:
			var separation: float=event.position.distance_to(hit.point)
			if separation<distance:distance=separation;best=hit
		if not best.is_empty():
			if galaxy:
				route_system=FrontierUniverse.system_index(manifest,int(best.ordinal));route_selected.emit(int(best.ordinal));queue_redraw();accept_event();return
			galaxy=false;reset_view()
			if best.has("station"):station_selected.emit(int(best.station))
			else:selected.emit(int(best.ordinal))
			queue_redraw();accept_event()

func _draw_spatial() -> void:
	scene_3d.update(size,zoom,pan,nearby_only)
	draw_texture_rect(scene_3d.viewport.get_texture(),Rect2(Vector2.ZERO,size),false)
	var outer: float=manifest.settings.outer_radius
	var origin:=FrontierUniverse.map_position(manifest,current_system)/outer
	var source: Vector2=scene_3d.project_star(origin)
	var ring:=PackedVector2Array()
	for i in 129:ring.append(scene_3d.project(origin+Vector2.from_angle(float(i)/128*TAU)*stellar_range/outer))
	draw_polyline(ring,Color("67cbb4"),1.5,true)
	if zoom>5:
		for fraction in [.25,.5,.75]:
			var guide_ring:=PackedVector2Array()
			for i in 65:guide_ring.append(scene_3d.project(origin+Vector2.from_angle(float(i)/64*TAU)*stellar_range/outer*fraction))
			draw_polyline(guide_ring,Color("83d9c51c"),1,true)
		for axis in [Vector2.RIGHT,Vector2.UP]:
			draw_line(scene_3d.project(origin-axis*stellar_range/outer),scene_3d.project(origin+axis*stellar_range/outer),Color("83d9c51c"),1,true)
	var indices: Dictionary={0:true,current_system:true}
	if route_system>=0:indices[route_system]=true
	# Screen density sampling is recomputed at every zoom; every cached system can emerge.
	var view_key:=str([manifest.id,size,zoom,pan,map_built,current_system,nearby_only,stellar_range])
	if spatial_key!=view_key:
		spatial_key=view_key;spatial_indices.clear()
		var occupied: Dictionary={}
		var candidates: Array=[]
		if nearby_only:
			for item in FrontierStellarRoutes.nearby(manifest,current_system,stellar_range):candidates.append(item.index)
		else:
			var count:=FrontierStellarRoutes.points.size()
			var stride:=maxi(1,int(float(count)/minf(6000,180*zoom*zoom)))
			for index in range(0,count,stride):
				if FrontierStellarRoutes.has_point(index):candidates.append(index)
		for index in candidates:
			var point: Vector2=scene_3d.project_star(FrontierStellarRoutes.points[index]/outer)
			if not Rect2(Vector2(16,38),size-Vector2(32,68)).has_point(point):continue
			var cell:=Vector2i(point/(32.0 if nearby_only else 22.0))
			if occupied.has(cell):continue
			occupied[cell]=true;spatial_indices[index]=true
	indices.merge(spatial_indices)
	displayed_systems.clear()
	if journal!=null and not nearby_only:
		for key in journal.data.systems:indices[int(key)]=true
	var rendered_stars:=PackedVector2Array()
	for index in indices:
		var coordinate: Vector2=FrontierStellarRoutes.points[index]/outer if FrontierStellarRoutes.has_point(index) else FrontierUniverse.map_position(manifest,index)/outer
		var point: Vector2=scene_3d.project_star(coordinate)
		if not Rect2(Vector2.ZERO,size).grow(-8).has_point(point):continue
		var reachable: bool=coordinate.distance_to(origin)*outer<=stellar_range+.001
		if nearby_only and not reachable:continue
		var color:=Color("b2f4e1") if reachable else Color("647286")
		rendered_stars.append(coordinate)
		# Thin projection stem exposes height without replacing the actual 3D star.
		var plane_point: Vector2=scene_3d.project(coordinate)
		if zoom>5 and point.distance_to(plane_point)>3:
			draw_line(plane_point,point,Color(color,.24),1,true)
			draw_arc(plane_point,2,0,TAU,12,Color(color,.25),1,true)
		if can_inspect_system(index):draw_arc(point,5,0,TAU,16,color,1,true)
		if index==current_system:draw_rect(Rect2(point-Vector2(7,7),Vector2(14,14)),Color.WHITE,false,2)
		if index==route_system:draw_arc(point,9,0,TAU,24,Color("ffc180"),2,true)
		displayed_systems[index]=point;hits.append({"point":point,"ordinal":FrontierUniverse.first_ordinal(manifest,index)})
	scene_3d.set_stars(rendered_stars,origin,stellar_range/outer)
	if route_system>=0:
		var destination: Vector2=scene_3d.project_star(FrontierUniverse.map_position(manifest,route_system)/outer)
		draw_line(source,destination,Color("ffc180"),2,true)
	if not transit.is_empty():
		var from: Vector2=scene_3d.project_star(Vector2(transit.from[0],transit.from[1])/outer)
		var to: Vector2=scene_3d.project_star(Vector2(transit.to[0],transit.to[1])/outer)
		var ship: Vector2=from.lerp(to,float(transit.progress))
		draw_line(from,to,Color("7bebd0"),2,true);draw_circle(ship,6,Color.WHITE)
		var distance:=Vector2(transit.from[0],transit.from[1]).distance_to(Vector2(transit.to[0],transit.to[1]))
		draw_string(get_theme_default_font(),Vector2(18,54),"항해  %.1f / %.1f 항로 단위"%[distance*float(transit.progress),distance],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)
	draw_string(get_theme_default_font(),Vector2(18,26),"은하 항로  ·  항속거리 %.0f"%stellar_range,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("b2f4e1"))
	draw_string(get_theme_default_font(),Vector2(18,size.y-18),"휠 확대 · 우클릭 이동 · 휠 버튼 회전 · 별 선택",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("bccbd8"))

func focus_nearby() -> void:
	galaxy=true;nearby_only=true
	await get_tree().process_frame
	if not is_inside_tree() or manifest.is_empty():return
	scene_3d.yaw=0;scene_3d.tilt=.72
	zoom=clampf(2.55*float(manifest.settings.outer_radius)/(stellar_range*3.0),1.0,160.0)
	pan=Vector2.ZERO;scene_3d.update(size,zoom,pan,true)
	var point: Vector2=scene_3d.project_star(FrontierUniverse.map_position(manifest,current_system)/float(manifest.settings.outer_radius))
	pan=size*.5-point;spatial_key="";queue_redraw()
