extends SceneTree

const State = preload("res://scripts/meme_game_state.gd")
const Pool = preload("res://scripts/narrative/pickup_char_pool.gd")
var failures: Array[String] = []
var checks := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var main = load("res://scenes/babel_meme_game.tscn").instantiate()
	main._save_path = "user://published_feed_test.dat"
	main._locale.preferences_path = "user://published_feed_preferences.cfg"
	main._camera_session_decided = true
	main._camera_enabled = false
	root.add_child(main)
	main._resolve_camera_consent(false)
	var state = State.new()
	state.new_run()
	main._begin_game_session(state, {}, false)
	main.game.set_active_app("social")
	main.set_view_state("phone_down")
	main._set_social_screen("home")
	var external_before: Dictionary = main._social_post_for_index(0)
	_publish(main, ["门"])
	_publish(main, ["我", "想", "回", "家"])
	main.game.pollution = 95
	main._render()
	var indices: Array = main._social_visible_post_indices()
	_check(indices.size() == main.SOCIAL_POST_CARDS.size() + 2, "published notebook sentences appear alongside all external feed posts")
	_check(indices.size() >= 2 and indices[0] == -2 and indices[1] == -1, "newest publication is first in the waterfall")
	var latest: Dictionary = main._social_post_for_index(-2)
	var first: Dictionary = main._social_post_for_index(-1)
	_check(bool(latest.get("is_player_post", false)) and latest.get("text") == "我想回家", "own post uses the actual published sentence")
	_check(latest.get("id") != first.get("id") and latest.get("id") != external_before.id, "player publications have separate stable identities")
	_check(main._social_post_for_index(0) == external_before, "adding publications does not shift external post IDs or pickup tokens")
	# Keep the baseline failure bounded when the feed has no own-post implementation.
	if bool(latest.get("is_player_post", false)):
		await _test_rendered_posts(main, latest, first)
	main.free()
	await process_frame
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("published social feed tests passed (%d checks; actual submissions, own detail, stable likes, three locales, save/load)" % checks)
	quit(0 if failures.is_empty() else 1)


func _test_rendered_posts(main: Node, latest: Dictionary, first: Dictionary) -> void:
	for locale_code in ["zh", "en", "ja"]:
		main._locale.set_locale(locale_code)
		main._set_social_screen("home")
		for frame in range(3):
			await process_frame
		var card := main.find_child("SocialPostCard-2", true, false)
		var caption := main.find_child("SocialPostCaption-2", true, false) as Label
		_check(card != null and card.get_parent().name == "SocialMasonryColumn0", "newest own post uses the first waterfall column")
		_check(caption != null and caption.text == "我想回家", "player original survives interface localization and pollution")
		var first_caption := main.find_child("SocialPostCaption-1", true, false) as Label
		_check(first_caption != null and first_caption.text == "门" and main._social_fragment(first) == "门", "even a published word matching a UI catalog entry stays in its original language")
		_check(main.find_child("SocialPostFollowButton-2", true, false) == null, "own publication does not offer self-follow")
		var status := main.find_child("SocialPostOwnStatus-2", true, false) as Label
		_check(status != null and status.text.contains(main._locale.translate("已发布")), "own publication visibly identifies its published status")
		if status != null and card != null:
			_check(status.get_global_rect().end.x <= card.get_global_rect().end.x, "published status fits within its waterfall card in every locale")
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		if card != null:
			card.gui_input.emit(click)
		_check(main._social_detail_open and main._social_detail_post_index == -2, "clicking the published card opens its own detail")
		var detail := main.find_child("SocialDetailPostText", true, false) as Label
		_check(detail != null and detail.text == "我想回家", "own detail displays the full original rather than translating or corrupting it")
		_check(main.find_child("SocialPickupLineText", true, false) == null and main.find_child("SocialCommentsHeader", true, false) == null, "own detail does not borrow an external post's pickup line or fake comments")
		_check(main.find_child("SocialDetailFollowButton", true, false) == null, "own detail has no self-follow action")
		_check(main._social_like_text(latest, -2) == "♡ 0", "own likes start at zero instead of borrowing external popularity")
	var own_like := main.find_child("SocialPostLikeButton-1", true, false) as Button
	_check(own_like != null, "published card has its own like action")
	if own_like != null:
		own_like.pressed.emit()
	_check(main.game.is_social_post_liked(str(first.id)) and not main.game.is_social_post_liked(str(latest.id)), "liking one publication cannot like another")
	_check(not main.game.is_social_post_liked(str(main._social_post_for_index(0).id)), "own likes do not affect external post IDs")
	main._open_social_post(-1)
	_publish(main, ["灯"])
	main._render()
	_check(main._social_post_for_index(-1).id == first.id and main._social_detail_post_index == -1, "publishing a newer sentence leaves the open older detail stable")
	_check(main.find_child("SocialDetailPostText", true, false).text == "门", "open detail still shows the older sentence after another publication")
	main._social_channel = "following"
	_check(main._social_visible_post_indices().is_empty(), "self publications do not pretend to be followed external authors")
	main._social_channel = "discover"
	_check(main._save_progress(), "published feed state saves through the actual game save")
	main.show_main_menu()
	_check(main.continue_game(), "published feed reloads through Continue")
	main.game.set_active_app("social")
	main.set_view_state("phone_down")
	main._render()
	_check(main.game.published_memes.size() == 3 and main._social_visible_post_indices()[0] == -3, "saved publications return newest-first")
	_check(main._social_detail_post_index == -1 and main._social_post_for_index(-1).id == first.id, "saved negative detail index restores its own publication")
	_check(main.game.is_social_post_liked(str(first.id)), "publication likes survive save/load without changing identity")
	main._open_social_post(0)
	_check(main.find_child("SocialPickupLineText", true, false) != null, "external NPC posts still provide their existing pickup content")
	# Older meme publishing can reuse a source ID; each publication stays distinct.
	main.game.published_memes.push_front({"id": "floor_13", "clean_text": "", "text": "legacy player sentence"})
	main.game.published_memes.push_front({"id": "floor_13", "text": "another player sentence"})
	var newest: Dictionary = main._social_post_for_index(-5)
	var previous: Dictionary = main._social_post_for_index(-4)
	_check(newest.id != previous.id and newest.id != main._social_post_for_index(0).id, "repeated legacy meme IDs cannot collide with each other or NPC posts")
	_check(previous.text == "legacy player sentence", "an empty legacy clean-text field does not hide a valid publication")
	_check(newest.tokens.is_empty() and not newest.pickup_available, "own publication adapters never export NPC pickup tokens")


func _publish(main: Node, units: Array) -> void:
	for unit in units:
		if not main.game.is_social_char_collected(unit, "zh"):
			for post_id in Pool.POST_SEEDS.keys():
				if main.game.pick_social_char(post_id, unit, "zh").picked:
					break
		_check(main.game.free_sentence_place(unit, "zh"), "collected notebook unit enters the publication draft")
	_check(main.game.submit_free_sentence("zh").submitted, "actual notebook draft produces a saved publication")


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
