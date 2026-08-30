extends SceneTree

const ContentJsonScript = preload("res://framework/content_json.gd")

var _failures: Array[String] = []


func _init() -> void:
	test_reads_existing_catalog_files()
	test_cached_reads_return_same_reference()
	test_duplicate_array_copies_nested_dictionaries()
	test_missing_file_returns_empty_dictionary()
	if _failures.is_empty():
		print("content json tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func test_reads_existing_catalog_files() -> void:
	var social: Dictionary = ContentJsonScript.read_dictionary("res://content/social_feed_catalog.json", "test")
	_assert_true(not social.is_empty(), "social feed catalog should load as a dictionary")
	_assert_true(social.has("post_cards"), "social feed catalog should expose post_cards")

	var seeds: Dictionary = ContentJsonScript.read_dictionary("res://content/pickup_post_seeds.json", "test")
	_assert_true(not seeds.is_empty(), "pickup post seeds should load as a dictionary")
	_assert_true(seeds.has("floor_13"), "pickup post seeds should include floor_13")


func test_cached_reads_return_same_reference() -> void:
	ContentJsonScript.clear_cache()
	var first: Dictionary = ContentJsonScript.load_dictionary_cached("res://content/pickup_post_seeds.json", "test")
	var second: Dictionary = ContentJsonScript.load_dictionary_cached("res://content/pickup_post_seeds.json", "test")
	_assert_true(first == second, "cached dictionary loads should reuse the same in-memory catalog")


func test_duplicate_array_copies_nested_dictionaries() -> void:
	var source: Array = [{"id": "a"}]
	var copy_a: Array = ContentJsonScript.duplicate_array(source)
	var copy_b: Array = ContentJsonScript.duplicate_array(source)
	copy_a[0]["id"] = "mutated"
	_assert_eq_text(str((copy_b[0] as Dictionary).get("id", "")), "a", "duplicate_array should deep-copy dictionary entries")


func test_missing_file_returns_empty_dictionary() -> void:
	var missing: Dictionary = ContentJsonScript.read_dictionary("res://content/does_not_exist.json", "test")
	_assert_true(missing.is_empty(), "missing content files should return an empty dictionary")


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq_text(value: String, expected: String, message: String) -> void:
	if value != expected:
		_failures.append("%s (got %s, expected %s)" % [message, value, expected])
