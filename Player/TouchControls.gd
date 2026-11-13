extends Control

const MOVEMENT_ACTIONS: Array[StringName] = [
	&"move_forward",
	&"move_back",
	&"move_left",
	&"move_right",
]
const LOOK_ACTIONS: Array[StringName] = [
	&"look_up",
	&"look_down",
	&"look_left",
	&"look_right",
]

var _active_touches: Dictionary = {}
var _movement_touch_id := -1
var _look_touch_id := -1
var _was_paused := false


func _ready() -> void:
	visible = DisplayServer.is_touchscreen_available()
	_was_paused = get_tree().paused
	resized.connect(queue_redraw)


func _exit_tree() -> void:
	_release_all_touches()


func _process(_delta: float) -> void:
	var paused := get_tree().paused
	if paused and not _was_paused:
		_release_all_touches()
	_was_paused = paused
	visible = DisplayServer.is_touchscreen_available() and not paused


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch
		var local_event := make_input_local(touch_event) as InputEventScreenTouch
		if touch_event.pressed:
			_touch_started(touch_event.index, local_event.position)
		else:
			_touch_ended(touch_event.index)
	elif event is InputEventScreenDrag:
		var drag_event := event as InputEventScreenDrag
		var local_event := make_input_local(drag_event) as InputEventScreenDrag
		_touch_moved(drag_event.index, local_event.position)


func _touch_started(touch_id: int, position: Vector2) -> void:
	if _active_touches.has(touch_id):
		return

	for button in _button_layout():
		if position.distance_squared_to(button.center) <= button.radius * button.radius:
			var action: StringName = button.action
			_active_touches[touch_id] = {"kind": "button", "action": action}
			_emit_action(action, 1.0)
			queue_redraw()
			get_viewport().set_input_as_handled()
			return

	var movement_center := _joystick_center(false)
	var joystick_radius := _joystick_radius()
	if _movement_touch_id == -1 and position.distance_squared_to(movement_center) <= pow(joystick_radius * 1.7, 2):
		_movement_touch_id = touch_id
		_active_touches[touch_id] = {"kind": "movement", "position": position}
		_update_joystick(position, false)
		get_viewport().set_input_as_handled()
		return

	var look_center := _joystick_center(true)
	if _look_touch_id == -1 and position.distance_squared_to(look_center) <= pow(joystick_radius * 1.7, 2):
		_look_touch_id = touch_id
		_active_touches[touch_id] = {"kind": "look", "position": position}
		_update_joystick(position, true)
		get_viewport().set_input_as_handled()


func _touch_moved(touch_id: int, position: Vector2) -> void:
	if not _active_touches.has(touch_id):
		return

	var touch: Dictionary = _active_touches[touch_id]
	touch.position = position
	_active_touches[touch_id] = touch
	if touch.kind == "movement":
		_update_joystick(position, false)
	elif touch.kind == "look":
		_update_joystick(position, true)
	queue_redraw()
	get_viewport().set_input_as_handled()


func _touch_ended(touch_id: int) -> void:
	if not _active_touches.has(touch_id):
		return

	var touch: Dictionary = _active_touches[touch_id]
	_active_touches.erase(touch_id)
	if touch.kind == "movement":
		_movement_touch_id = -1
		_set_joystick_actions(Vector2.ZERO, false)
	elif touch.kind == "look":
		_look_touch_id = -1
		_set_joystick_actions(Vector2.ZERO, true)
	elif touch.kind == "button" and not _is_action_held(touch.action):
		_emit_action(touch.action, 0.0)
	queue_redraw()
	get_viewport().set_input_as_handled()


func _update_joystick(position: Vector2, is_look: bool) -> void:
	var center := _joystick_center(is_look)
	var value := (position - center).limit_length(_joystick_radius()) / _joystick_radius()
	var magnitude := value.length()
	if magnitude <= 0.12:
		value = Vector2.ZERO
	else:
		value = value.normalized() * ((magnitude - 0.12) / 0.88)

	_set_joystick_actions(value, is_look)
	queue_redraw()


func _set_joystick_actions(value: Vector2, is_look: bool) -> void:
	if is_look:
		_emit_action(&"look_left", maxf(-value.x, 0.0))
		_emit_action(&"look_right", maxf(value.x, 0.0))
		_emit_action(&"look_up", maxf(-value.y, 0.0))
		_emit_action(&"look_down", maxf(value.y, 0.0))
	else:
		_emit_action(&"move_left", maxf(-value.x, 0.0))
		_emit_action(&"move_right", maxf(value.x, 0.0))
		_emit_action(&"move_forward", maxf(-value.y, 0.0))
		_emit_action(&"move_back", maxf(value.y, 0.0))


