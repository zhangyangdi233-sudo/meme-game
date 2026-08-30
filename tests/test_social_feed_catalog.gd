extends SceneTree

const CatalogScript = preload("res://scripts/game/social_feed_catalog.gd")

var _failures: Array[String] = []


func _init() -> void:
	test_catalog_loads_and_validates()
	test_expected_content_counts()
	test_day_plan_lookup()
	test_defensive_copies()
	if _failures.is_empty():
		print("social feed catalog tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func test_catalog_loads_and_validates() -> void:
	var validation: Dictionary = CatalogScript.validate()
	_assert_true(bool(validation.get("ok", false)), "catalog should validate: %s" % str(validation.get("problems", [])))


func test_expected_content_counts() -> void:
	_assert_eq(CatalogScript.get_channels().size(), 2, "catalog should expose two social channels")
	_assert_eq(CatalogScript.get_post_cards().size(), 12, "catalog should expose twelve post cards")
	_assert_eq(CatalogScript.get_day_plans().size(), 6, "catalog should expose six day plans")
	var first_post: Dictionary = CatalogScript.get_post_cards()[0]
	_assert_eq(str(first_post.get("id", "")), "floor_13", "first post card id should remain stable")
	var first_plan: Dictionary = CatalogScript.get_day_plans()[0]
	_assert_eq(str(first_plan.get("title", "")), "旧帖被顶上来", "first day plan title should remain stable")


func test_day_plan_lookup() -> void:
	var day_one: Dictionary = CatalogScript.day_plan_for_day(1)
	_assert_eq(str(day_one.get("speaker", "")), "同学", "day 1 should resolve to the first authored plan")
	var overflow: Dictionary = CatalogScript.day_plan_for_day(99)
	_assert_eq(str(overflow.get("title", "")), "没有人在顶上", "days beyond the catalog should clamp to the final plan")


func test_defensive_copies() -> void:
	var channels_a: Array = CatalogScript.get_channels()
	var channels_b: Array = CatalogScript.get_channels()
	channels_a[0]["label"] = "mutated"
	_assert_ne(str((channels_b[0] as Dictionary).get("label", "")), "mutated", "channel arrays should return defensive copies")


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])


func _assert_ne(actual: Variant, expected: Variant, message: String) -> void:
	if actual == expected:
		_failures.append("%s (expected value different from %s)" % [message, str(expected)])
