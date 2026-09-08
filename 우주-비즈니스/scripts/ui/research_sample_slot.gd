class_name FrontierResearchSampleSlot
extends FrontierItemTile
signal specimen_dropped(resource: String)
func _can_drop_data(_at: Vector2,data: Variant) -> bool:
	return not disabled and data is Dictionary and data.get("research_sample") is String
func _drop_data(_at: Vector2,data: Variant) -> void:specimen_dropped.emit(data.research_sample)
