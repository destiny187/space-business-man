class_name FrontierAugmentationSlot
extends FrontierItemTile
signal gem_dropped(resource: String)
func _can_drop_data(_at: Vector2,data: Variant) -> bool:
	return not disabled and data is Dictionary and data.get("augmentation_gem") is String
func _drop_data(_at: Vector2,data: Variant) -> void:gem_dropped.emit(data.augmentation_gem)
