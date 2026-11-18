extends Node3D


@export_node_path("Camera3D") var cam_path := NodePath("Camera")
@onready var cam: Camera3D = get_node(cam_path)

@export var mouse_sensitivity := 2.0
@export_range(0.0, 40.0, 1.0) var joystick_look_smoothing := 18.0
@export var y_limit := 90.0
var mouse_axis := Vector2()
var rot := Vector3()
var _joystick_axis := Vector2.ZERO


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	mouse_sensitivity = mouse_sensitivity / 1000
	y_limit = deg_to_rad(y_limit)


# Called when there is an input event
func _input(event: InputEvent) -> void:
	# Mouse look (only if the mouse is captured).
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		mouse_axis = event.relative
		camera_rotation()


# Called every physics tick. 'delta' is constant
func _physics_process(delta: float) -> void:
	var joystick_axis := Input.get_vector(&"look_left", &"look_right",
			&"look_up", &"look_down", 0.0)
	if joystick_axis.is_zero_approx():
		_joystick_axis = Vector2.ZERO
	elif not is_zero_approx(joystick_look_smoothing):
		var smoothing_weight := 1.0 - exp(-joystick_look_smoothing * delta)
		_joystick_axis = _joystick_axis.lerp(joystick_axis, smoothing_weight)
	else:
		_joystick_axis = joystick_axis

	if not _joystick_axis.is_zero_approx():
		mouse_axis = _joystick_axis * 2000.0 * delta
		camera_rotation()


func camera_rotation() -> void:
	# Horizontal mouse look.
	rot.y -= mouse_axis.x * mouse_sensitivity
	# Vertical mouse look.
	rot.x = clamp(rot.x - mouse_axis.y * mouse_sensitivity, -y_limit, y_limit)
	
	get_owner().rotation.y = rot.y
	rotation.x = rot.x
