extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(label)
func run() -> void:
	var assets: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/render_assets.json"))
	var ids: Dictionary = {}
	var covered: Array[String] = []
	var cache: Dictionary = {}
	for row in assets:
		check(not ids.has(row.id),"unique render id "+row.id)
		ids[row.id] = true
		covered.append(row.model)
		check(FileAccess.file_exists("res://../"+row.source),"editable original "+row.id)
		check(FileAccess.file_exists("res://../docs/production/media/ink-catalog/"+row.id+".png"),"native review render "+row.id)
		check(ResourceLoader.exists("res://assets/ui/previews/"+row.id+".png"),"game portrait "+row.id)
		var packed := load(row.model) as PackedScene
		check(packed != null,"load "+row.id)
		if packed == null: continue
		var instance := packed.instantiate() as Node3D
		FrontierInkStyle.apply(instance,cache)
		var surfaces := 0
		for mesh in instance.find_children("*","MeshInstance3D",true,false):
			for i in range(mesh.mesh.get_surface_count()):
				var mat: Material = mesh.get_active_material(i)
				var transparent: bool = mat is StandardMaterial3D and mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
				check(transparent or (mat is ShaderMaterial and mat.shader == FrontierInkStyle.CEL),"production surface "+row.id)
				surfaces += 1
		check(surfaces > 0,"nonempty model "+row.id)
		instance.free()
	# Adding a gameplay GLB without a review render must fail the normal test suite.
	for filename in DirAccess.get_files_at("res://assets/models"):
		if filename.ends_with(".glb"):
			check(covered.has("res://assets/models/"+filename),"catalogue covers gameplay asset "+filename)
	for name in ["ground","strata","water","moon"]:
		var shader := FileAccess.get_file_as_string("res://assets/materials/"+name+".gdshader")
		check(shader.contains("ink/cel_light.gdshaderinc"),"environment shares light bands "+name)
	check(FrontierInkStyle.config().mandatory,"ink style is mandatory")
	print("INK_CONTRACT_TESTS checks=%d failures=%d assets=%d" % [checks,failures,assets.size()])
	quit(1 if failures else 0)
