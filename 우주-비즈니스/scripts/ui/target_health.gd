class_name FrontierTargetHealth
extends Control
## Aim-only status: no identity, card, caption or pointer input.
var health_ratio:=1.0
var shield_ratio:=0.0
var has_shield:=false
func _init() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	size=Vector2(104,9)
	hide()
func present(health: float,maximum: float,shield:=0.0,shield_max:=0.0) -> void:
	health_ratio=clampf(health/maxf(1,maximum),0,1)
	shield_ratio=clampf(shield/maxf(1,shield_max),0,1)
	has_shield=shield_max>0
	position=get_viewport().get_visible_rect().size*.5+Vector2(-52,32)
	visible=health>0
	queue_redraw()
func _draw() -> void:
	draw_rect(Rect2(0,4,104,5),Color("11191eeb"))
	draw_rect(Rect2(1,5,102*health_ratio,3),Color("e7a987"))
	if has_shield:
		draw_rect(Rect2(0,0,104,3),Color("11191eeb"))
		draw_rect(Rect2(1,1,102*shield_ratio,1),Color("91d9ff"))
