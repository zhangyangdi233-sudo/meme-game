extends SceneTree
## The game's social feed source reads the configured run, locale and language material,
## and loads each texture once.

const GameSocialFeedSourceScript = preload("res://scripts/game/game_social_feed_source.gd")
const GameLocaleScript = preload("res://scripts/localization/game_locale.gd")
const LanguageMaterialScript = preload("res://scripts/game/language_material.gd")
const MemeGameStateScript = preload("res://scripts/meme_game_state.gd")
const PropertyBootScript = preload("res://scripts/game/property_boot.gd")
const RegistryScript = preload("res://framework/service_registry.gd")

var _failures: Array[String] = []


func _init() -> void:
	RegistryScript.clear()
	PropertyBootScript.install()
	_test_it_follows_the_configured_run()
	_test_it_hands_out_the_configured_material()
	_test_it_loads_a_texture_once()
	_test_the_discover_channel_lists_posts()
	RegistryScript.clear()
	if _failures.is_empty():
		print("game social feed source tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_it_follows_the_configured_run() -> void:
	var source := GameSocialFeedSourceScript.new()
	var first: MemeGameState = MemeGameStateScript.new()
	first.day = 2
	first.pollution = 30
	source.configure(first, GameLocaleScript.new(), null)
	_assert_eq(source.game_day(), 2, "the source should read the configured run's day")
	_assert_eq(source.pollution(), 30, "the source should read the configured run's pollution")
	var second: MemeGameState = MemeGameStateScript.new()
	second.day = 5
	source.configure(second, GameLocaleScript.new(), null)
	_assert_eq(source.game_day(), 5, "reconfiguring should follow the new run")


func _test_it_hands_out_the_configured_material() -> void:
	var source := GameSocialFeedSourceScript.new()
	var material: LanguageMaterial = LanguageMaterialScript.new()
	source.configure(MemeGameStateScript.new(), GameLocaleScript.new(), material)
	_assert_true(source.language_material() == material, "the source should hand out the configured material")


func _test_it_loads_a_texture_once() -> void:
	var source := GameSocialFeedSourceScript.new()
	_assert_true(source.load_texture("res://does/not/exist.png") == null, "a missing texture should load as null")
	var first := source.load_texture(GameSocialFeedSourceScript.NO_SIGNAL_ICON_PATH)
	_assert_true(first != null, "the no-signal icon should load")
	_assert_true(source.load_texture(GameSocialFeedSourceScript.NO_SIGNAL_ICON_PATH) == first, "a loaded texture should be reused")


func _test_the_discover_channel_lists_posts() -> void:
	var source := GameSocialFeedSourceScript.new()
	source.configure(MemeGameStateScript.new(), GameLocaleScript.new(), null)
	_assert_true(not source.channels().is_empty(), "the source should list the catalog's channels")
	_assert_true(not source.visible_post_indices([], "discover").is_empty(), "the discover channel should list posts")


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, expected, actual])


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
