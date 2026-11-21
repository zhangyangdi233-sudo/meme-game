class_name SocialPublishPanel
extends Node
## Game-side publish page of the social app. The sentence is composed and posted in the notebook (#154); this page only
## shows the last post and points the player there. The social panel hands it the page host to paint into; while shown
## it watches the posts and repaints its own page.

const PostSlipScript = preload("res://scripts/ui/post_slip.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const PropertyWatchScript = preload("res://scripts/game/property_watch.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const ServiceRegistryScript = preload("res://framework/service_registry.gd")

var _host: Control
var _page: Control
var _painted_post: Dictionary = {}
var _watch: PropertyWatchScript = PropertyWatchScript.new(self, {
	PropertyKeysScript.PUBLISHED_MEMES: _on_model_changed,
	PropertyKeysScript.CHAPTER_ONE_PROGRESS: _on_model_changed,
})


## Paints the publish page into `host`; later model writes repaint it there until it is released.
func render(host: Control) -> void:
	_host = host
	_paint()


## The social panel is about to clear the page host; this page no longer repaints itself.
func release() -> void:
	_host = null
	_page = null


## Watches the models while the social app shows and lets go when it hides.
func set_shown(shown: bool) -> void:
	if shown:
		# Registering delivers each value once; one repaint after all of them covers a value that changed while hidden.
		if not _watch.is_active() and _watch.start():
			_repaint_if_stale()
	else:
		_watch.stop()


func _paint() -> void:
	if _host == null:
		return
	if _page != null and is_instance_valid(_page):
		_host.remove_child(_page)
		_page.queue_free()
	_painted_post = _last_post()
	_render_publish_page(_host)


func _render_publish_page(parent: Control) -> void:
	var publish_page := VBoxContainer.new()
	publish_page.name = "SocialPublishPage"
	publish_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	publish_page.add_theme_constant_override("separation", 6)
	parent.add_child(publish_page)
	_page = publish_page

	var page_header := HBoxContainer.new()
	page_header.name = "SocialPublishHeader"
	page_header.custom_minimum_size.y = 44
	page_header.add_theme_constant_override("separation", 8)
	publish_page.add_child(page_header)
	var page_title := _theme().label("发布新信号", 22, _theme().theme_color("ink")) as Label
	page_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_header.add_child(page_title)

	var result_panel := _theme().panel() as PanelContainer
	result_panel.name = "SocialPublishResult"
	result_panel.set_meta("soft_panel", true)
	publish_page.add_child(result_panel)
	var result_box := VBoxContainer.new()
	result_box.add_theme_constant_override("separation", 6)
	result_panel.add_child(result_box)
	var hint := _theme().label("在笔记本里拼句、投稿。", 15, _theme().theme_color("accent")) as Label
	hint.name = "SocialPublishNotebookHint"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_box.add_child(hint)
	if _painted_post.is_empty():
		var empty_line := _theme().label("还没有投稿。", 14, _theme().theme_color("muted")) as Label
		empty_line.name = "PublishEmptyLine"
		result_box.add_child(empty_line)
	PostSlipScript.add_to(result_box, _painted_post, _theme())


func _on_model_changed(_value: Variant) -> void:
	if not _watch.is_syncing():
		_repaint_if_stale()


## A page that is not painted is left to the social panel; a page that shows these values already needs nothing.
func _repaint_if_stale() -> void:
	if _host == null or _last_post() == _painted_post:
		return
	_paint()
	_theme().apply_ui_theme(_page)
	_theme().localize_control_tree(_page)


func _last_post() -> Dictionary:
	var published: Variant = _watch.read(PropertyKeysScript.PUBLISHED_MEMES)
	var progress: Variant = _watch.read(PropertyKeysScript.CHAPTER_ONE_PROGRESS)
	return PostSlipScript.latest(published as Array if published is Array else [], progress as Dictionary if progress is Dictionary else {})


## The UI theme bound by the host; panels resolve it instead of taking theme callables.
func _theme() -> GameUiTheme:
	return ServiceRegistryScript.resolve(ServiceKeysScript.UI_THEME) as GameUiTheme
