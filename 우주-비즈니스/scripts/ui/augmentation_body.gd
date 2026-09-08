class_name FrontierAugmentationBody
extends Control
signal field_selected(field: String)
var preview: FrontierAugmentationPreview
var buttons: Dictionary={}
var selected: String="mobility"
func _ready() -> void:
	custom_minimum_size=Vector2(320,280);size_flags_horizontal=Control.SIZE_EXPAND_FILL;size_flags_vertical=Control.SIZE_EXPAND_FILL
	preview=FrontierAugmentationPreview.new();add_child(preview);preview.show_behind_parent=true;preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for key in ["vitality","combat","mobility"]:
		var button:=Button.new();button.text={"vitality":"흉부 · 생명","combat":"팔 · 전투","mobility":"다리 · 기동"}[key];button.custom_minimum_size=Vector2(108,38)
		add_child(button);buttons[key]=button;button.pressed.connect(func():field_selected.emit(key))
func _process(_delta: float) -> void:
	if not is_visible_in_tree():return
	var rows: Dictionary={"vitality":.24,"combat":.46,"mobility":.75}
	for key in buttons:
		buttons[key].position=Vector2(8 if key!="combat" else size.x-116,size.y*float(rows[key]))
		buttons[key].add_theme_color_override("font_color",FrontierInterfaceStyle.ACCENT if selected==key else FrontierInterfaceStyle.TEXT)
	queue_redraw()
func _draw() -> void:
	if preview==null:return
	for key in buttons:
		var point:=preview.body_point(key)
		var start: Vector2=buttons[key].position+Vector2(buttons[key].size.x if key!="combat" else 0,buttons[key].size.y*.5)
		var color:=FrontierInterfaceStyle.ACCENT if selected==key else FrontierInterfaceStyle.LINE
		draw_line(start,point,color,1.5,true);draw_arc(point,8 if selected==key else 4,0,TAU,32,color,2,true)
