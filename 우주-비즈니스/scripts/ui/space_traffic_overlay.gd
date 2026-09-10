extends Control
var row: Dictionary={}
var radio_text: String=""
var mark: Texture2D=preload("res://assets/ui/corporations/space_y.svg")
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func _draw() -> void:
	var font:=get_theme_default_font();var cyan:=Color(.53,.91,1)
	if not radio_text.is_empty():draw_string(font,Vector2(24,size.y-142),"Space Y 관제   "+radio_text,HORIZONTAL_ALIGNMENT_LEFT,size.x-48,16,cyan)
	if row.is_empty():return
	var center:=size*.5
	for side in [-1,1]:
		var a:=center+Vector2(side*32,-21);draw_line(a,a+Vector2(side*9,0),cyan,2,true);draw_line(a,a+Vector2(0,42),cyan,2,true);draw_line(a+Vector2(0,42),a+Vector2(side*9,42),cyan,2,true)
	var width:=minf(312,size.x*.36);var origin:=Vector2(minf(center.x+55,size.x-width-18),maxf(30,center.y-168))
	draw_rect(Rect2(origin,Vector2(width,144)),Color(.025,.065,.1,.88))
	draw_line(origin,origin+Vector2(0,144),cyan,2)
	draw_texture_rect(mark,Rect2(origin+Vector2(14,13),Vector2(34,34)),false)
	draw_string(font,origin+Vector2(58,31),row.call_sign,HORIZONTAL_ALIGNMENT_LEFT,width-68,18,Color(.91,.97,1))
	draw_string(font,origin+Vector2(14,66),row.label+"   "+FrontierFlightTelemetry.distance_label(float(row.distance)),HORIZONTAL_ALIGNMENT_LEFT,width-28,16,cyan)
	var destination: String="화성 Y-01" if row.to=="solar_mars_port" else "지구 Y-02"
	draw_string(font,origin+Vector2(14,94),"→ "+destination,HORIZONTAL_ALIGNMENT_LEFT,width-28,15,Color(.75,.86,.91))
	if row.kind=="fighter":
		for side in [-1,1]:
			var p:=origin+Vector2(40+side*17,116);draw_colored_polygon(PackedVector2Array([p+Vector2(0,-8),p+Vector2(9,8),p+Vector2(0,4),p+Vector2(-9,8)]),cyan)
		draw_string(font,origin+Vector2(86,123),"2기 항로 경비",HORIZONTAL_ALIGNMENT_LEFT,width-100,13,Color(.75,.86,.91));return
	for i in 4:
		var p:=origin+Vector2(14+i*16,108);draw_rect(Rect2(p,Vector2(11,16)),Color(.3,.65,.8) if float(row.pods)*4>i else Color(.08,.15,.2));draw_rect(Rect2(p,Vector2(11,16)),cyan,false,1)
	draw_string(font,origin+Vector2(86,123),row.cargo,HORIZONTAL_ALIGNMENT_LEFT,width-100,13,Color(.75,.86,.91))
