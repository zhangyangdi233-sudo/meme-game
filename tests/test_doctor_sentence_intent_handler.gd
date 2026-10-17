extends SceneTree
## The doctor sentence intent handler takes the composer's token, drop, slot and confirm intents off an empty bus,
## keeps the selected token model, writes its feedback line, and returns what the host should present.
## No main scene is opened.

const Harness = preload("res://tests/harness/minimal_game_harness.gd")
const ActionOutcomeScript = preload("res://scripts/game/action_outcome.gd")
const BootScript = preload("res://scripts/game/property_boot.gd")
const DoctorSentenceIntentHandlerScript = preload("res://scripts/game/doctor_sentence_intent_handler.gd")
const GameEventBusScript = preload("res://scripts/ui/game_event_bus.gd")
const IntentResultScript = preload("res://scripts/game/intent_result.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const RegistryScript = preload("res://framework/service_registry.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const UiIntentsScript = preload("res://scripts/ui_intents.gd")

var _failures: Array[String] = []
var _game: MemeGameState
var _handler: DoctorSentenceIntentHandler
var _results: Array = []


func _init() -> void:
	_test_it_claims_every_composer_intent_and_nothing_else()
	_test_a_slot_press_with_no_token_asks_for_one()
	_test_a_token_press_selects_the_token()
	_test_slots_and_drops_place_the_token_or_word_the_refusal()
	_test_a_drop_with_no_token_changes_nothing()
	_test_a_refused_confirm_keeps_the_selection()
	_test_a_confirmed_sentence_clears_the_selection()
	RegistryScript.clear()
	if _failures.is_empty():
		print("doctor sentence intent handler tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


## A clean registry, the models, an empty bus and a stand-in host that routes the composer intents to the handler.
func _boot() -> void:
	RegistryScript.clear()
	BootScript.install()
	_game = Harness.new_state()
	_handler = DoctorSentenceIntentHandlerScript.new()
	_handler.configure(_game)
	var bus := GameEventBusScript.new()
	RegistryScript.bind(ServiceKeysScript.UI_EVENT_BUS, bus)
	_results.clear()
	bus.intent_emitted.connect(func(intent_name: String, payload: Dictionary) -> void:
		if _handler.handles(intent_name):
			_results.append(_handler.handle(intent_name, payload)))


## The doctor's conversation open in composing, with three tokens the phone has already published.
func _speaking() -> void:
	var tokens := [
		_token("subject-1", "我", "speaker.self", ["subject"], "本账号", "患者", "你"),
		_token("action-1", "看见", "perceive.see", ["action"], "捕获", "报告", "记得"),
		_token("object-1", "塔", "place.tower", ["object"], "信号塔", "病区", "出口"),
	]
	for token: Dictionary in tokens:
		token["used_worlds"] = ["phone"]
	_game.notebook_tokens = tokens
	_game.start_typed_reality_conversation("doctor_floor1", "doctor", "医生")


func _token(token_id: String, text: String, lexeme_id: String, roles: Array, phone_surface: String, doctor_surface: String, doll_surface: String) -> Dictionary:
	return {
		"id": token_id,
		"text": text,
		"lexeme_id": lexeme_id,
		"grammar_roles": roles,
		"phone_surface": phone_surface,
		"doctor_surface": doctor_surface,
		"doll_surface": doll_surface,
		"tags": ["test"],
		"rarity": 1,
		"pollution_stage": 0,
		"used_worlds": [],
	}


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


func _selected_token() -> String:
	return str(_model(PropertyKeysScript.SELECTED_LANGUAGE_TOKEN).read())


func _test_it_claims_every_composer_intent_and_nothing_else() -> void:
	_boot()
	for intent_name in [
		UiIntentsScript.COMPOSER_TOKEN_PRESSED,
		UiIntentsScript.COMPOSER_TOKEN_DROPPED,
		UiIntentsScript.COMPOSER_SLOT_PRESSED,
		UiIntentsScript.COMPOSER_CONFIRM_PRESSED,
	]:
		_assert_true(_handler.handles(intent_name), "the handler should claim %s" % intent_name)
	for intent_name in [
		UiIntentsScript.CONVERSATION_CHOICE_PRESSED,
		UiIntentsScript.CONVERSATION_CONTINUE_PRESSED,
		UiIntentsScript.NOTEBOOK_CRAFT_REQUESTED,
		UiIntentsScript.SOCIAL_COMPOSER_SUBMIT_REQUESTED,
	]:
		_assert_true(not _handler.handles(intent_name), "the handler should leave %s to the host" % intent_name)


func _test_a_slot_press_with_no_token_asks_for_one() -> void:
	_boot()
	var result := _raise(UiIntentsScript.COMPOSER_SLOT_PRESSED, {UiIntentsScript.KEY_SLOT_ID: "subject"})
	_assert_eq(_feedback(), "先选择一个词。", "a slot press with no selected token should ask for one")
	_assert_presents(result, DoctorSentenceIntentHandlerScript.COMPOSER_CHANGED, "a slot press")


func _test_a_token_press_selects_the_token() -> void:
	_boot()
	var result := _raise(UiIntentsScript.COMPOSER_TOKEN_PRESSED, {UiIntentsScript.KEY_TOKEN_ID: "ghost"})
	_assert_eq(_selected_token(), "ghost", "a token press should remember the token")
	_assert_eq(_feedback(), "选中了一个带到医生面前的词。", "a token press should word its feedback")
	_assert_presents(result, DoctorSentenceIntentHandlerScript.COMPOSER_CHANGED, "a token press")


func _test_slots_and_drops_place_the_token_or_word_the_refusal() -> void:
	_boot()
	_speaking()
	_raise(UiIntentsScript.COMPOSER_TOKEN_PRESSED, {UiIntentsScript.KEY_TOKEN_ID: "ghost"})
	_raise(UiIntentsScript.COMPOSER_SLOT_PRESSED, {UiIntentsScript.KEY_SLOT_ID: "subject"})
	_assert_eq(_feedback(), "这个词不能放在句子的这个位置。", "a slot press should try the selected token and report a refusal")
	_raise(UiIntentsScript.COMPOSER_TOKEN_PRESSED, {UiIntentsScript.KEY_TOKEN_ID: "subject-1"})
	_raise(UiIntentsScript.COMPOSER_SLOT_PRESSED, {UiIntentsScript.KEY_SLOT_ID: "subject"})
	_assert_eq(_feedback(), "词已经进入医生句槽。", "a slot press should place the selected token")
	var drop := _raise(UiIntentsScript.COMPOSER_TOKEN_DROPPED, {UiIntentsScript.KEY_DATA: {"kind": "language_token", "id": "action-1"}, UiIntentsScript.KEY_SLOT_ID: "action"})
	_assert_eq(_selected_token(), "action-1", "a drop should remember the dropped token")
	_assert_eq(_feedback(), "词已经进入医生句槽。", "a drop should place the dropped token")
	_assert_presents(drop, DoctorSentenceIntentHandlerScript.COMPOSER_CHANGED, "a drop")
	_raise(UiIntentsScript.COMPOSER_TOKEN_DROPPED, {UiIntentsScript.KEY_DATA: {"kind": "language_token", "id": "action-1"}, UiIntentsScript.KEY_SLOT_ID: "subject"})
	_assert_eq(_feedback(), "这个词不能放在句子的这个位置。", "a drop on the wrong slot should report a refusal")


func _test_a_drop_with_no_token_changes_nothing() -> void:
	_boot()
	_raise(UiIntentsScript.COMPOSER_TOKEN_PRESSED, {UiIntentsScript.KEY_TOKEN_ID: "ghost-2"})
	var result := _raise(UiIntentsScript.COMPOSER_TOKEN_DROPPED, {UiIntentsScript.KEY_DATA: {}, UiIntentsScript.KEY_SLOT_ID: "subject"})
	_assert_eq(_selected_token(), "ghost-2", "a drop with no token id should change nothing")
	_assert_presents(result, IntentResultScript.NONE, "a drop with no token")


func _test_a_refused_confirm_keeps_the_selection() -> void:
	_boot()
	_raise(UiIntentsScript.COMPOSER_TOKEN_PRESSED, {UiIntentsScript.KEY_TOKEN_ID: "ghost-2"})
	var result := _raise(UiIntentsScript.COMPOSER_CONFIRM_PRESSED)
	_assert_presents(result, DoctorSentenceIntentHandlerScript.CONFIRMED, "a confirm")
	if result != null and result.outcome != null:
		_assert_eq(result.outcome.feedback_key, ActionOutcomeScript.DOCTOR_SENTENCE_REJECTED, "an unfinished sentence should be rejected")
	_assert_eq(_selected_token(), "ghost-2", "a refused confirm should keep the selection")


func _test_a_confirmed_sentence_clears_the_selection() -> void:
	_boot()
	_speaking()
	for slot_and_token in [["subject", "subject-1"], ["action", "action-1"], ["object", "object-1"]]:
		_raise(UiIntentsScript.COMPOSER_TOKEN_DROPPED, {UiIntentsScript.KEY_DATA: {"kind": "language_token", "id": slot_and_token[1]}, UiIntentsScript.KEY_SLOT_ID: slot_and_token[0]})
	var result := _raise(UiIntentsScript.COMPOSER_CONFIRM_PRESSED)
	_assert_presents(result, DoctorSentenceIntentHandlerScript.CONFIRMED, "a confirm")
	if result != null and result.outcome != null:
		_assert_true(result.outcome.succeeded, "a full sentence should be spoken")
	_assert_eq(_selected_token(), "", "a spoken sentence should clear the selection")


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
