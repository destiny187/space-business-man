extends Control
signal selected(ordinal: int)
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
func _process(_delta: float) -> void:
	if compact or not galaxy or not is_visible_in_tree() or manifest.is_empty():return
	var key:=FrontierStellarRoutes.key
	if key.is_empty():return
	if key!=map_key:
		map_key=key;map_built=0;map_cells.clear();map_points.resize(FrontierStellarRoutes.points.size())
	var previous:=map_built
	var deadline:=Time.get_ticks_usec()+1500
	while map_built<FrontierStellarRoutes.built and Time.get_ticks_usec()<deadline:
		var index:=FrontierStellarRoutes.insertion_order[map_built]
		var point:=FrontierStellarRoutes.points[index]/float(manifest.settings.outer_radius)
		map_points[index]=point
		var cell:=Vector2i(floori(point.x*32),floori(point.y*32))
		if not map_cells.has(cell):map_cells[cell]=[]
		map_cells[cell].append(index);map_built+=1
	if map_built!=previous:queue_redraw()
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
	zoom=1.0;pan=Vector2.ZERO;queue_redraw()
var core_view: SubViewport
func _ready() -> void:
	if not compact:core_view=FrontierGalacticCore.preview(self,128,true)
	visibility_changed.connect(func():
		if core_view!=null:core_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS if galaxy and is_visible_in_tree() else SubViewport.UPDATE_DISABLED
	)
	tooltip_text="외곽: 저티어 · 중심: 고티어 비중 증가\n방문한 항성계만 선택할 수 있습니다.\n중앙 블랙홀은 위치 표식입니다."
	custom_minimum_size=Vector2(180,180) if compact else Vector2(280,340)
	clip_contents=true
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
func can_inspect_system(index: int) -> bool:
	return index==current_system or (journal!=null and journal.data.systems.has(str(index)))
func _draw() -> void:
	hits.clear()
	if manifest.is_empty():return
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
	if event is InputEventMouseMotion and event.button_mask&MOUSE_BUTTON_MASK_RIGHT:
		pan+=event.relative;queue_redraw();accept_event();return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		var previous:=zoom
		zoom=clampf(zoom*(1.25 if event.button_index==MOUSE_BUTTON_WHEEL_UP else .8),.75,24.0)
		pan=event.position-size*.5-(event.position-size*.5-pan)*(zoom/previous)
		queue_redraw();accept_event();return
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		if galaxy and event.position.distance_to(size*.5+pan)<22:accept_event();return
		var best: Dictionary={};var distance:=16.0
		for hit in hits:
			var separation: float=event.position.distance_to(hit.point)
			if separation<distance:distance=separation;best=hit
		if not best.is_empty():galaxy=false;reset_view();selected.emit(int(best.ordinal));queue_redraw();accept_event()
