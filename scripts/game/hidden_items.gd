class_name HiddenItems
extends RefCounted
## The hidden items a run can carry (#130, #142 Q2): one per floor, the first of them Enoch, given by round four's NPC
## behind the door once helped. Each has a name and a one-line description per language; `provisional` marks wording
## the planner has not settled yet. Read-only content; the run keeps which ones it holds (`hidden_items`).

const ContentJsonScript = preload("res://framework/content_json.gd")

const ITEMS_PATH := "res://content/hidden_items.json"
const SUPPORTED_LOCALES := ["zh", "ja", "en"]


static func is_known(item_id: String, path: String = ITEMS_PATH) -> bool:
	return _items(path).get(item_id) is Dictionary


static func is_provisional(item_id: String, path: String = ITEMS_PATH) -> bool:
	return bool(_item(item_id, path).get("provisional", false))


## The item's name in a language, or empty when the item is unknown.
static func item_name(item_id: String, locale_code: String, path: String = ITEMS_PATH) -> String:
	return _text(item_id, "name", locale_code, path)


## The item's one line in a language, or empty when the item is unknown.
static func description(item_id: String, locale_code: String, path: String = ITEMS_PATH) -> String:
	return _text(item_id, "description", locale_code, path)


## The ids among `values` that name a known item, each once, in their order: what a save may hand back.
static func known_ids(values: Variant, path: String = ITEMS_PATH) -> Array:
	var ids: Array = []
	for value: Variant in values if values is Array else []:
		if value is String and is_known(value, path) and value not in ids:
			ids.append(value)
	return ids


static func validate(path: String = ITEMS_PATH) -> Array[String]:
	return problems_in(ContentJsonScript.load_dictionary_cached(path, "HiddenItems"))


## Names everything wrong with the items' catalog: each needs a name and a line in every language.
static func problems_in(catalog: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	var items: Variant = catalog.get("items")
	if not items is Dictionary or (items as Dictionary).is_empty():
		problems.append("there are no hidden items")
		return problems
	for item_id: Variant in items:
		var item: Variant = items[item_id]
		if not item is Dictionary:
			problems.append("hidden item %s is not a table" % item_id)
			continue
		if item.has("provisional") and not item["provisional"] is bool:
			problems.append("hidden item %s says neither yes nor no to provisional" % item_id)
		for part: String in ["name", "description"]:
			var by_locale: Variant = item.get(part)
			for locale_code: String in SUPPORTED_LOCALES:
				if not by_locale is Dictionary or str((by_locale as Dictionary).get(locale_code, "")).is_empty():
					problems.append("hidden item %s has no %s in %s" % [item_id, part, locale_code])
	return problems


static func _items(path: String) -> Dictionary:
	var items: Variant = ContentJsonScript.load_dictionary_cached(path, "HiddenItems").get("items")
	return items if items is Dictionary else {}


static func _item(item_id: String, path: String) -> Dictionary:
	var item: Variant = _items(path).get(item_id)
	return item if item is Dictionary else {}


static func _text(item_id: String, part: String, locale_code: String, path: String) -> String:
	var by_locale: Variant = _item(item_id, path).get(part)
	return str((by_locale as Dictionary).get(locale_code, "")) if by_locale is Dictionary else ""
