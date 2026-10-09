extends SceneTree

const WORLD_SCRIPT = preload("res://scripts/world/chapter_world.gd")
const EXPECTED_LAYER := 1 << 19
var _failures: Array[String] = []
var _checks := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var world = WORLD_SCRIPT.new()
	root.add_child(world)
	_check(world.has_method("_isolate_xray_marks"), "chapter host must isolate authored Xray-only geometry")
	if world.has_method("_isolate_xray_marks"):
		_test_metadata_and_inheritance(world)
		_test_contract_names(world)
		_test_actual_import_extras(world)
		_test_source_exit_guide_contract(world)
		_test_isolation_before_tree_entry(world)
	world.free()
	for failure in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("chapter Xray layer tests passed (%d checks; synthetic metadata and render isolation)" % _checks)
	quit(0 if _failures.is_empty() else 1)


func _test_metadata_and_inheritance(world: Node3D) -> void:
	var asset := Node3D.new()
	asset.name = "SyntheticAsset"
	var group := Node3D.new()
	group.name = "ArrowGroup"
	group.set_meta("xray_only", true)
	asset.add_child(group)
	var direct := _mesh("DirectArrow")
	direct.set_meta("xray_only", true)
	asset.add_child(direct)
	var inherited := _mesh("InheritedArrow")
	inherited.set_meta("xray_only", false)
	group.add_child(inherited)
	var nested_group := Node.new()
	group.add_child(nested_group)
	var nested := MultiMeshInstance3D.new()
	nested.name = "NestedInstances"
	nested.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	nested_group.add_child(nested)
	var extras_group := Node3D.new()
	extras_group.set_meta("gltf_extras", {"xray_only": true})
	asset.add_child(extras_group)
	var extras_child := _mesh("ExtrasArrow")
	extras_group.add_child(extras_child)
	var hidden_mark := _mesh("AlreadyHiddenArrow")
	hidden_mark.set_meta("xray_only", true)
	hidden_mark.visible = false
	asset.add_child(hidden_mark)
	var ordinary := _mesh("OrdinaryProp")
	ordinary.layers = 5
	ordinary.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	ordinary.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	ordinary.set_meta("gltf_extras", {"xray_only": "true"})
	asset.add_child(ordinary)
	world._isolate_xray_marks(asset)
	for geometry: GeometryInstance3D in [direct, inherited, nested, extras_child, hidden_mark]:
		_check_isolated(geometry)
	_check(group.visible and direct.visible and inherited.visible, "isolation never hides a visible marked group or mesh")
	_check(not hidden_mark.visible, "isolation preserves pre-existing hidden state")
	_check(ordinary.layers == 5, "ordinary geometry retains its existing render layers")
	_check(ordinary.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED, "ordinary geometry retains shadow setting")
	_check(ordinary.gi_mode == GeometryInstance3D.GI_MODE_DYNAMIC, "ordinary geometry retains GI setting")
	world._isolate_xray_marks(asset)
	_check_isolated(direct)
	asset.free()


func _test_contract_names(world: Node3D) -> void:
	var asset := Node3D.new()
	var listed_group := Node3D.new()
	listed_group.name = "WallGuideGroup"
	asset.add_child(listed_group)
	var listed_child := _mesh("WallArrow")
	listed_group.add_child(listed_child)
	var similar_name := _mesh("WallGuideGroupDecoration")
	asset.add_child(similar_name)
	world._contract = {"xray_guides": ["WallGuideGroup"]}
	world._isolate_xray_marks(asset)
	_check_isolated(listed_child)
	_check(similar_name.layers == 1, "contract matching is exact and cannot include similarly named props")
	var wrapped := _mesh("WrappedContractArrow")
	asset.add_child(wrapped)
	world._contract = {"xray_guides": {"nodes": ["WrappedContractArrow"]}}
	world._isolate_xray_marks(asset)
	_check_isolated(wrapped)
	asset.free()


