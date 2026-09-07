class_name FrontierCursorPolicy
extends RefCounted
## Mouse capture is global; visible interface windows always take priority.
static func modal_open(tree: SceneTree) -> bool:
	for popup in tree.root.find_children("*","Window",true,false):
		if popup.visible:return true
	return false
static func release() -> void:
	if Input.mouse_mode!=Input.MOUSE_MODE_VISIBLE:Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
