class_name FrontierUIScale
extends RefCounted
## Scale readable controls without shrinking the usable viewport or 3D rendering.
static func apply_later(node: Control,factor: float) -> void:
	apply_id.call_deferred(node.get_instance_id(),factor)
static func apply_id(id: int,factor: float) -> void:
	var node:=instance_from_id(id) as Control
	if node==null or not node.is_inside_tree():return
	if node is Label or node is BaseButton or node is LineEdit or node is RichTextLabel or node is TabContainer:
		var font_key: String="normal_font_size" if node is RichTextLabel else "font_size"
		if not node.has_meta("ui_base_font"):node.set_meta("ui_base_font",node.get_theme_font_size(font_key))
		node.add_theme_font_size_override(font_key,roundi(float(node.get_meta("ui_base_font"))*factor))
		if node is Button or node is LineEdit:
			if not node.has_meta("ui_base_height"):node.set_meta("ui_base_height",node.custom_minimum_size.y)
			node.custom_minimum_size.y=maxf(float(node.get_meta("ui_base_height")),28.0*factor)
static func apply_tree(tree: SceneTree,factor: float) -> void:_walk(tree.root,factor)
static func _walk(node: Node,factor: float) -> void:
	if node is Control:apply_id(node.get_instance_id(),factor)
	for child in node.get_children():_walk(child,factor)
