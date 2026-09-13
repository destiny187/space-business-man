extends "res://tests/render_creature_speed_audit.gd"
## Same gameplay speed on both sides; the new gait is allowed to play faster.
func _initialize() -> void:
 folder=ProjectSettings.globalize_path("res://../output/creature-gameplay-speed")
 super._initialize()