func _button_layout() -> Array[Dictionary]:
	var radius := _button_radius()
	return [
		{
			"action": &"grapple",
			"label": "HOOK",
			"center": _anchored_point(0.87, 0.34, radius),
			"radius": radius,
		},
		{
			"action": &"grapple_retract",
			"label": "RELEASE",
			"center": _anchored_point(0.96, 0.48, radius),
			"radius": radius,
		},
		{
			"action": &"jump",
			"label": "JUMP",
			"center": _anchored_point(0.87, 0.61, radius),
			"radius": radius,
		},
		{
			"action": &"sprint",
			"label": "SPRINT",
			"center": _anchored_point(0.96, 0.70, radius),
			"radius": radius,
		},
		{
			"action": &"escape",
			"label": "PAUSE",
			"center": _anchored_point(0.96, 0.14, radius),
			"radius": radius,
		},
	]


func _anchored_point(horizontal: float, vertical: float, margin: float) -> Vector2:
	return Vector2(
		clampf(size.x * horizontal, margin + 8.0, size.x - margin - 8.0),
		clampf(size.y * vertical, margin + 8.0, size.y - margin - 8.0)
	)


func _joystick_center(is_look: bool) -> Vector2:
	return Vector2(size.x * (0.70 if is_look else 0.15), size.y * 0.81)


func _joystick_radius() -> float:
	return clampf(minf(size.x, size.y) * 0.13, 36.0, 74.0)


func _button_radius() -> float:
	return clampf(minf(size.x, size.y) * 0.065, 24.0, 36.0)


func _is_action_held(action: StringName) -> bool:
	for touch in _active_touches.values():
		if touch.kind == "button" and touch.action == action:
			return true
	return false


func _emit_action(action: StringName, strength: float) -> void:
	var input_event := InputEventAction.new()
	input_event.action = action
	input_event.pressed = strength > 0.0
	input_event.strength = strength
	Input.parse_input_event(input_event)


func _release_all_touches() -> void:
	for touch in _active_touches.values():
		if touch.kind == "button":
			_emit_action(touch.action, 0.0)
	if _movement_touch_id != -1:
		for action in MOVEMENT_ACTIONS:
			_emit_action(action, 0.0)
	if _look_touch_id != -1:
		for action in LOOK_ACTIONS:
			_emit_action(action, 0.0)

	_active_touches.clear()
	_movement_touch_id = -1
	_look_touch_id = -1
	queue_redraw()


func _draw() -> void:
	var stick_radius := _joystick_radius()
	_draw_joystick(_joystick_center(false), stick_radius, _movement_touch_id)
	_draw_joystick(_joystick_center(true), stick_radius, _look_touch_id)

	var font := ThemeDB.fallback_font
	var font_size := clampi(roundi(_button_radius() * 0.38), 11, 14)
	for button in _button_layout():
		var action: StringName = button.action
		var pressed := _is_action_held(action)
		var fill_color := Color(0.01, 0.08, 0.16, 0.62 if pressed else 0.42)
		var edge_color := Color(0.0, 0.75, 0.87, 0.95 if pressed else 0.72)
		draw_circle(button.center, button.radius, fill_color)
		draw_arc(button.center, button.radius, 0.0, TAU, 48, edge_color, 2.0, true)
		var label: String = button.label
		var text_width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(
			font,
			button.center + Vector2(-text_width * 0.5, font_size * 0.35),
			label,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size,
			Color(0.82, 0.96, 1.0, 1.0)
		)


func _draw_joystick(center: Vector2, radius: float, touch_id: int) -> void:
	draw_circle(center, radius, Color(0.01, 0.08, 0.16, 0.34))
	draw_arc(center, radius, 0.0, TAU, 48, Color(0.0, 0.75, 0.87, 0.62), 2.0, true)
	var knob_position := center
	if touch_id != -1 and _active_touches.has(touch_id):
		knob_position = center + (
			(_active_touches[touch_id].position - center).limit_length(radius) * 0.58
		)
	draw_circle(knob_position, radius * 0.38, Color(0.0, 0.75, 0.87, 0.72))
