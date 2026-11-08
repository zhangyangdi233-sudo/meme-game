class_name SocialFeedCatalog
extends RefCounted
## Loads authored social feed content from JSON and validates shape before injection.

const ContentJsonScript = preload("res://framework/content_json.gd")
const CATALOG_PATH := "res://content/social_feed_catalog.json"
const SOCIAL_POSTER_COUNT := 12


static func load_catalog(path: String = CATALOG_PATH) -> Dictionary:
	var catalog: Dictionary = ContentJsonScript.load_dictionary_cached(path, "SocialFeedCatalog")
	if catalog.is_empty():
		return {"_path": path, "channels": [], "post_cards": [], "day_plans": []}
	catalog["_path"] = path
	return catalog


static func get_channels(path: String = CATALOG_PATH) -> Array:
	return ContentJsonScript.duplicate_array(load_catalog(path).get("channels", []))


static func get_post_cards(path: String = CATALOG_PATH) -> Array:
	return ContentJsonScript.duplicate_array(load_catalog(path).get("post_cards", []))


static func get_day_plans(path: String = CATALOG_PATH) -> Array:
	return ContentJsonScript.duplicate_array(load_catalog(path).get("day_plans", []))


static func day_plan_for_day(day_number: int, path: String = CATALOG_PATH) -> Dictionary:
	var day_plans := get_day_plans(path)
	if day_plans.is_empty():
		return {}
	var index := mini(maxi(1, day_number), day_plans.size()) - 1
	return (day_plans[index] as Dictionary).duplicate(true)


static func validate(path: String = CATALOG_PATH) -> Dictionary:
	var problems: Array[String] = []
	var catalog := load_catalog(path)
	var channels: Array = catalog.get("channels", [])
	var post_cards: Array = catalog.get("post_cards", [])
	var day_plans: Array = catalog.get("day_plans", [])
	if channels.is_empty():
		problems.append("channels must not be empty")
	if post_cards.is_empty():
		problems.append("post_cards must not be empty")
	if day_plans.is_empty():
		problems.append("day_plans must not be empty")
	var channel_ids: Array[String] = []
	for channel_data in channels:
		var channel: Dictionary = channel_data as Dictionary
		var channel_id := str(channel.get("id", ""))
		if channel_id.is_empty():
			problems.append("channel missing id")
		elif channel_id in channel_ids:
			problems.append("duplicate channel id: %s" % channel_id)
		else:
			channel_ids.append(channel_id)
		if str(channel.get("label", "")).is_empty():
			problems.append("channel %s missing label" % channel_id)
	var post_ids: Array[String] = []
	var poster_cells: Array[int] = []
	for post_data in post_cards:
		var post: Dictionary = post_data as Dictionary
		var post_id := str(post.get("id", ""))
		if post_id.is_empty():
			problems.append("post card missing id")
		elif post_id in post_ids:
			problems.append("duplicate post id: %s" % post_id)
		else:
			post_ids.append(post_id)
		for field_name in ["caption", "handle", "text"]:
			if str(post.get(field_name, "")).is_empty():
				problems.append("post %s missing %s" % [post_id, field_name])
		var poster_cell := int(post.get("poster_cell", -1))
		if poster_cell < 0 or poster_cell >= SOCIAL_POSTER_COUNT:
			problems.append("post %s poster_cell out of range: %d" % [post_id, poster_cell])
		elif poster_cell in poster_cells:
			problems.append("duplicate poster_cell: %d" % poster_cell)
		else:
			poster_cells.append(poster_cell)
		var tokens: Array = post.get("tokens", [])
		if tokens.is_empty():
			problems.append("post %s has no tokens" % post_id)
	for plan_index in day_plans.size():
		var plan: Dictionary = day_plans[plan_index] as Dictionary
		var plan_label := str(plan.get("title", "day_%d" % (plan_index + 1)))
		for field_name in ["title", "speaker", "line"]:
			if not plan.has(field_name):
				problems.append("day plan %s missing %s" % [plan_label, field_name])
		var trends: Array = plan.get("trends", [])
		if trends.is_empty():
			problems.append("day plan %s missing trends" % plan_label)
		var feed: Array = plan.get("feed", [])
		if feed.is_empty():
			problems.append("day plan %s missing feed entries" % plan_label)
	return {"ok": problems.is_empty(), "problems": problems}
