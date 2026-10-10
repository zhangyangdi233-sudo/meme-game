extends RefCounted
class_name SocialFeedContent
## Pure social feed post/caption/poster helpers extracted from the main scene adapter.

const SOCIAL_POSTER_COLUMNS := 4
const SOCIAL_POSTER_ROWS := 3
const SOCIAL_POSTER_COUNT := SOCIAL_POSTER_COLUMNS * SOCIAL_POSTER_ROWS


## The following channel lists only the posts of authors in followed_handles.
static func visible_post_indices(deps: Dictionary, followed_handles: Array = []) -> Array[int]:
	var result: Array[int] = []
	var social_channel := str(deps.get("social_channel", "discover"))
	var post_cards: Array = deps.get("post_cards", [])
	for post_index in post_cards.size():
		if social_channel == "following":
			var post := post_for_index(post_index, deps)
			var author_id_fn: Callable = deps.get("author_id", Callable())
			if author_id_fn.is_valid() and not followed_handles.has(author_id_fn.call(post)):
				continue
		result.append(post_index)
	return result


static func like_text(post: Dictionary, post_index: int, liked_post_ids: Array = []) -> String:
	var liked := liked_post_ids.has(str(post.get("id", "")))
	var stable_index := int(post.get("card_index", post_index))
	var count := 64 + (stable_index * 31) % 120 + (1 if liked else 0)
	return "%s %d" % ["♥" if liked else "♡", count]


static func floor_label(deps: Dictionary) -> String:
	var day_progress: Dictionary = deps.get("day_progress", {})
	var level_display_name: Callable = deps.get("level_display_name", Callable())
	var floor_number := clampi(int(day_progress.get("tower_floor", 1)), 1, 4)
	return level_display_name.call(floor_number) if level_display_name.is_valid() else str(floor_number)


static func caption(post: Dictionary, _post_index: int, deps: Dictionary) -> String:
	var translate: Callable = deps.get("translate", Callable())
	var text := str(post.get("caption", "未命名信号"))
	return translate.call(text) if translate.is_valid() else text


static func publish_result(deps: Dictionary) -> Dictionary:
	var placed_meme: Dictionary = deps.get("placed_meme", {})
	var game: Variant = deps.get("game")
	if game == null:
		return {}
	if not placed_meme.is_empty():
		return game.get_publish_result(placed_meme)
	return game.last_publish_result


static func poster_texture_path(_post_index: int, deps: Dictionary) -> String:
	return str(deps.get("poster_sheet_path", ""))


static func poster_texture(post_index: int, deps: Dictionary) -> Texture2D:
	var poster_sheet_path := str(deps.get("poster_sheet_path", ""))
	var cell_index := posmod(post_index, SOCIAL_POSTER_COUNT)
	var texture_cache: Dictionary = deps.get("texture_cache", {})
	var cache_key := "%s#cell-%d" % [poster_sheet_path, cell_index]
	if texture_cache.has(cache_key):
		return texture_cache[cache_key]
	var load_texture: Callable = deps.get("load_texture", Callable())
	var sheet: Texture2D = load_texture.call(poster_sheet_path) if load_texture.is_valid() else null
	if sheet == null:
		return null
	var cell_size := Vector2(
		floorf(float(sheet.get_width()) / SOCIAL_POSTER_COLUMNS),
		floorf(float(sheet.get_height()) / SOCIAL_POSTER_ROWS)
	)
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	var row := floori(float(cell_index) / SOCIAL_POSTER_COLUMNS)
	atlas.region = Rect2(
		Vector2(cell_index % SOCIAL_POSTER_COLUMNS, row) * cell_size,
		cell_size
	)
	texture_cache[cache_key] = atlas
	return atlas


static func post_for_index(post_index: int, deps: Dictionary) -> Dictionary:
	var post_cards: Array = deps.get("post_cards", [])
	if post_cards.is_empty():
		return {}
	var day_progress: Dictionary = deps.get("day_progress", {})
	var day_offset := 0 if deps.get("game") == null else maxi(0, int(day_progress.get("day", 1)) - 1) * 3
	var card_index := posmod(post_index + day_offset, post_cards.size())
	var post: Dictionary = (post_cards[card_index] as Dictionary).duplicate(true)
	post["card_index"] = card_index
	var translate: Callable = deps.get("translate", Callable())
	var current_locale := str(deps.get("current_locale", ""))
	var candidate_tokens: Array = []
	for token_data in post.get("tokens", []):
		var token: Dictionary = (token_data as Dictionary).duplicate(true)
		var source_text := str(token.get("text", ""))
		token["text"] = translate.call(source_text) if translate.is_valid() else source_text
		token["source_text"] = source_text
		token["content_locale"] = current_locale
		token["source_card_id"] = str(post.get("id", ""))
		token["lexeme_id"] = str(token.get("lexeme_id", "%s.%s" % [post.get("id", "post"), token.get("id", "token")]))
		for surface_field in ["phone_surface", "doctor_surface", "doll_surface"]:
			token[surface_field] = translate.call(str(token.get(surface_field, source_text))) if translate.is_valid() else str(token.get(surface_field, source_text))
		candidate_tokens.append(token)
	var prepared_tokens: Array = []
	var current_day := 1 if deps.get("game") == null else int(day_progress.get("day", 1))
	var pickup_indices := pickup_post_indices(current_day, deps)
	if post_index in pickup_indices and not candidate_tokens.is_empty():
		prepared_tokens = candidate_tokens.duplicate(true)
	post["tokens"] = prepared_tokens
	post["pickup_available"] = not prepared_tokens.is_empty()
	return post


static func author_id(post: Dictionary) -> String:
	return str(post.get("id", post.get("handle", "unknown-author")))


static func author_display(author_id_value: String, deps: Dictionary) -> String:
	var post_cards: Array = deps.get("post_cards", [])
	var translate: Callable = deps.get("translate", Callable())
	for post in post_cards:
		if str(post.get("id", "")) == author_id_value:
			var handle := str(post.get("handle", author_id_value))
			return translate.call(handle) if translate.is_valid() else handle
	return author_id_value


static func pickable_units(text: String, deps: Dictionary) -> Array[String]:
	var pickable_fn: Callable = deps.get("pickable_units", Callable())
	return pickable_fn.call(text) if pickable_fn.is_valid() else []


static func pickup_post_indices(day_number: int, deps: Dictionary) -> Array[int]:
	var indices: Array[int] = []
	var post_cards: Array = deps.get("post_cards", [])
	if post_cards.is_empty():
		return indices
	var pickup_post_count := mini(post_cards.size(), 2 + posmod(maxi(1, day_number) - 1, 4))
	var start_index := posmod((maxi(1, day_number) - 1) * 5, post_cards.size())
	for offset in pickup_post_count:
		indices.append(posmod(start_index + offset * 5, post_cards.size()))
	return indices
