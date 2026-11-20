extends SceneTree
## A full-screen VHS overlay added under a sized parent covers that parent, filter included. Its lens bows the picture
## only while the host says the pointer is captured, easing in and out.

const VhsOverlayScript = preload("res://framework/ui/vhs_overlay.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_deferred")


func _run_deferred() -> void:
	await process_frame
	await _test_overlay_covers_its_sized_parent()
	await _test_the_lens_bows_only_while_the_host_says_so()
	if _failures.is_empty():
		print("vhs overlay tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_overlay_covers_its_sized_parent() -> void:
	var parent := Control.new()
	parent.position = Vector2.ZERO
	parent.size = Vector2(1600, 900)
	root.add_child(parent)
	var overlay: Control = VhsOverlayScript.new()
	parent.add_child(overlay)
	await process_frame
	_assert_eq(overlay.size, parent.size, "the overlay should cover its parent")
	var filter := overlay.get_node_or_null("VHSDynamicFilter") as Control
	_assert_true(filter != null, "the overlay should build its shader filter")
	if filter != null:
		_assert_eq(filter.size, parent.size, "the shader filter should cover the parent too")
	parent.size = Vector2(960, 720)
	await process_frame
	_assert_eq(overlay.size, Vector2(960, 720), "the overlay should follow its parent's size")
	parent.free()


func _test_the_lens_bows_only_while_the_host_says_so() -> void:
	var parent := Control.new()
	parent.size = Vector2(1600, 900)
	root.add_child(parent)
	var overlay: VhsOverlay = VhsOverlayScript.new()
	parent.add_child(overlay)
	await process_frame
	var material := (overlay.get_node("VHSDynamicFilter") as ColorRect).material as ShaderMaterial
	_assert_eq(material.get_shader_parameter("lens_bow"), 0.0, "a new overlay should not bow the picture under a free pointer")
	overlay.set_lens_bowed(true)
	overlay._process(overlay.LENS_BOW_SECONDS * 0.5)
	_assert_true(is_equal_approx(float(material.get_shader_parameter("lens_bow")), 0.5), "the bow should ease in: %s" % str(material.get_shader_parameter("lens_bow")))
	overlay._process(1.0)
	_assert_eq(material.get_shader_parameter("lens_bow"), 1.0, "a captured pointer should bow the picture fully")
	overlay.set_lens_bowed(false)
	overlay._process(1.0)
	_assert_eq(material.get_shader_parameter("lens_bow"), 0.0, "a freed pointer should flatten the picture again")
	_assert_true(material.shader.code.contains("lens_bow"), "the filter should read the bow the overlay sets")
	parent.free()


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
