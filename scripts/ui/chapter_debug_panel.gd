@tool
class_name ChapterDebugPanel
extends PaletteSceneRoot
## Debug-build panel F9 shows during a run: the chapter's phase, basement round and exit, and one button per round
## that asks the host to jump there. A jump is a request like any other UI intent; the host changes the run.

const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const PropertyWatchScript = preload("res://scripts/game/property_watch.gd")
const ChapterOneProgressScript = preload("res://scripts/game/chapter_one_progress.gd")
const GameUiThemeScript = preload("res://scripts/ui/game_ui_theme.gd")
const UiIntentsScript = preload("res://scripts/ui_intents.gd")

var _watch: PropertyWatchScript = PropertyWatchScript.new(self, {
	PropertyKeysScript.CHAPTER_ONE_PROGRESS: _on_progress,
})


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	for round_number in range(1, ChapterOneProgressScript.BASEMENT_ROUND_COUNT + 1):
		var button := get_node_or_null("%%ChapterDebugRound%dButton" % round_number) as BaseButton
		if button != null:
			button.pressed.connect(_request_round.bind(round_number))
	_watch.start()
	var theme := GameUiThemeScript.bound()
	if theme != null:
		apply_palette(theme.active_palette())


func _request_round(round_number: int) -> void:
	GameEventBus.raise(UiIntentsScript.CHAPTER_ROUND_JUMP_REQUESTED, {UiIntentsScript.KEY_INDEX: round_number})


func _on_progress(value: Variant) -> void:
	var status := get_node_or_null("%ChapterDebugStatus") as Label
	if status == null:
		return
	var progress := ChapterOneProgressScript.normalize(value)
	match ChapterOneProgressScript.phase_of(progress):
		ChapterOneProgressScript.PHASE_OPENING:
			status.text = "开场"
		ChapterOneProgressScript.PHASE_TOWER:
			status.text = "十字路口（第一章之后）"
		_:
			status.text = "地下室 第 %d / %d 轮\n出口：%s" % [
				ChapterOneProgressScript.round_of(progress),
				ChapterOneProgressScript.BASEMENT_ROUND_COUNT,
				"开" if ChapterOneProgressScript.exit_open(progress) else "关",
			]
