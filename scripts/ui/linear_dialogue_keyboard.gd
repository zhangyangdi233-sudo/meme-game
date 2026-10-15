extends Control
## A dialogue key types one authored unit; it never asks players to reproduce text.

var input_allowed: Callable
var advance_character: Callable
var hint_active := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE


func _input(event: InputEvent) -> void:
	if not input_allowed.is_valid() or not bool(input_allowed.call()) or not event is InputEventKey:
		return
	var key := event as InputEventKey
	# Escape remains the settings shortcut. Other keys stay inside the conversation
	# so typing F or Tab cannot accidentally interact with the world or the phone.
	if key.keycode in [KEY_ESCAPE, KEY_F10]:
		return
	get_viewport().set_input_as_handled()
	if not key.pressed or key.echo or key.ctrl_pressed or key.alt_pressed or key.meta_pressed:
		return
	var printable := key.unicode >= 32 and key.unicode != 127
	# Physical letters also work while a CJK IME is composing a syllable.
	var physical := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
	printable = printable or (physical >= KEY_A and physical <= KEY_Z) or (physical >= KEY_0 and physical <= KEY_9) or physical == KEY_SPACE
	if printable and advance_character.is_valid():
		advance_character.call()
