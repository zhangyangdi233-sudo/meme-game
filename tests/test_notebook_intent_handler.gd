extends SceneTree
## The notebook intent handler takes the notebook's intents off an empty bus, changes the state and the language
## material, writes its feedback line, and returns what the host should present. No main scene is opened.

const Harness = preload("res://tests/harness/minimal_game_harness.gd")
const ActionOutcomeScript = preload("res://scripts/game/action_outcome.gd")
const BootScript = preload("res://scripts/game/property_boot.gd")
const GameEventBusScript = preload("res://scripts/ui/game_event_bus.gd")
const GameLocaleScript = preload("res://scripts/localization/game_locale.gd")
const IntentResultScript = preload("res://scripts/game/intent_result.gd")
const LanguageMaterialScript = preload("res://scripts/game/language_material.gd")
const NotebookIntentHandlerScript = preload("res://scripts/game/notebook_intent_handler.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const RegistryScript = preload("res://framework/service_registry.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const UiIntentsScript = preload("res://scripts/ui_intents.gd")

var _failures: Array[String] = []
var _game: MemeGameState
var _handler: NotebookIntentHandler
var _answer_panel: Control
var _results: Array = []


func _init() -> void:
	call_deferred("_run_async")


func _run_async() -> void:
	_test_it_claims_every_notebook_intent_and_nothing_else()
	_test_a_tab_change_asks_the_host_to_re_theme()
	_test_bank_taps_place_the_word_and_ask_for_its_flight()
	_test_a_tile_dropped_on_the_answer_joins_the_sentence()
	await _test_a_tile_dropped_off_the_answer_stays_out()
	_test_craft_returns_the_submit_outcome()
	_test_committed_positions_are_written_to_the_state()
	_test_fusion_slots_take_the_selected_meme_and_word_the_refusals()
	_test_fusion_returns_the_action_and_selects_the_fused_meme()
	if _answer_panel != null:
		_answer_panel.queue_free()
	RegistryScript.clear()
	if _failures.is_empty():
		print("notebook intent handler tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


## A clean registry, the models, an empty bus and a stand-in host that routes the notebook intents to the handler.
func _boot() -> void:
	RegistryScript.clear()
	BootScript.install()
	_game = Harness.new_state()
	var locale := GameLocaleScript.new()
	locale.set_locale("zh")
	var material := LanguageMaterialScript.new()
	material.configure(_game, locale)
	_handler = NotebookIntentHandlerScript.new()
	_handler.configure(_game, material, locale, func() -> Control: return _answer_panel)
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


func _model(property_name: String) -> ValuePropertyModel:
	var manager := RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	return manager.model(property_name) as ValuePropertyModel


func _feedback() -> String:
	return str(_model(PropertyKeysScript.FEEDBACK_TEXT).read())


func _test_it_claims_every_notebook_intent_and_nothing_else() -> void:
	_boot()
	for intent_name in [
		UiIntentsScript.NOTEBOOK_CRAFT_REQUESTED,
		UiIntentsScript.NOTEBOOK_FUSION_REQUESTED,
		UiIntentsScript.NOTEBOOK_TAB_CHANGED,
		UiIntentsScript.NOTEBOOK_CANVAS_POSITIONS_COMMITTED,
		UiIntentsScript.NOTEBOOK_CANVAS_TILE_DROPPED_OUTSIDE,
		UiIntentsScript.NOTEBOOK_COMPOSER_BANK_TAPPED,
		UiIntentsScript.NOTEBOOK_FUSION_MEME_DROPPED,
		UiIntentsScript.NOTEBOOK_FUSION_SLOT_PRESSED,
	]:
		_assert_true(_handler.handles(intent_name), "the handler should claim %s" % intent_name)
	for intent_name in [
		UiIntentsScript.START_GAME,
		UiIntentsScript.SOCIAL_COMPOSER_SUBMIT_REQUESTED,
		UiIntentsScript.COMPOSER_CONFIRM_PRESSED,
		UiIntentsScript.SETTINGS_PRESSED,
	]:
		_assert_true(not _handler.handles(intent_name), "the handler should leave %s to the host" % intent_name)


func _test_a_tab_change_asks_the_host_to_re_theme() -> void:
	_boot()
	var result := _raise(UiIntentsScript.NOTEBOOK_TAB_CHANGED, {UiIntentsScript.KEY_TAB_ID: "fusion"})
	_assert_presents(result, NotebookIntentHandlerScript.TAB_CHANGED, "a tab change")


func _test_bank_taps_place_the_word_and_ask_for_its_flight() -> void:
	_boot()
	_game.pick_social_char("floor_13", "门", "zh")
	_game.pick_social_char("floor_13", "开", "zh")
	var first := _raise(UiIntentsScript.NOTEBOOK_COMPOSER_BANK_TAPPED, {UiIntentsScript.KEY_UNIT: "门"})
	_raise(UiIntentsScript.NOTEBOOK_COMPOSER_BANK_TAPPED, {UiIntentsScript.KEY_UNIT: "开"})
	_assert_eq(_game.get_free_sentence_text("zh"), "门开", "bank tap intents should build the sentence in order")
	_assert_presents(first, NotebookIntentHandlerScript.PLACE, "a bank tap")
	if first != null:
		_assert_eq(first.unit, "门", "a bank tap should name the word for its flight")
		_assert_eq(first.value, true, "a bank tap should say the word was placed")
	var unknown := _raise(UiIntentsScript.NOTEBOOK_COMPOSER_BANK_TAPPED, {UiIntentsScript.KEY_UNIT: "无"})
	if unknown != null:
		_assert_eq(unknown.value, false, "a word not held should not be placed")


func _test_a_tile_dropped_on_the_answer_joins_the_sentence() -> void:
	_boot()
	_game.pick_social_char("floor_13", "门", "zh")
	_answer_panel = Control.new()
	_answer_panel.position = Vector2(100.0, 100.0)
	_answer_panel.size = Vector2(200.0, 80.0)
	root.add_child(_answer_panel)
	var result := _raise(UiIntentsScript.NOTEBOOK_CANVAS_TILE_DROPPED_OUTSIDE, {UiIntentsScript.KEY_UNIT: "门", UiIntentsScript.KEY_RELEASE_GLOBAL: Vector2(150.0, 120.0)})
	_assert_eq(_game.get_free_sentence_text("zh"), "门", "a tile released over the answer should join the sentence")
	_assert_eq(_feedback(), LanguageMaterialScript.PLACED_LINE, "a placed tile should word its feedback")
	_assert_presents(result, IntentResultScript.NONE, "a tile drop")


func _test_a_tile_dropped_off_the_answer_stays_out() -> void:
	_boot()
	_game.pick_social_char("floor_13", "门", "zh")
	_raise(UiIntentsScript.NOTEBOOK_CANVAS_TILE_DROPPED_OUTSIDE, {UiIntentsScript.KEY_UNIT: "门", UiIntentsScript.KEY_RELEASE_GLOBAL: Vector2(10.0, 10.0)})
	_assert_true(_game.get_free_sentence_units().is_empty(), "a tile released off the answer should stay out")
	_answer_panel.queue_free()
	_answer_panel = null
	await process_frame
	_raise(UiIntentsScript.NOTEBOOK_CANVAS_TILE_DROPPED_OUTSIDE, {UiIntentsScript.KEY_UNIT: "门", UiIntentsScript.KEY_RELEASE_GLOBAL: Vector2(150.0, 120.0)})
	_assert_true(_game.get_free_sentence_units().is_empty(), "with no answer panel a released tile should stay out")


func _test_craft_returns_the_submit_outcome() -> void:
	_boot()
	_game.pick_social_char("floor_13", "门", "zh")
	_raise(UiIntentsScript.NOTEBOOK_COMPOSER_BANK_TAPPED, {UiIntentsScript.KEY_UNIT: "门"})
	var result := _raise(UiIntentsScript.NOTEBOOK_CRAFT_REQUESTED)
	_assert_true(_game.get_free_sentence_units().is_empty(), "a craft intent should post the sentence")
	_assert_presents(result, IntentResultScript.SUBMIT, "a craft")
	if result != null:
		_assert_true(result.outcome != null and result.outcome.succeeded, "a craft should carry its outcome")


func _test_committed_positions_are_written_to_the_state() -> void:
	_boot()
	var result := _raise(UiIntentsScript.NOTEBOOK_CANVAS_POSITIONS_COMMITTED, {UiIntentsScript.KEY_TILE_POSITIONS: {"门": Vector2(42.0, 24.0)}})
	_assert_eq(_game.get_char_canvas_position("门", "zh"), Vector2(42.0, 24.0), "a commit intent should write the resting position")
	_assert_presents(result, IntentResultScript.NONE, "a position commit")


func _two_memes() -> void:
	_game.completed_memes = [
		{"id": "meme-left", "title": "左梗", "text": "左", "tags": [], "rarity": 1, "pollution_bias": 1, "fusion_level": 0, "unit_count": 1},
		{"id": "meme-right", "title": "右梗", "text": "右", "tags": [], "rarity": 1, "pollution_bias": 1, "fusion_level": 0, "unit_count": 1},
	]
	_game.fusion_slots = {}


func _test_fusion_slots_take_the_selected_meme_and_word_the_refusals() -> void:
	_boot()
	_two_memes()
	var empty_press := _raise(UiIntentsScript.NOTEBOOK_FUSION_SLOT_PRESSED, {UiIntentsScript.KEY_SLOT_ID: "left"})
	_assert_eq(_feedback(), "先从融合列表选择一个完整梗。", "a slot press with no selected meme should ask for one")
	_assert_presents(empty_press, NotebookIntentHandlerScript.FUSION_SLOTS_CHANGED, "a slot press")
	var drop := _raise(UiIntentsScript.NOTEBOOK_FUSION_MEME_DROPPED, {UiIntentsScript.KEY_DATA: {"kind": "meme", "id": "meme-left"}, UiIntentsScript.KEY_SLOT_ID: "left"})
	_assert_eq(str(_game.fusion_slots.get("left", "")), "meme-left", "a drop intent should put the meme in the slot")
	_assert_eq(str(_model(PropertyKeysScript.SELECTED_MEME).read()), "meme-left", "a drop should select the dropped meme")
	_assert_eq(_feedback(), "旧梗已放入融合槽。", "a drop should word its feedback")
	_assert_presents(drop, NotebookIntentHandlerScript.FUSION_SLOTS_CHANGED, "a meme drop")
	_raise(UiIntentsScript.NOTEBOOK_FUSION_SLOT_PRESSED, {UiIntentsScript.KEY_SLOT_ID: "right"})
	_assert_true(not _game.fusion_slots.has("right"), "a slot press should refuse the meme already in the other slot")
	_assert_eq(_feedback(), "两个融合槽不能使用同一个梗。", "a refused slot press should say why")
	_raise(UiIntentsScript.NOTEBOOK_FUSION_MEME_DROPPED, {UiIntentsScript.KEY_DATA: {"kind": "meme", "id": "meme-left"}, UiIntentsScript.KEY_SLOT_ID: "right"})
	_assert_eq(_feedback(), "两个融合槽必须放入不同的完整梗。", "a refused drop should say why")
	_model(PropertyKeysScript.SELECTED_MEME).write("meme-right")
	_raise(UiIntentsScript.NOTEBOOK_FUSION_SLOT_PRESSED, {UiIntentsScript.KEY_SLOT_ID: "right"})
	_assert_eq(str(_game.fusion_slots.get("right", "")), "meme-right", "a slot press should place the selected meme")


func _test_fusion_returns_the_action_and_selects_the_fused_meme() -> void:
	_boot()
	_two_memes()
	_game.place_meme_in_fusion_slot("left", "meme-left")
	_game.place_meme_in_fusion_slot("right", "meme-right")
	var result := _raise(UiIntentsScript.NOTEBOOK_FUSION_REQUESTED)
	_assert_eq(_game.completed_memes.size(), 3, "a fusion intent should fuse the two memes")
	_assert_presents(result, IntentResultScript.ACTION, "a fusion")
	if result != null and result.outcome != null:
		_assert_true(result.outcome.succeeded, "a fusion should carry its outcome")
		_assert_eq(str(_model(PropertyKeysScript.SELECTED_MEME).read()), result.outcome.selected_meme_id, "a fusion should select the fused meme")
	_model(PropertyKeysScript.SELECTED_MEME).write("meme-left")
	var refused := _raise(UiIntentsScript.NOTEBOOK_FUSION_REQUESTED)
	if refused != null and refused.outcome != null:
		_assert_true(not refused.outcome.succeeded, "fusing empty slots should fail")
	_assert_eq(str(_model(PropertyKeysScript.SELECTED_MEME).read()), "meme-left", "a failed fusion should keep the selection")


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
