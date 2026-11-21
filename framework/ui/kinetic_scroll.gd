class_name KineticScroll
extends Node
## Phone-like vertical scrolling for a ScrollContainer: a wheel notch glides a share of the page, a touchpad pan
## follows the fingers, and a left-button drag moves the content with the pointer and flings on release.
##
## Attach it to the ScrollContainer it drives; it lives as that container's child and takes its gui_input, so a new
## container gets a new one. The control under a press sees it first: a card that opens on release asks
## was_dragged() first, so a drag (or a press that caught a moving feed) never opens what it started on. Children that
## should let a drag through use MOUSE_FILTER_PASS; the container then takes the press so nothing behind it does.
## Drag distances are read in the container's own coordinates, so a scaled window still tracks the pointer.

## A wheel notch scrolls this share of the visible page.
const WHEEL_PAGE_SHARE := 0.3
## One unit of touchpad pan delta scrolls this many pixels.
const PAN_PIXELS := 60.0
## A press that moves less than this stays a tap.
const DRAG_THRESHOLD := 8.0
## How fast a wheel glide closes on its target (per second, exponential).
const GLIDE_RATE := 14.0
## How fast a fling loses speed (per second, exponential).
const FLING_FRICTION := 4.0
const FLING_MIN_SPEED := 20.0
const FLING_MAX_SPEED := 6000.0
## A drag held still this long before release lets go without a fling.
const FLING_HOLD_LIMIT := 0.1

var _scroll: ScrollContainer
var _position := 0.0
var _target := 0.0
var _velocity := 0.0
var _pressing := false
var _dragged := false
var _caught := false
var _held_still := 0.0
var _press_y := 0.0
var _press_scroll := 0.0
var _release_velocity := 0.0


static func attach(scroll: ScrollContainer) -> KineticScroll:
	var kinetic := KineticScroll.new()
	kinetic.name = "KineticScroll"
	kinetic._scroll = scroll
	kinetic._position = float(scroll.scroll_vertical)
	kinetic._target = kinetic._position
	scroll.add_child(kinetic)
	scroll.gui_input.connect(kinetic._on_scroll_gui_input)
	return kinetic


func _process(delta: float) -> void:
	advance(delta)


## Whether the current (or last) press was a scroll rather than a tap: it moved far enough to drag, or it caught a
## feed that was still moving.
func was_dragged() -> bool:
	return _dragged or _caught


func is_settled() -> bool:
	return not _pressing and _velocity == 0.0 and absf(_position - _target) < 0.5


## Takes one input event; true when the event was a scroll and should go no further.
func handle_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return _handle_button(event as InputEventMouseButton)
	if event is InputEventMouseMotion:
		return _handle_motion(event as InputEventMouseMotion)
	if event is InputEventPanGesture:
		var pan_delta := (event as InputEventPanGesture).delta.y * PAN_PIXELS
		if pan_delta == 0.0:
			return false
		_glide_by(pan_delta)
		return true
	return false


## Moves the scroll one step of time on: a fling slows down, a glide closes on its target.
func advance(delta: float) -> void:
	if _scroll == null or not is_instance_valid(_scroll):
		return
	if _pressing and _dragged:
		_held_still += delta
		return
	if is_settled():
		return
	if _velocity != 0.0:
		_target += _velocity * delta
		_velocity *= exp(-FLING_FRICTION * delta)
		if absf(_velocity) < FLING_MIN_SPEED:
			_velocity = 0.0
		var limit := _max_scroll()
		if _target <= 0.0 or _target >= limit:
			_target = clampf(_target, 0.0, limit)
			_velocity = 0.0
		_position = _target
	elif _position != _target:
		_position += (_target - _position) * (1.0 - exp(-GLIDE_RATE * delta))
		if absf(_target - _position) < 0.5:
			_position = _target
	_apply()


func _handle_button(event: InputEventMouseButton) -> bool:
	var direction := 0.0
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		direction = 1.0
	elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
		direction = -1.0
	if direction != 0.0:
		if event.pressed:
			var notches := event.factor if event.factor > 0.0 else 1.0
			_glide_by(direction * notches * _page() * WHEEL_PAGE_SHARE)
		return true
	if event.button_index != MOUSE_BUTTON_LEFT:
		return false
	if event.pressed:
		_sync_from_scroll()
		_caught = not is_settled()
		_velocity = 0.0
		_target = _position
		_apply()
		_pressing = true
		_dragged = false
		_press_y = event.position.y
		_press_scroll = _position
		_release_velocity = 0.0
		_held_still = 0.0
		return true
	if not _pressing:
		return false
	_end_press(true)
	return true


func _handle_motion(event: InputEventMouseMotion) -> bool:
	if not _pressing:
		return false
	if event.button_mask & MOUSE_BUTTON_MASK_LEFT == 0:
		# The release went somewhere else (focus lost): end the press where it is.
		_end_press(false)
		return false
	var pulled := _press_y - event.position.y
	if not _dragged and absf(pulled) < DRAG_THRESHOLD:
		return true
	_dragged = true
	_held_still = 0.0
	_position = clampf(_press_scroll + pulled, 0.0, _max_scroll())
	_target = _position
	_release_velocity = -event.velocity.y / _screen_scale()
	_apply()
	return true


func _end_press(may_fling: bool) -> void:
	_pressing = false
	_velocity = 0.0
	if may_fling and _dragged and _held_still < FLING_HOLD_LIMIT:
		_velocity = clampf(_release_velocity, -FLING_MAX_SPEED, FLING_MAX_SPEED)
		if absf(_velocity) < FLING_MIN_SPEED:
			_velocity = 0.0


func _glide_by(amount: float) -> void:
	_sync_from_scroll()
	_velocity = 0.0
	_target = clampf(_target + amount, 0.0, _max_scroll())


## Someone else moved the container (a repaint, a reset): start from where it is.
func _sync_from_scroll() -> void:
	if absf(float(_scroll.scroll_vertical) - roundf(_position)) > 1.0:
		_position = float(_scroll.scroll_vertical)
		_target = _position
		_velocity = 0.0


func _apply() -> void:
	_scroll.scroll_vertical = roundi(_position)


## How many screen pixels one of the container's own pixels takes, for pointer speeds read on screen.
func _screen_scale() -> float:
	var scale := absf(_scroll.get_global_transform_with_canvas().get_scale().y)
	return scale if scale > 0.0 else 1.0


func _page() -> float:
	return maxf(_scroll.get_v_scroll_bar().page, _scroll.size.y)


func _max_scroll() -> float:
	var bar := _scroll.get_v_scroll_bar()
	return maxf(0.0, bar.max_value - bar.page)


func _on_scroll_gui_input(event: InputEvent) -> void:
	if handle_input(event):
		_scroll.accept_event()
