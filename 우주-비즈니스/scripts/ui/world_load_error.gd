class_name FrontierWorldLoadError
extends RefCounted
static func show_error(owner_node: Node,reason: String) -> void:
	owner_node.set_process(false);owner_node.set_physics_process(false);owner_node.set_process_unhandled_input(false)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var layer:=CanvasLayer.new();owner_node.add_child(layer)
	var panel:=PanelContainer.new();panel.position=Vector2(40,40);panel.custom_minimum_size=Vector2(720,220);layer.add_child(panel)
	var theme:=Theme.new();theme.default_font=load("res://assets/fonts/NotoSansKR.ttf");theme.default_font_size=18;panel.theme=theme
	var column:=VBoxContainer.new();panel.add_child(column)
	var label:=Label.new();label.text="탐험 저장을 열 수 없습니다. 원본과 백업은 보존했습니다.\n"+reason+"\n새 세계로 덮어쓰지 않았습니다.";label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(label)
	var button:=Button.new();button.text="시작 화면으로";column.add_child(button)
	button.pressed.connect(func():owner_node.get_tree().change_scene_to_file("res://scenes/app/main.tscn"))
