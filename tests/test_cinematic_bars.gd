extends SceneTree
## Letterbox bars: aspect-derived height, 12% cap, named ColorRects, viewport size passed in.

const BarsScript = preload("res://framework/ui/cinematic_bars.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_async")


func _run_async() -> void:
	await _run()
	if _failures.is_empty():
		print("cinematic bars tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	var host := Control.new()
	host.size = Vector2(1600, 900)
	root.add_child(host)
	var bars = BarsScript.new()
	host.add_child(bars)
	bars.configure(2.35, 0.12)
	bars.relayout(Vector2(1600, 900))
	await process_frame

	# 1600x900 at 2.35: picture 1600/2.35≈680.85, half-gap≈109.57, cap 900*0.12=108.
	_assert_true(is_equal_approx(bars.bar_height(Vector2(1600, 900)), 108.0), "1600x900 should cap at 12 percent (108px)")
	# Wider than target with short height: 2000x400 picture≈851 > 400 → height 0.
	_assert_true(is_equal_approx(bars.bar_height(Vector2(2000, 400)), 0.0), "a viewport already shorter than the picture should get no bars")
	_assert_true(is_equal_approx(bars.bar_height(Vector2(2.35 * 400.0, 400.0)), 0.0), "a viewport that matches 2.35 should get no bars")
	# Square 900x900: half-gap≈258.5, cap 108.
	_assert_true(is_equal_approx(bars.bar_height(Vector2(900, 900)), 108.0), "a taller viewport should still cap at 12 percent")

	var top := bars.get_node_or_null("CinematicTopBar") as ColorRect
	var bottom := bars.get_node_or_null("CinematicBottomBar") as ColorRect
	_assert_true(top != null and bottom != null, "the overlay should own named top and bottom ColorRects")
	if top != null and bottom != null:
		_assert_true(is_equal_approx(top.offset_bottom, 108.0), "top bar offset_bottom should match the computed height")
		_assert_true(is_equal_approx(bottom.offset_top, -108.0), "bottom bar offset_top should match the computed height")
		_assert_true(top.z_index == 8 and bottom.z_index == 8, "bars should keep the overlay z-index")
		bars.set_bars_visible(false)
		_assert_true(not top.visible and not bottom.visible, "set_bars_visible should hide both ColorRects")
		bars.set_bars_visible(true)
		_assert_true(top.visible and bottom.visible, "set_bars_visible should show both ColorRects")

	host.queue_free()
	await process_frame


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
