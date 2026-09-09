class_name FrontierItemTile
extends Button
signal item_dropped(item_id: String)
signal cargo_dropped(payload: Dictionary)
var cargo_payload: Dictionary={}
var cargo_destination: String=""
var item_id: String=""
var slot: int=-1
var caption: String=""
var amount: String=""
var grade:=0
var picture: Texture2D
var selected:=false
var unavailable:=false
var compact_slot:=false
func _init() -> void:
	custom_minimum_size=Vector2(88,96);mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	mouse_entered.connect(queue_redraw);mouse_exited.connect(queue_redraw);focus_entered.connect(queue_redraw);focus_exited.connect(queue_redraw)
func _draw() -> void:
	var edge: Color=FrontierInterfaceStyle.ACCENT if selected or has_focus() else FrontierInterfaceStyle.LINE
	var bg: Color=Color("253b40") if is_hovered() else FrontierInterfaceStyle.PANEL
	draw_style_box(FrontierInterfaceStyle.box(bg,edge,0),Rect2(Vector2.ZERO,size))
	if selected:draw_rect(Rect2(0,0,3,size.y),FrontierInterfaceStyle.ACCENT)
	var font:=get_theme_default_font()
	var picture_area:=Rect2(7,5,size.x-14,size.y-28)
	if compact_slot:picture_area=Rect2(5,5,size.x-10,size.y-10)
	var picture_size:=picture_area.size
	if picture!=null:
		var ratio:=minf(picture_size.x/picture.get_width(),picture_size.y/picture.get_height())
		var dims:=picture.get_size()*ratio
		draw_texture_rect(picture,Rect2(picture_area.position+(picture_area.size-dims)*.5,dims),false,Color(1,1,1,.45 if unavailable else 1))
	else:
		draw_line(size*.5-Vector2(7,5),size*.5+Vector2(7,-5),FrontierInterfaceStyle.LINE,1)
		draw_line(size*.5-Vector2(0,12),size*.5+Vector2(0,2),FrontierInterfaceStyle.LINE,1)
	if slot>=0:draw_string(font,Vector2(8,17),str(slot+1),HORIZONTAL_ALIGNMENT_LEFT,-1,12,FrontierInterfaceStyle.ACCENT if selected else FrontierInterfaceStyle.MUTED)
	for i in grade:draw_rect(Rect2(size.x-9-i*6,8,3,8),FrontierInterfaceStyle.WARNING)
	if unavailable:
		var p:=Vector2(size.x-16,size.y-18)
		draw_rect(Rect2(p,Vector2(8,7)),FrontierInterfaceStyle.WARNING,false,1)
		draw_arc(p+Vector2(4,0),3,PI,TAU,12,FrontierInterfaceStyle.WARNING,1,true)
	if not amount.is_empty():
		var width:=font.get_string_size(amount,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
		draw_style_box(FrontierInterfaceStyle.box(FrontierInterfaceStyle.INK,Color.TRANSPARENT,0),Rect2(size.x-width-14,3,width+10,21))
		draw_string(font,Vector2(size.x-width-9,19),amount,HORIZONTAL_ALIGNMENT_LEFT,-1,14,FrontierInterfaceStyle.TEXT)
	if not caption.is_empty() and not compact_slot:
		var label:=caption
		while label.length()>1 and font.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x>size.x-14:label=label.left(label.length()-2)+"…"
		draw_string(font,Vector2(7,size.y-8),label,HORIZONTAL_ALIGNMENT_LEFT,size.x-14,12,FrontierInterfaceStyle.TEXT)
func _get_drag_data(_at: Vector2) -> Variant:
	if (item_id.is_empty() and cargo_payload.is_empty()) or slot>=0:return null
	var image:=TextureRect.new();image.texture=picture;image.custom_minimum_size=Vector2(80,70);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;set_drag_preview(image)
	return cargo_payload if not cargo_payload.is_empty() else {"equipment_item":item_id}
func _can_drop_data(_at: Vector2,data: Variant) -> bool:
	if not cargo_destination.is_empty():return data is Dictionary and data.get("source",cargo_destination)!=cargo_destination and data.has("source")
	return slot>=0 and data is Dictionary and data.get("equipment_item") is String
func _drop_data(_at: Vector2,data: Variant) -> void:
	if not cargo_destination.is_empty():cargo_dropped.emit(data)
	else:item_dropped.emit(data.equipment_item)
