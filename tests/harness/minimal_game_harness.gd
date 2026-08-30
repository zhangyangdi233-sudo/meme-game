extends RefCounted
## Shared helpers for module-only tests: MemeGameState setup and Control-tree probes.

const StateScript = preload("res://scripts/meme_game_state.gd")


static func new_state() -> RefCounted:
	var state := StateScript.new()
	state.new_run()
	return state


static func find_node_by_name(node: Node, wanted_name: String) -> Node:
	if node == null:
		return null
	if node.name == wanted_name:
		return node
	for child in node.get_children():
		var found := find_node_by_name(child, wanted_name)
		if found != null:
			return found
	return null


static func collect_control_text(root: Node) -> String:
	var result := ""
	if root is Label or root is Button or root is RichTextLabel or root is LineEdit:
		result += str(root.get("text")) + "\n"
	for child in root.get_children():
		result += collect_control_text(child)
	return result


static func craft_token(
	token_id: String,
	text: String,
	role: String,
	phone_surface: String,
	doctor_surface: String,
	lexeme_id: String = ""
) -> Dictionary:
	return {
		"id": token_id,
		"text": text,
		"lexeme_id": lexeme_id if not lexeme_id.is_empty() else "test.%s" % token_id,
		"grammar_roles": [role],
		"phone_surface": phone_surface,
		"doctor_surface": doctor_surface,
		"doll_surface": text,
		"tags": ["test"],
		"rarity": 1,
	}
