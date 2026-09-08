class_name FrontierCargoDropArea
extends ScrollContainer
signal cargo_dropped(payload: Dictionary)
var destination: String=""
func _can_drop_data(_position: Vector2,data: Variant) -> bool:
	return data is Dictionary and data.has("source") and data.source!=destination
func _drop_data(_position: Vector2,data: Variant) -> void:
	cargo_dropped.emit(data)
