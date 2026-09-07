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
var core_view: SubViewport
func _ready() -> void:
	core_view=FrontierGalacticCore.preview(self,128,true)
	visibility_changed.connect(func():
		if core_view!=null:core_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS if galaxy and is_visible_in_tree() else SubViewport.UPDATE_DISABLED
	)
	tooltip_text="외곽: 저티어 · 중심: 고티어 비중 증가\n중앙 블랙홀은 항해 기준점입니다."
	custom_minimum_size=Vector2(265,240)
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
func _draw() -> void:
	if manifest.is_empty():return
	hits.clear()
	draw_style_box(_background(),Rect2(Vector2.ZERO,size))
	var center:=Vector2(size.x/2,size.y/2)
	var font:=get_theme_default_font()
	if core_view!=null:core_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS if galaxy and is_visible_in_tree() else SubViewport.UPDATE_DISABLED
	if galaxy:
		draw_texture_rect(core_view.get_texture(),Rect2(center-Vector2(22,22),Vector2(44,44)),false)
		for band in 5:draw_arc(center,22+band*21,0,TAU,80,Color("274152"),1,true)
		var count: int=int(manifest.settings.planet_count)/int(manifest.settings.planets_per_system)
		var indices: Dictionary={0:true,system_index:true,current_system:true}
		var favorite_systems: Dictionary={}
		for i in 200:indices[int(i*count/200)]=true
		if journal!=null:
			for key in journal.data.systems:indices[int(key)]=true
			for key in journal.data.favorites:
				var favorite_index:=FrontierUniverse.system_index(manifest,FrontierUniverse.ordinal_of(manifest,key))
				indices[favorite_index]=true;favorite_systems[favorite_index]=true
		for index in indices:
			var sys:=FrontierUniverse.system(manifest,index)
			var point:=center+Vector2(sys.map_position[0],sys.map_position[1])/float(manifest.settings.outer_radius)*105
			draw_circle(point,4 if index==0 else 2.5,Color("72dfd1") if index==0 else [Color("9dcfca"),Color("81b9db"),Color("d9c379"),Color("e49468"),Color("e9778e")][int(sys.band)])
			if journal!=null and journal.data.systems.has(str(index)):draw_arc(point,5,0,TAU,16,Color("94edcf"),1.5,true)
			if favorite_systems.has(index):draw_string(font,point+Vector2(4,-4),"★",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("ffc180"))
			if index==current_system:draw_rect(Rect2(point-Vector2(7,7),Vector2(14,14)),Color.WHITE,false,1)
			hits.append({"point":point,"ordinal":FrontierUniverse.showcase_ordinal(manifest,index)})
		if not transit.is_empty():
			var factor: float=105/float(manifest.settings.outer_radius)
			var source:=center+Vector2(transit.from[0],transit.from[1])*factor
			var destination:=center+Vector2(transit.to[0],transit.to[1])*factor
			var vessel:=center+Vector2(transit.galaxy_position[0],transit.galaxy_position[1])*factor
			draw_line(source,destination,Color(.4,.85,1,.65),2,true)
			draw_circle(vessel,5,Color.WHITE)
		draw_string(font,Vector2(8,20),"은하 · 외곽 저티어 → 중심 고티어",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("e0ebe3"))
	else:
		draw_circle(center,9,Color("ffe2a3"))
		var count: int=FrontierUniverse.body_count(manifest,system_index)
		for i in count:
			var ordinal:=FrontierUniverse.first_ordinal(manifest,system_index)+i
			var body:=FrontierUniverse.body(manifest,ordinal)
			var position:=FrontierUniverse.position(manifest,ordinal,elapsed)
			var radial:=Vector2(position.x,position.z).normalized()
			var radius:=20.0+float(body.orbit.radius)/FrontierUniverse.orbit_radius(manifest,system_index,count-1)*95.0
			var point:=center+radial*radius
			draw_circle(point,5 if FrontierUniverse.landable(body) else 8,Color("79cfc8") if FrontierUniverse.landable(body) else Color("d2a977"))
			if journal!=null:
				if journal.data.bodies.get(body.id,{}).get("scanned",false):draw_arc(point,10,0,TAU,24,Color("94edcf"),1,true)
				if journal.data.favorites.has(body.id):draw_string(font,point+Vector2(-16,-10),"★",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("ffc180"))
				if journal.data.bodies.get(body.id,{}).get("site","")=="active":draw_rect(Rect2(point-Vector2(8,8),Vector2(16,16)),Color("ffc180"),false,1.5)
			if ordinal==target:draw_arc(point,11,0,TAU,24,Color.WHITE,2,true)
			draw_string(font,point+Vector2(7,-7),str(i+1),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.WHITE)
			hits.append({"point":point,"ordinal":ordinal})
		draw_string(font,Vector2(8,20),FrontierUniverse.system(manifest,system_index).star.name,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("e0ebe3"))
func _background() -> StyleBoxFlat:
	var style:=StyleBoxFlat.new();style.bg_color=Color("0b1d2b");style.set_corner_radius_all(6);return style
func _show_core() -> void:
	var popup:=Window.new();popup.title="은하 중심 · 중앙 블랙홀";popup.size=Vector2i(900,700);popup.exclusive=true;add_child(popup)
	var background:=ColorRect.new();background.color=Color("02040a");background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);popup.add_child(background)
	var view:=FrontierGalacticCore.preview(popup,1024)
	var picture:=TextureRect.new();picture.texture=view.get_texture();picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);popup.add_child(picture)
	var caption:=Label.new();caption.text="은하 중심 · 고티어 성역\n강착 원반과 극축 제트 · 탐험의 이정표";caption.position=Vector2(24,24);caption.add_theme_font_size_override("font_size",23);popup.add_child(caption)
	popup.close_requested.connect(popup.queue_free);popup.popup_centered()
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		if galaxy and event.position.distance_to(size*.5)<22:_show_core();accept_event();return
		var best: Dictionary={};var distance:=16.0
		for hit in hits:
			var separation: float=event.position.distance_to(hit.point)
			if separation<distance:distance=separation;best=hit
		if not best.is_empty():selected.emit(int(best.ordinal));galaxy=false;queue_redraw();accept_event()
