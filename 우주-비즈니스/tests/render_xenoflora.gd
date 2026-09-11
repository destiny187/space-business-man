extends "res://tests/render_xenofauna.gd"
func _initialize() -> void:
	destination="res://../docs/production/media/xenoflora/"
	catalogue="res://data/bestiary/xenoflora_forms.json"
	collection_title="XENOFLORA"
	run.call_deferred()
