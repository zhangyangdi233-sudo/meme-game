extends SceneTree
## Module contracts; main/Journey own pickup persistence and global key routing.

var checks := 0
var failures: Array[String] = []
var closed_count := 0

func _init() -> void:
	root.visible = false
	_run.call_deferred()

func _run() -> void:
	var world_path := "res://scripts/world/floor_two_note.gd"
	var view_path := "res://scripts/ui/floor_two_note_view.gd"
	_check(ResourceLoader.exists(world_path) and ResourceLoader.exists(view_path), "world paper and inspect view modules exist")
	if not failures.is_empty():
		_finish()
		return
	var note = load(world_path).new()
	root.add_child(note)
	_check(note is Area3D and note.get_meta("actor_type", "") == "floor2_note" and note.get_meta("actor_id", "") == "floor2_note", "note is the dedicated interaction actor")
	_check(note.find_children("*", "StaticBody3D", true, false).is_empty(), "paper cannot obstruct the player's capsule")
	_check(note.find_children("*", "Light3D", true, false).is_empty(), "world note adds no light")
	var mesh: MeshInstance3D = note.get_node("PaperMesh")
	var material: StandardMaterial3D = mesh.material_override
	_check(not material.emission_enabled and material.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL, "paper is lit by the world, never self illuminating")
	_check(material.albedo_texture != null, "world paper includes the same handwritten content texture")
	var view = load(view_path).new()
	root.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	view.closed.connect(func(): closed_count += 1)
	_check(not view.active and not view.visible, "inspect starts closed")
	var original_mode := Input.mouse_mode
	for locale in ["zh", "en", "ja"]:
		view.open(locale)
		_check(view.active and view.visible, "inspect opens in " + locale)
		var paper = view.get_node("NotePaper")
		_check(paper.ORIGINAL_TEXT == "墙不再是墙，路不再是路", "Chinese original is preserved in " + locale)
		for character in paper.ORIGINAL_TEXT:
			_check(paper.HANDWRITING.has_char(character.unicode_at(0)), "handwriting font supplies " + character)
		var translation: Label = view.get_node("NoteTranslation")
		_check(translation.visible == (locale != "zh"), "only non-Chinese locales add a secondary translation")
		for dimensions in [Vector2(800, 600), Vector2(1280, 720), Vector2(1920, 1080)]:
			view.size = dimensions
			view.layout_contents()
			_check(Rect2(Vector2.ZERO, dimensions).encloses(paper.get_rect()), "paper fits viewport " + str(dimensions))
			_check(paper.handwriting_font_size() >= 36, "red handwritten text remains readable at " + str(dimensions))
			_check(paper.handwriting_fits(), "both original lines fit the sheet at " + str(dimensions))
		view.close()
		var once := closed_count
		view.close()
		_check(closed_count == once and not view.active, "repeat close cannot duplicate the read event")
	_check(closed_count == 3, "each completed read emits exactly once")
	view.open("en")
	view.cancel()
	_check(closed_count == 3 and not view.active and not view.visible, "scene cleanup does not mark an unread paper read")
	_check(Input.mouse_mode == original_mode, "inspect UI never changes global mouse capture")
	view.free()
	note.free()
	await process_frame
	_finish()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _finish() -> void:
	for message in failures:
		push_error(message)
	if failures.is_empty():
		print("floor two note passed (%d checks)" % checks)
	quit(0 if failures.is_empty() else 1)
