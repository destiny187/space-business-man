extends Control
signal selected(ordinal: int)
var manifest: Dictionary={}
var system_index:=0
var elapsed:=0.0
var galaxy:=false
var target:=0
var hits: Array=[]
func _ready() -> void:
	custom_minimum_size=Vector2(265,240)
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
func _draw() -> void:
	if manifest.is_empty():return
	hits.clear()
	draw_style_box(_background(),Rect2(Vector2.ZERO,size))
	var center:=Vector2(size.x/2,size.y/2)
	var font:=get_theme_default_font()
	if galaxy:
		for band in 5:draw_arc(center,22+band*21,0,TAU,80,Color("274152"),1,true)
		var count: int=int(manifest.settings.planet_count)/int(manifest.settings.planets_per_system)
		for i in 201:
			var index: int=0 if i==0 else int((i-1)*count/200)
			var sys:=FrontierUniverse.system(manifest,index)
			var point:=center+Vector2(sys.map_position[0],sys.map_position[1])/float(manifest.settings.outer_radius)*105
			draw_circle(point,4 if index==0 else 2.5,Color("72dfd1") if index==0 else Color("c4a678"))
			hits.append({"point":point,"ordinal":index*int(manifest.settings.planets_per_system)})
		draw_string(font,Vector2(8,20),"은하 · 별을 눌러 항성계 탐색",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("e0ebe3"))
	else:
		draw_circle(center,9,Color("ffe2a3"))
		var count: int=manifest.settings.planets_per_system
		for i in count:
			var ordinal:=system_index*count+i
			var body:=FrontierUniverse.body(manifest,ordinal)
			var position:=FrontierUniverse.position(manifest,ordinal,elapsed)
			var radial:=Vector2(position.x,position.z).normalized()
			var radius:=25.0+i*11.5
			draw_arc(center,radius,0,TAU,80,Color("355568"),1,true)
			var point:=center+radial*radius
			draw_circle(point,5 if FrontierUniverse.landable(body) else 8,Color("79cfc8") if FrontierUniverse.landable(body) else Color("d2a977"))
			if ordinal==target:draw_arc(point,11,0,TAU,24,Color.WHITE,2,true)
			draw_string(font,point+Vector2(7,-7),str(i+1),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.WHITE)
			hits.append({"point":point,"ordinal":ordinal})
		draw_string(font,Vector2(8,20),"항성계 · 천체를 눌러 선택",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("e0ebe3"))
func _background() -> StyleBoxFlat:
	var style:=StyleBoxFlat.new();style.bg_color=Color("0b1d2b");style.set_corner_radius_all(6);return style
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		var best: Dictionary={};var distance:=16.0
		for hit in hits:
			var separation: float=event.position.distance_to(hit.point)
			if separation<distance:distance=separation;best=hit
		if not best.is_empty():selected.emit(int(best.ordinal));galaxy=false;queue_redraw();accept_event()
