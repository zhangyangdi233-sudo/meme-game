extends SceneTree
## The social intent handler takes the social feed's intents off an empty bus, changes the state and the language
## material, writes its feedback line, and returns what the host should present. No main scene is opened.

const Harness = preload("res://tests/harness/minimal_game_harness.gd")
const ActionOutcomeScript = preload("res://scripts/game/action_outcome.gd")
const BootScript = preload("res://scripts/game/property_boot.gd")
const GameEventBusScript = preload("res://scripts/ui/game_event_bus.gd")
const GameSocialFeedSourceScript = preload("res://scripts/game/game_social_feed_source.gd")
const IntentResultScript = preload("res://scripts/game/intent_result.gd")
const LanguageMaterialScript = preload("res://scripts/game/language_material.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const RegistryScript = preload("res://framework/service_registry.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const SocialIntentHandlerScript = preload("res://scripts/game/social_intent_handler.gd")
const UiIntentsScript = preload("res://scripts/ui_intents.gd")

var _failures: Array[String] = []
var _game: MemeGameState
var _handler: SocialIntentHandler
var _results: Array = []


func _init() -> void:
	_test_it_claims_every_social_intent_and_nothing_else()
	_test_page_changes_ask_the_host_to_re_theme()
	_test_a_card_counts_the_opened_post_for_the_tutorial()
	_test_like_and_follow_write_the_state_and_the_feedback()
	_test_closing_the_window_and_the_detail()
	_test_pickup_and_composer_intents_build_and_post_a_sentence()
	RegistryScript.clear()
	if _failures.is_empty():
		print("social intent handler tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


## A clean registry, the models, an empty bus and a stand-in host that routes the social intents to the handler.
func _boot() -> void:
	RegistryScript.clear()
	BootScript.install()
	_game = Harness.new_state()
	var material := LanguageMaterialScript.new()
	material.configure(_game, null)
	var source := GameSocialFeedSourceScript.new()
	source.configure(_game, null, material)
	_handler = SocialIntentHandlerScript.new()
	_handler.configure(_game, material, source)
	var bus := GameEventBusScript.new()
	RegistryScript.bind(ServiceKeysScript.UI_EVENT_BUS, bus)
	_results.clear()
	bus.intent_emitted.connect(func(intent_name: String, payload: Dictionary) -> void:
		if _handler.handles(intent_name):
			_results.append(_handler.handle(intent_name, payload)))


func _raise(intent_name: String, payload: Dictionary = {}) -> IntentResult:
	var heard := _results.size()
	GameEventBus.raise(intent_name, payload)
	_assert_eq(_results.size(), heard + 1, "the handler should answer %s once" % intent_name)
	return _results.back() if _results.size() > heard else null


func _feedback() -> String:
	var manager := RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	return str((manager.model(PropertyKeysScript.FEEDBACK_TEXT) as ValuePropertyModel).read())


func _test_it_claims_every_social_intent_and_nothing_else() -> void:
	_boot()
	for intent_name in [
		UiIntentsScript.SOCIAL_CHANNEL_PRESSED,
		UiIntentsScript.SOCIAL_SCREEN_REQUESTED,
		UiIntentsScript.SOCIAL_CARD_CLICKED,
		UiIntentsScript.SOCIAL_LIKE_PRESSED,
		UiIntentsScript.SOCIAL_FOLLOW_PRESSED,
		UiIntentsScript.SOCIAL_CLOSE_REQUESTED,
		UiIntentsScript.SOCIAL_DETAIL_CLOSE_REQUESTED,
		UiIntentsScript.SOCIAL_PICKUP_UNIT_CLICKED,
		UiIntentsScript.SOCIAL_COMPOSER_AREA_DROPPED,
		UiIntentsScript.SOCIAL_COMPOSER_TILE_DROPPED,
		UiIntentsScript.SOCIAL_COMPOSER_ANSWER_TAPPED,
		UiIntentsScript.SOCIAL_COMPOSER_SUBMIT_REQUESTED,
	]:
		_assert_true(_handler.handles(intent_name), "the handler should claim %s" % intent_name)
	for intent_name in [
		UiIntentsScript.START_GAME,
		UiIntentsScript.APP_WINDOW_CLOSE_REQUESTED,
		UiIntentsScript.NOTEBOOK_CRAFT_REQUESTED,
	]:
		_assert_true(not _handler.handles(intent_name), "the handler should leave %s to the host" % intent_name)


func _test_page_changes_ask_the_host_to_re_theme() -> void:
	_boot()
	var channel := _raise(UiIntentsScript.SOCIAL_CHANNEL_PRESSED, {UiIntentsScript.KEY_CHANNEL: "following"})
	_assert_presents(channel, SocialIntentHandlerScript.PAGE_CHANGED, "a channel tab")
	var screen := _raise(UiIntentsScript.SOCIAL_SCREEN_REQUESTED, {UiIntentsScript.KEY_SCREEN: "profile"})
	_assert_presents(screen, SocialIntentHandlerScript.PAGE_CHANGED, "a nav button")


func _test_a_card_counts_the_opened_post_for_the_tutorial() -> void:
	_boot()
	_game.tutorial_progress = {"current_step_id": "open_post", "completed_step_ids": ["find_guide", "open_social"]}
	var result := _raise(UiIntentsScript.SOCIAL_CARD_CLICKED, {UiIntentsScript.KEY_POST_INDEX: 2})
	_assert_presents(result, SocialIntentHandlerScript.PAGE_CHANGED, "a card")
	_assert_eq(str(_game.tutorial_progress.get("current_step_id", "")), "collect_words", "opening a post should finish the tutorial step")


func _test_like_and_follow_write_the_state_and_the_feedback() -> void:
	_boot()
	var like := _raise(UiIntentsScript.SOCIAL_LIKE_PRESSED, {UiIntentsScript.KEY_POST_ID: "floor_13"})
	_assert_true(_game.is_social_post_liked("floor_13"), "a like intent should like the post")
	_assert_eq(_feedback(), "已保存这条信号。", "a like should word its feedback")
	_assert_presents(like, IntentResultScript.NONE, "a like")
	_raise(UiIntentsScript.SOCIAL_LIKE_PRESSED, {UiIntentsScript.KEY_POST_ID: "floor_13"})
	_assert_true(not _game.is_social_post_liked("floor_13"), "a second like intent should unlike it")
	_assert_eq(_feedback(), "已取消保存。", "an unlike should word its feedback")
	var follow := _raise(UiIntentsScript.SOCIAL_FOLLOW_PRESSED, {UiIntentsScript.KEY_AUTHOR_ID: "floor_13"})
	_assert_true(_game.is_social_following("floor_13"), "a follow intent should follow the author")
	_assert_true(_feedback().begins_with("已关注 @") and _feedback() != "已关注 @floor_13。", "a follow should name the author's handle")
	_assert_presents(follow, IntentResultScript.NONE, "a follow")
	_raise(UiIntentsScript.SOCIAL_FOLLOW_PRESSED, {UiIntentsScript.KEY_AUTHOR_ID: "floor_13"})
	_assert_true(_feedback().begins_with("已取消关注 @"), "an unfollow should word its feedback")


func _test_closing_the_window_and_the_detail() -> void:
	_boot()
	_game.open_app_window("social")
	var close := _raise(UiIntentsScript.SOCIAL_CLOSE_REQUESTED)
	_assert_true(not _game.is_app_window_open("social"), "a close intent should close the social window")
	_assert_eq(_feedback(), "关闭 social 窗口。", "closing should word its feedback")
	_assert_presents(close, SocialIntentHandlerScript.WINDOW_CLOSED, "a close")
	var detail := _raise(UiIntentsScript.SOCIAL_DETAIL_CLOSE_REQUESTED)
	_assert_eq(_feedback(), "关闭社交详情。", "closing the detail should word its feedback")
	_assert_presents(detail, SocialIntentHandlerScript.PAGE_CHANGED, "a detail close")


func _test_pickup_and_composer_intents_build_and_post_a_sentence() -> void:
	_boot()
	var pickup := _raise(UiIntentsScript.SOCIAL_PICKUP_UNIT_CLICKED, {UiIntentsScript.KEY_META: "门", UiIntentsScript.KEY_POST_ID: "floor_13"})
	_assert_true(_game.is_social_char_collected("门", "zh"), "a pickup intent should collect the word")
	_assert_presents(pickup, SocialIntentHandlerScript.PICKUP, "a pickup")
	if pickup != null:
		_assert_eq(pickup.unit, "门", "a pickup should name the picked word for its flight")
		_assert_true(pickup.outcome != null and pickup.outcome.succeeded, "a pickup should carry its outcome")
	_raise(UiIntentsScript.SOCIAL_PICKUP_UNIT_CLICKED, {UiIntentsScript.KEY_META: "开", UiIntentsScript.KEY_POST_ID: "floor_13"})
	var area := _raise(UiIntentsScript.SOCIAL_COMPOSER_AREA_DROPPED, {UiIntentsScript.KEY_DATA: {"kind": "composer_unit", "id": "门"}})
	_assert_eq(_game.get_free_sentence_text("zh"), "门", "an area drop intent should place the dragged word")
	_assert_presents(area, IntentResultScript.NONE, "an area drop")
	var tile := _raise(UiIntentsScript.SOCIAL_COMPOSER_TILE_DROPPED, {UiIntentsScript.KEY_DATA: {"kind": "composer_unit", "id": "开"}, UiIntentsScript.KEY_BEFORE_INDEX: 0})
	_assert_eq(_game.get_free_sentence_text("zh"), "开门", "a tile drop intent should place the word before the tile")
	_assert_presents(tile, IntentResultScript.NONE, "a tile drop")
	var tap := _raise(UiIntentsScript.SOCIAL_COMPOSER_ANSWER_TAPPED, {UiIntentsScript.KEY_UNIT_INDEX: 0})
	_assert_eq(_game.get_free_sentence_text("zh"), "门", "an answer tap intent should remove that tile")
	_assert_presents(tap, IntentResultScript.NONE, "an answer tap")
	var submit := _raise(UiIntentsScript.SOCIAL_COMPOSER_SUBMIT_REQUESTED)
	_assert_true(_game.get_free_sentence_units().is_empty(), "a submit intent should post the sentence")
	_assert_presents(submit, IntentResultScript.SUBMIT, "a submit")
	if submit != null:
		_assert_true(submit.outcome != null and submit.outcome.succeeded, "a submit should carry its outcome")


func _assert_presents(result: IntentResult, presentation: String, label: String) -> void:
	_assert_true(result != null, "%s should return a result" % label)
	if result != null:
		_assert_eq(result.presentation, presentation, "%s should ask the host for the right presentation" % label)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
