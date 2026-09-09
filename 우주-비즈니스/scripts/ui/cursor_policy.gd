class_name FrontierCursorPolicy
extends RefCounted
## Mouse capture is global; visible interface windows always take priority.
static var _tree: WeakRef
static var _windows: Dictionary={}

static func modal_open(tree: SceneTree) -> bool:
	if _tree==null or _tree.get_ref()!=tree:
		_watch(tree)
	# Read visibility immediately: a dialog opened/closed during an input event
	# must take effect in that same event, not on the next rendered frame.
	for reference: WeakRef in _windows.values():
		var popup:=reference.get_ref() as Window
		if popup!=null and popup.visible:return true
	return false

static func _watch(tree: SceneTree) -> void:
	if _tree!=null and _tree.get_ref()!=null:
		var previous: SceneTree=_tree.get_ref()
		previous.node_added.disconnect(_added)
		previous.node_removed.disconnect(_removed)
	_tree=weakref(tree);_windows.clear()
	tree.node_added.connect(_added)
	tree.node_removed.connect(_removed)
	# One inventory per SceneTree. Subsequent scene changes use its signals.
	for popup in tree.root.find_children("*","Window",true,false):_added(popup)

static func _added(node: Node) -> void:
	if node is Window:_windows[node.get_instance_id()]=weakref(node)

static func _removed(node: Node) -> void:
	if node is Window:_windows.erase(node.get_instance_id())

static func release() -> void:
	if Input.mouse_mode!=Input.MOUSE_MODE_VISIBLE:Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
