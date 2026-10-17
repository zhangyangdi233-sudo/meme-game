class_name GameSocialFeedSource
extends SocialFeedSource
## The game's social content: the catalog posts read against the current run, locale and language material.
## The host configures it again whenever a new run starts.

const EchoQuoteContentScript = preload("res://scripts/narrative/echo_quote_content.gd")
const PollutionStageScript = preload("res://scripts/world/pollution_stage.gd")
const RuntimeTextureCacheScript = preload("res://scripts/game/runtime_texture_cache.gd")
const SocialFeedCatalogScript = preload("res://scripts/game/social_feed_catalog.gd")
const SocialFeedContentScript = preload("res://scripts/game/social_feed_content.gd")

const PLAYER_CHARACTER_PATH := "res://assets/generated/characters/protagonist_operator.png"
const NO_SIGNAL_ICON_PATH := "res://assets/generated/ui/no_signal_icon.png"
const SOCIAL_POSTER_SHEET_PATH := "res://assets/generated/social/poster_sheet.png"
const COMPOSER_SOFT_UNIT_LIMIT := 12

var post_cards: Array = SocialFeedCatalogScript.get_post_cards()
var _channels: Array = SocialFeedCatalogScript.get_channels()
var _textures: RuntimeTextureCache
var _game: MemeGameState
var _locale: BabelGameLocale
var _material: LanguageMaterial


func _init(textures: RuntimeTextureCache = null) -> void:
	_textures = textures if textures != null else RuntimeTextureCacheScript.new()


func configure(game: MemeGameState, locale: BabelGameLocale, material: LanguageMaterial) -> void:
	_game = game
	_locale = locale
	_material = material


## The lookups SocialFeedContent reads for the current run.
func content_deps() -> Dictionary:
	return {
		"post_cards": post_cards,
		"game": _game,
		"day_progress": _game.get_day_progress_snapshot() if _game != null else {},
		"current_locale": current_locale(),
		"translate": translate,
		"level_display_name": func(floor_number: int) -> String: return _locale.level_display_name(floor_number),
		"poster_sheet_path": SOCIAL_POSTER_SHEET_PATH,
		"texture_cache": _textures.textures,
		"load_texture": load_texture,
		"pickable_units": func(text: String) -> Array[String]: return _locale.pickable_units(text),
	}


func channels() -> Array:
	return _channels


func load_texture(path: String) -> Texture2D:
	return _textures.load_texture(path)


func poster_texture(poster_cell: int) -> Texture2D:
	return SocialFeedContentScript.poster_texture(poster_cell, content_deps())


func poster_sheet_path() -> String:
	return SOCIAL_POSTER_SHEET_PATH


func poster_sheet_count() -> int:
	return SocialFeedContentScript.SOCIAL_POSTER_COUNT


func no_signal_icon_path() -> String:
	return NO_SIGNAL_ICON_PATH


func player_character_path() -> String:
	return PLAYER_CHARACTER_PATH


func composer_soft_unit_limit() -> int:
	return COMPOSER_SOFT_UNIT_LIMIT


func visible_post_indices(followed_handles: Array, channel: String) -> Array[int]:
	return SocialFeedContentScript.visible_post_indices(content_deps(), followed_handles, channel)


func post_for_index(post_index: int) -> Dictionary:
	return SocialFeedContentScript.post_for_index(post_index, content_deps())


func like_text(post: Dictionary, post_index: int, liked_post_ids: Array) -> String:
	return SocialFeedContentScript.like_text(post, post_index, liked_post_ids)


func caption_text(post: Dictionary, post_index: int) -> String:
	return SocialFeedContentScript.caption(post, post_index, content_deps())


func author_id(post: Dictionary) -> String:
	return SocialFeedContentScript.author_id(post)


func corrupt_text(text: String) -> String:
	text = translate(text)
	var stage := PollutionStageScript.stage(_game.pollution, _game.day) if _game != null else PollutionStageScript.stage(0, 1)
	var replacements := [translate("哈吉米"), "□", translate("沉默"), "……"]
	return PollutionStageScript.corrupt_sentence_ui(
		text,
		int(stage.get("pollution", 0)),
		int(stage.get("day", 0)),
		current_locale(),
		replacements,
	)


func translate(text: String) -> String:
	return _locale.translate(text) if _locale != null else text


func floor_label() -> String:
	return SocialFeedContentScript.floor_label(content_deps())


func player_echo_quote() -> String:
	return _game.get_player_echo_quote(current_locale()) if _game != null else ""


func echo_comment_handle() -> String:
	return EchoQuoteContentScript.anon_handle(current_locale())


func game_day() -> int:
	return _game.day if _game != null else 0


func pollution() -> int:
	return _game.pollution if _game != null else 0


func current_locale() -> String:
	return _locale.current_locale if _locale != null else ""


func language_material() -> LanguageMaterial:
	return _material
