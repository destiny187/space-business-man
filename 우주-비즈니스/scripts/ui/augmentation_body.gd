class_name FrontierAugmentationBody
extends Control
signal field_selected(field: String)
# The authored scanner still drives the actual station's tray/gem/scan motion.
# Its offscreen render is disabled while the illustrated ability card is shown.
var preview: FrontierAugmentationPreview
var artwork: TextureRect
var buttons: Dictionary={}
var selected: String="mobility"
var shown: String=""
var last_phase: String=""
var textures: Dictionary={}
var pulse:=0.0
func _ready() -> void:
	custom_minimum_size=Vector2(292,185);size_flags_horizontal=Control.SIZE_EXPAND_FILL
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	preview=FrontierAugmentationPreview.new();preview.artwork_mode=true;add_child(preview)
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	artwork=TextureRect.new();artwork.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;artwork.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(artwork);artwork.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);artwork.offset_bottom=-6
	for key in ["mobility","combat","vitality"]:textures[key]=load("res://assets/ui/augmentation/"+key+".png")
func _process(delta: float) -> void:
	if not is_visible_in_tree():return
	if shown!=selected:
		shown=selected;artwork.texture=textures[selected]
		artwork.modulate.a=.45;create_tween().tween_property(artwork,"modulate:a",1.0,.16);queue_redraw()
	if last_phase!=preview.phase:last_phase=preview.phase;pulse=0;queue_redraw()
	if last_phase in ["waiting","success"]:pulse+=delta;queue_redraw()
func _draw() -> void:
	var accent: Color={"mobility":Color("82c9ee"),"combat":Color("efb46f"),"vitality":Color("83d9b8")}[selected]
	if last_phase=="error":accent=FrontierInterfaceStyle.DANGER
	var bar:=Rect2(Vector2(0,size.y-3),Vector2(size.x,3))
	draw_style_box(FrontierInterfaceStyle.box(FrontierInterfaceStyle.INK,FrontierInterfaceStyle.LINE,6),Rect2(Vector2.ZERO,size))
	draw_rect(bar,FrontierInterfaceStyle.LINE)
	var fraction:=.3 if last_phase not in ["prepared","waiting","success"] else (1.0 if last_phase!="waiting" else .25+.75*fmod(pulse*.55,1.0))
	draw_rect(Rect2(bar.position,Vector2(bar.size.x*fraction,3)),accent)
