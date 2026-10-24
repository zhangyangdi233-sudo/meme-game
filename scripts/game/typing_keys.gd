class_name TypingKeys
extends RefCounted
## Which key presses type the next unit of a conversation line: a fresh press of a text key. Arrows, modifiers on
## their own, shortcuts with Ctrl, Alt or Meta, and a held key's repeats type nothing.


static func types_a_unit(key: InputEventKey) -> bool:
	if key == null or not key.pressed or key.echo:
		return false
	if key.ctrl_pressed or key.alt_pressed or key.meta_pressed:
		return false
	if key.unicode >= 32 and key.unicode != 127:
		return true
	# An input method composing a syllable may hold the character back; the physical text key still counts.
	var physical := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
	return (physical >= KEY_A and physical <= KEY_Z) or (physical >= KEY_0 and physical <= KEY_9) or physical == KEY_SPACE
