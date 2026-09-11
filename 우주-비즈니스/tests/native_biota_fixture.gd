extends RefCounted
static func prepare() -> void:
	FrontierEcologyCatalog.prepare()
	for row in JSON.parse_string(FileAccess.get_file_as_string("res://data/bestiary/biota_recipes.json")).species:
		FrontierEcologyCatalog._forms[row.id]=row
		var id: String=row.id+"_p00_s00"
		FrontierEcologyCatalog._looks[row.id]={id:{"id":id,"form_id":row.id,"scale":1.0}}
	# Only finished representative models are eligible for this provisional UI run.
	for row in JSON.parse_string(FileAccess.get_file_as_string("res://data/bestiary/biota_preview_forms.json")).forms:FrontierEcologyCatalog._forms[row.id]=row
	for row in JSON.parse_string(FileAccess.get_file_as_string("res://data/bestiary/biota_preview_appearances.json")).appearances:FrontierEcologyCatalog._looks[row.form_id][row.id]=row
	FrontierEcologyCatalog._biota_signature="recipe-fixture-not-full-art-validation"
