class_name SocialIntentHandler
extends IntentHandler
## Handles the social feed's intents: changes the state and the language material, writes the feedback line,
## and returns what the host presents. The host stays the only listener and routes these intents here (ADR 0007).

const SocialFeedContentScript = preload("res://scripts/game/social_feed_content.gd")
const UiIntentsScript = preload("res://scripts/ui_intents.gd")

## The social panel already repainted its page; the host re-themes the phone shell.
const PAGE_CHANGED := "social_page_changed"
## The social window closed; the host shuts the open post and refreshes the phone shell.
const WINDOW_CLOSED := "social_window_closed"
## A word pickup; the host flies the word and settles when it spent the day's first action.
const PICKUP := "social_pickup"

const INTENTS: Array[String] = [
	UiIntentsScript.SOCIAL_CHANNEL_PRESSED,
	UiIntentsScript.SOCIAL_SCREEN_REQUESTED,
	UiIntentsScript.SOCIAL_CARD_CLICKED,
	UiIntentsScript.SOCIAL_LIKE_PRESSED,
	UiIntentsScript.SOCIAL_FOLLOW_PRESSED,
	UiIntentsScript.SOCIAL_CLOSE_REQUESTED,
	UiIntentsScript.SOCIAL_DETAIL_CLOSE_REQUESTED,
	UiIntentsScript.SOCIAL_PUBLISH_CONFIRM_REQUESTED,
	UiIntentsScript.SOCIAL_PICKUP_UNIT_CLICKED,
	UiIntentsScript.SOCIAL_COMPOSER_AREA_DROPPED,
	UiIntentsScript.SOCIAL_COMPOSER_TILE_DROPPED,
	UiIntentsScript.SOCIAL_COMPOSER_ANSWER_TAPPED,
	UiIntentsScript.SOCIAL_COMPOSER_SUBMIT_REQUESTED,
]

var _game: MemeGameState
var _material: LanguageMaterial
var _source: GameSocialFeedSource


## The host configures it again before each use, so a new run's state is never stale.
func configure(game: MemeGameState, material: LanguageMaterial, source: GameSocialFeedSource) -> void:
	_game = game
	_material = material
	_source = source


func handles(intent_name: String) -> bool:
	return intent_name in INTENTS


func handle(intent_name: String, payload: Dictionary) -> IntentResult:
	match intent_name:
		UiIntentsScript.SOCIAL_CHANNEL_PRESSED, UiIntentsScript.SOCIAL_SCREEN_REQUESTED:
			return IntentResultScript.present(PAGE_CHANGED)
		UiIntentsScript.SOCIAL_CARD_CLICKED:
			_game.notify_tutorial("post_opened", {"post_index": int(payload.get(UiIntentsScript.KEY_POST_INDEX, -1))})
			return IntentResultScript.present(PAGE_CHANGED)
		UiIntentsScript.SOCIAL_LIKE_PRESSED:
			var liked := _game.toggle_social_like(str(payload.get(UiIntentsScript.KEY_POST_ID, "")))
			_write_feedback("已保存这条信号。" if liked else "已取消保存。")
		UiIntentsScript.SOCIAL_FOLLOW_PRESSED:
			var author_id := str(payload.get(UiIntentsScript.KEY_AUTHOR_ID, ""))
			var followed := _game.toggle_social_follow(author_id)
			var display_handle := SocialFeedContentScript.author_display(author_id, _source.content_deps())
			_write_feedback("已关注 @%s。" % display_handle if followed else "已取消关注 @%s。" % display_handle)
		UiIntentsScript.SOCIAL_CLOSE_REQUESTED:
			_game.close_app_window("social")
			_write_feedback("关闭 social 窗口。")
			return IntentResultScript.present(WINDOW_CLOSED)
		UiIntentsScript.SOCIAL_DETAIL_CLOSE_REQUESTED:
			_write_feedback("关闭社交详情。")
			return IntentResultScript.present(PAGE_CHANGED)
		UiIntentsScript.SOCIAL_PUBLISH_CONFIRM_REQUESTED:
			return _action(_game.publish_dialogue())
		UiIntentsScript.SOCIAL_PICKUP_UNIT_CLICKED:
			var meta: Variant = payload.get(UiIntentsScript.KEY_META)
			var pickup := IntentResultScript.present(PICKUP, _material.pick_from_post(meta, str(payload.get(UiIntentsScript.KEY_POST_ID, ""))))
			pickup.unit = str(meta)
			return pickup
		UiIntentsScript.SOCIAL_COMPOSER_AREA_DROPPED:
			_material.drop_on_area(payload.get(UiIntentsScript.KEY_DATA, {}))
		UiIntentsScript.SOCIAL_COMPOSER_TILE_DROPPED:
			_material.drop_before(payload.get(UiIntentsScript.KEY_DATA, {}), int(payload.get(UiIntentsScript.KEY_BEFORE_INDEX, 0)))
		UiIntentsScript.SOCIAL_COMPOSER_ANSWER_TAPPED:
			_material.remove_at(int(payload.get(UiIntentsScript.KEY_UNIT_INDEX, -1)))
		UiIntentsScript.SOCIAL_COMPOSER_SUBMIT_REQUESTED:
			return IntentResultScript.present(IntentResultScript.SUBMIT, _material.submit())
	return IntentResultScript.present(IntentResultScript.NONE)

