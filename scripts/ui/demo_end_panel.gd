class_name DemoEndPanel
extends Control
## The demo's end screen: black text on white, in the chosen language and its formal font. It mounts the Layout scene
## `scenes/ui/demo_end.tscn` and stays up until the player asks for the main menu.

const NarrativeSessionCatalogScript = preload("res://scripts/game/narrative_session_catalog.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const PropertyWatchScript = preload("res://scripts/game/property_watch.gd")
const GameUiThemeScript = preload("res://scripts/ui/game_ui_theme.gd")
const UiIntentsScript = preload("res://scripts/ui_intents.gd")

const MENU_BUTTON_TEXT := "退回主画面"

var _watch: PropertyWatchScript = PropertyWatchScript.new(self, {PropertyKeysScript.LOCALE: _on_locale})
@onready var _text := $DemoEndColumn/DemoEndText as Label
@onready var _menu_button := $DemoEndColumn/DemoEndMenuButton as Button


func _ready() -> void:
	_menu_button.pressed.connect(_on_menu_button_pressed)
	_watch.start()


func _on_locale(value: Variant) -> void:
	var locale := str(value)
	var font := LocaleFont.font(locale)
	_text.text = NarrativeSessionCatalogScript.demo_end_text(locale)
	_text.add_theme_font_override("font", font)
	_menu_button.add_theme_font_override("font", font)
	_menu_button.text = MENU_BUTTON_TEXT
	var theme := GameUiThemeScript.bound()
	if theme != null:
		theme.set_localized_property(_menu_button, "text")


func _on_menu_button_pressed() -> void:
	GameEventBus.raise(UiIntentsScript.RETURN_MAIN_MENU_PRESSED)