func _test_isolation_before_tree_entry(world: Node3D) -> void:
	var asset := Node3D.new()
	var arrow := _mesh("PreRenderArrow")
	arrow.set_meta("gltf_extras", {"xray_only": true})
	asset.add_child(arrow)
	var observed := {"layers": 0, "shadow": -1, "gi": -1}
	arrow.tree_entered.connect(func():
		observed.layers = arrow.layers
		observed.shadow = arrow.cast_shadow
		observed.gi = arrow.gi_mode
	)
	# Deliberately stop binding at marker validation: this checks the production
	# asset attachment path without building any stage, audio or lighting.
	var configured: bool = world.configure_stage({"phase": "basement"}, {}, asset, {"anchors": {"MissingRequiredMarker": {}}})
	_check(not configured and not world.diagnostics.is_empty(), "fixture stops at expected missing-anchor validation")
	_check(observed.layers == EXPECTED_LAYER, "production binding isolates layers before asset tree entry")
	_check(observed.shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "production binding disables shadows before asset tree entry")
	_check(observed.gi == GeometryInstance3D.GI_MODE_DISABLED, "production binding disables GI before asset tree entry")


func _test_actual_import_extras(world: Node3D) -> void:
	var asset := Node3D.new()
	var imported_group := Node3D.new()
	imported_group.name = "ActualImportedGuide"
	imported_group.set_meta("extras", {"xray_only": true})
	asset.add_child(imported_group)
	var inherited := _mesh("ActualImportedGuidePaint")
	imported_group.add_child(inherited)
	var directly_marked := _mesh("ActualImportedDirectMark")
	directly_marked.set_meta("extras", {"xray_only": true})
	asset.add_child(directly_marked)
	var ordinary := _mesh("ImportedOrdinaryProp")
	ordinary.set_meta("extras", {"xray_only": "true"})
	asset.add_child(ordinary)
	world._contract = {}
	world._isolate_xray_marks(asset)
	_check_isolated(inherited)
	_check_isolated(directly_marked)
	_check(ordinary.layers == 1, "actual import extras require a boolean true flag")
	_check(imported_group.visible and directly_marked.visible, "actual import metadata never changes visibility")
	asset.free()


func _test_source_exit_guide_contract(world: Node3D) -> void:
	var asset := Node3D.new()
	var listed_root := Node3D.new()
	listed_root.name = "XRAY_EXIT_GUIDE_01"
	asset.add_child(listed_root)
	var root_child := _mesh("AuthoredPaintChild")
	listed_root.add_child(root_child)
	var listed_mesh := _mesh("XRAY_EXIT_GUIDE_02_Paint")
	asset.add_child(listed_mesh)
	var similar := _mesh("XRAY_EXIT_GUIDE_02_PaintExtra")
	asset.add_child(similar)
	world._contract = {"xray_exit_guides": {
		"count": 3, "max_count": 3, "property": "xray_only", "normal_view_visible": false,
		"marks": [
			{"root": "XRAY_EXIT_GUIDE_01", "mesh": "XRAY_EXIT_GUIDE_01_Paint"},
			{"root": "XRAY_EXIT_GUIDE_02", "mesh": "XRAY_EXIT_GUIDE_02_Paint"},
			{"root": "XRAY_EXIT_GUIDE_03", "mesh": "XRAY_EXIT_GUIDE_03_Paint"},
		],
	}}
	world._isolate_xray_marks(asset)
	_check_isolated(root_child)
	_check_isolated(listed_mesh)
	_check(similar.layers == 1, "source contract fallback matches exact root or mesh names only")
	_check(listed_root.visible and listed_mesh.visible, "normal_view_visible false selects layers without globally hiding guides")
	asset.free()


func _mesh(node_name: String) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	mesh.mesh = BoxMesh.new()
	mesh.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	return mesh


func _check_isolated(geometry: GeometryInstance3D) -> void:
	_check(geometry.layers == EXPECTED_LAYER, "%s uses only Xray layer 20" % geometry.name)
	_check(geometry.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%s cannot cast into the ordinary world" % geometry.name)
	_check(geometry.gi_mode == GeometryInstance3D.GI_MODE_DISABLED, "%s cannot contribute to GI" % geometry.name)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
